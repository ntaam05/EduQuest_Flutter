using System.Collections.Concurrent;
using System.Security.Claims;
using EduQuest.Api.Data;
using EduQuest.Api.Hubs;
using EduQuest.Api.Models;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Services;

/// <summary>
/// Owns the synchronized trivia-round state machine. All authoritative timing and scoring lives on the server.
/// </summary>
public sealed class RoomGameService(IServiceScopeFactory scopeFactory, IHubContext<RoomHub> hub)
{
    public const int ResultsDurationSeconds = 5;
    private static readonly ConcurrentDictionary<string, SemaphoreSlim> RoomLocks = new();
    private readonly IServiceScopeFactory _scopeFactory = scopeFactory;
    private readonly IHubContext<RoomHub> _hub = hub;

    public static string GroupName(string roomId) => $"room:{roomId}";

    public async Task StartAsync(string roomId, int userId)
    {
        var gate = RoomLocks.GetOrAdd(roomId, _ => new SemaphoreSlim(1, 1));
        object? questionEvent = null;
        object? roomOverview = null;
        await gate.WaitAsync();
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var room = await LoadRoomAsync(db, roomId);
            if (room is null) throw new InvalidOperationException("Không tìm thấy phòng.");
            if (room.HostId != userId) throw new InvalidOperationException("Chỉ chủ phòng mới được bắt đầu.");
            if (room.Status != "Waiting") throw new InvalidOperationException("Phòng không còn ở trạng thái chờ.");
            var questions = SortedQuestions(room);
            if (questions.Count == 0) throw new InvalidOperationException("Bài thi chưa có câu hỏi hợp lệ.");
            if (room.Members.Count == 0) throw new InvalidOperationException("Phòng chưa có người chơi.");

            room.Status = "Playing";
            room.CurrentQuestionIndex = 0;
            room.CurrentRoundNumber = 1;
            room.CurrentRoundStartedAt = DateTime.UtcNow;
            room.RoundResultsShownAt = null;
            room.FinishedAt = null;
            foreach (var member in room.Members)
            {
                member.Score = 0;
                member.CorrectAnswers = 0;
                member.Rank = null;
            }
            await db.SaveChangesAsync();
            questionEvent = BuildQuestionStarted(room, questions[0]);
            roomOverview = BuildOverview(room);
        }
        finally { gate.Release(); }

        await _hub.Clients.Group(GroupName(roomId)).SendAsync("RoomUpdated", roomOverview);
        await _hub.Clients.Group(GroupName(roomId)).SendAsync("QuestionStarted", questionEvent);
    }

    public async Task<object> SubmitAnswerAsync(string roomId, int userId, int questionId, int selectedAnswerIndex)
    {
        var gate = RoomLocks.GetOrAdd(roomId, _ => new SemaphoreSlim(1, 1));
        object? progressEvent = null;
        await gate.WaitAsync();
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var room = await LoadRoomAsync(db, roomId);
            if (room is null) throw new InvalidOperationException("Không tìm thấy phòng.");
            if (!room.Members.Any(m => m.UserId == userId)) throw new InvalidOperationException("Bạn không phải thành viên của phòng này.");
            if (room.Status != "Playing" || room.CurrentRoundStartedAt is null) throw new InvalidOperationException("Câu hỏi hiện tại đã đóng.");
            var questions = SortedQuestions(room);
            if (room.CurrentQuestionIndex < 0 || room.CurrentQuestionIndex >= questions.Count) throw new InvalidOperationException("Không xác định được câu hỏi hiện tại.");
            var question = questions[room.CurrentQuestionIndex];
            if (question.Id != questionId) throw new InvalidOperationException("Đây không phải câu hỏi đang mở.");
            if (selectedAnswerIndex < 0 || selectedAnswerIndex >= question.Options.Count) throw new InvalidOperationException("Phương án trả lời không hợp lệ.");

            var now = DateTime.UtcNow;
            var elapsed = Math.Max(0L, (long)(now - room.CurrentRoundStartedAt.Value).TotalMilliseconds);
            var roundLimit = room.RoundDurationSeconds * 1000L;
            if (elapsed >= roundLimit) throw new InvalidOperationException("Đã hết thời gian trả lời câu này.");
            if (await db.RoomAnswers.AnyAsync(x => x.RoomId == roomId && x.QuestionId == question.Id && x.UserId == userId))
                throw new InvalidOperationException("Bạn đã chốt đáp án cho câu này rồi.");

            var isCorrect = selectedAnswerIndex == question.CorrectAnswerIndex;
            // Correct answers earn 100–1000 points. Earlier correct answers earn more. Incorrect answers earn 0.
            var points = isCorrect ? Math.Max(100, 1000 - (int)Math.Floor(elapsed / (double)roundLimit * 900)) : 0;
            db.RoomAnswers.Add(new RoomAnswer
            {
                RoomId = roomId,
                QuestionId = question.Id,
                UserId = userId,
                SelectedAnswerIndex = selectedAnswerIndex,
                IsCorrect = isCorrect,
                Points = points,
                ElapsedMilliseconds = elapsed,
                AnsweredAt = now
            });
            await db.SaveChangesAsync();
            var answeredCount = await db.RoomAnswers.CountAsync(x => x.RoomId == roomId && x.QuestionId == question.Id);
            progressEvent = new
            {
                room_id = roomId,
                question_id = question.Id,
                answered_count = answeredCount,
                total_players = room.Members.Count,
                // Correctness and points are intentionally withheld until the timer ends.
                your_answer_saved = true
            };
        }
        finally { gate.Release(); }

        await _hub.Clients.Group(GroupName(roomId)).SendAsync("RoundProgress", progressEvent);
        return new { accepted = true, message = "Đã ghi nhận đáp án. Kết quả sẽ công bố khi hết giờ." };
    }

    public async Task<object?> GetSnapshotAsync(string roomId, int userId)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var room = await LoadRoomAsync(db, roomId, asNoTracking: true);
        if (room is null || !room.Members.Any(m => m.UserId == userId)) return null;
        return await BuildSnapshotFromLoadedRoomAsync(db, room, userId);
    }

    public async Task<object?> GetRoomOverviewAsync(string roomId)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var room = await LoadRoomAsync(db, roomId, asNoTracking: true);
        return room is null ? null : BuildOverview(room);
    }

    /// <summary>Called by the hosted timer worker once per second, independent of connected clients.</summary>
    public async Task TickAsync(CancellationToken cancellationToken)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
        var ids = await db.StudyRooms.AsNoTracking()
            .Where(r => r.Status == "Playing" || r.Status == "ShowingResults")
            .Select(r => r.Id).ToListAsync(cancellationToken);
        foreach (var id in ids)
        {
            cancellationToken.ThrowIfCancellationRequested();
            try { await ProcessRoomTickAsync(id, cancellationToken); }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested) { throw; }
            catch (Exception ex) { Console.Error.WriteLine($"[RoomGame] tick failed for {id}: {ex}"); }
        }
    }

    private async Task ProcessRoomTickAsync(string roomId, CancellationToken cancellationToken)
    {
        var gate = RoomLocks.GetOrAdd(roomId, _ => new SemaphoreSlim(1, 1));
        string? eventName = null;
        object? payload = null;
        object? overview = null;
        await gate.WaitAsync(cancellationToken);
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var room = await LoadRoomAsync(db, roomId);
            if (room is null) return;
            var now = DateTime.UtcNow;
            var questions = SortedQuestions(room);

            if (room.Status == "Playing" && room.CurrentRoundStartedAt is not null &&
                now >= room.CurrentRoundStartedAt.Value.AddSeconds(room.RoundDurationSeconds))
            {
                if (room.CurrentQuestionIndex < 0 || room.CurrentQuestionIndex >= questions.Count) return;
                var question = questions[room.CurrentQuestionIndex];
                var answers = await db.RoomAnswers.Include(a => a.User)
                    .Where(a => a.RoomId == roomId && a.QuestionId == question.Id)
                    .OrderBy(a => a.AnsweredAt).ThenBy(a => a.ElapsedMilliseconds).ToListAsync(cancellationToken);

                // The server applies points once, only when transitioning Playing -> ShowingResults.
                foreach (var answer in answers)
                {
                    var member = room.Members.FirstOrDefault(m => m.UserId == answer.UserId);
                    if (member is null) continue;
                    member.Score = (member.Score ?? 0) + answer.Points;
                    if (answer.IsCorrect) member.CorrectAnswers = (member.CorrectAnswers ?? 0) + 1;
                }
                room.Status = "ShowingResults";
                room.RoundResultsShownAt = now;
                await db.SaveChangesAsync(cancellationToken);
                eventName = "QuestionResult";
                payload = BuildQuestionResult(room, question, answers);
                overview = BuildOverview(room);
            }
            else if (room.Status == "ShowingResults" && room.RoundResultsShownAt is not null &&
                     now >= room.RoundResultsShownAt.Value.AddSeconds(ResultsDurationSeconds))
            {
                var nextIndex = room.CurrentQuestionIndex + 1;
                if (nextIndex >= questions.Count)
                {
                    room.Status = "Finished";
                    room.FinishedAt = now;
                    UpdateRanks(room);
                    await db.SaveChangesAsync(cancellationToken);
                    eventName = "GameFinished";
                    payload = new { room_id = room.Id, leaderboard = BuildLeaderboard(room), finished_at = room.FinishedAt };
                    overview = BuildOverview(room);
                }
                else
                {
                    room.CurrentQuestionIndex = nextIndex;
                    room.CurrentRoundNumber++;
                    room.CurrentRoundStartedAt = now;
                    room.RoundResultsShownAt = null;
                    room.Status = "Playing";
                    await db.SaveChangesAsync(cancellationToken);
                    eventName = "QuestionStarted";
                    payload = BuildQuestionStarted(room, questions[nextIndex]);
                    overview = BuildOverview(room);
                }
            }
        }
        finally { gate.Release(); }

        if (eventName is not null)
        {
            await _hub.Clients.Group(GroupName(roomId)).SendAsync(eventName, payload, cancellationToken);
            await _hub.Clients.Group(GroupName(roomId)).SendAsync("RoomUpdated", overview, cancellationToken);
        }
    }

    private static async Task<StudyRoom?> LoadRoomAsync(AppDbContext db, string roomId, bool asNoTracking = false)
    {
        IQueryable<StudyRoom> query = db.StudyRooms
            .Include(r => r.Host)
            .Include(r => r.Quiz).ThenInclude(q => q!.Questions).ThenInclude(q => q.Options)
            .Include(r => r.Members).ThenInclude(m => m.User);
        if (asNoTracking) query = query.AsNoTracking();
        return await query.FirstOrDefaultAsync(r => r.Id == roomId);
    }

    private static List<Question> SortedQuestions(StudyRoom room) => room.Quiz?.Questions.OrderBy(q => q.Order).ThenBy(q => q.Id).ToList() ?? [];

    private static object BuildQuestionStarted(StudyRoom room, Question question)
    {
        // SQLite can materialize DateTime with Kind=Unspecified even though the persisted ticks are UTC.
        // Force UTC before JSON serialization so Flutter does not interpret the server deadline as local time.
        var started = DateTime.SpecifyKind(room.CurrentRoundStartedAt ?? DateTime.UtcNow, DateTimeKind.Utc);
        var ends = started.AddSeconds(room.RoundDurationSeconds);
        return new
        {
            room_id = room.Id,
            room_code = room.Code,
            question_index = room.CurrentQuestionIndex,
            question_number = room.CurrentQuestionIndex + 1,
            question_count = SortedQuestions(room).Count,
            current_round_number = room.CurrentRoundNumber,
            question_duration_seconds = room.RoundDurationSeconds,
            total_players = room.Members.Count,
            started_at = started,
            ends_at = ends,
            question = new
            {
                id = question.Id,
                text = question.Text,
                options = question.Options.OrderBy(o => o.Order).Select((o, i) => new { index = i, text = o.Text }).ToList()
            },
            leaderboard = BuildLeaderboard(room)
        };
    }

    private static object BuildQuestionResult(StudyRoom room, Question question, List<RoomAnswer> answers)
    {
        var byUser = answers.ToDictionary(a => a.UserId, a => a);
        var questionResults = room.Members.Select(m =>
        {
            byUser.TryGetValue(m.UserId, out var answer);
            return new
            {
                user_id = m.UserId,
                name = m.User?.Name ?? "Người chơi",
                avatar_emoji = m.User?.AvatarEmoji ?? "👤",
                answered = answer is not null,
                selected_answer_index = answer?.SelectedAnswerIndex,
                is_correct = answer?.IsCorrect ?? false,
                points_earned = answer?.Points ?? 0,
                elapsed_milliseconds = answer?.ElapsedMilliseconds
            };
        }).OrderByDescending(x => x.points_earned).ThenBy(x => x.elapsed_milliseconds ?? long.MaxValue).ThenBy(x => x.name).ToList();

        return new
        {
            room_id = room.Id,
            room_code = room.Code,
            question_id = question.Id,
            question_number = room.CurrentQuestionIndex + 1,
            question_count = SortedQuestions(room).Count,
            question_text = question.Text,
            options = question.Options.OrderBy(o => o.Order).Select((o, i) => new { index = i, text = o.Text }).ToList(),
            correct_answer_index = question.CorrectAnswerIndex,
            correct_answer_text = question.Options.OrderBy(o => o.Order).ElementAtOrDefault(question.CorrectAnswerIndex)?.Text,
            explanation = question.Explanation,
            answered_count = answers.Count,
            total_players = room.Members.Count,
            round_scores = questionResults,
            leaderboard = BuildLeaderboard(room),
            results_duration_seconds = ResultsDurationSeconds
        };
    }

    private static async Task<object> BuildSnapshotFromLoadedRoomAsync(AppDbContext db, StudyRoom room, int userId)
    {
        var overview = BuildOverview(room);
        var leaderboard = BuildLeaderboard(room);
        var snapshot = new Dictionary<string, object?>
        {
            ["mode"] = room.Status == "Waiting" ? "lobby" : room.Status == "Playing" ? "question" : room.Status == "ShowingResults" ? "results" : "finished",
            ["room"] = overview,
            ["leaderboard"] = leaderboard
        };
        var questions = SortedQuestions(room);
        if (room.CurrentQuestionIndex >= 0 && room.CurrentQuestionIndex < questions.Count)
        {
            var q = questions[room.CurrentQuestionIndex];
            if (room.Status == "Playing")
            {
                snapshot["question_event"] = BuildQuestionStarted(room, q);
                var answer = await db.RoomAnswers.AsNoTracking().FirstOrDefaultAsync(a => a.RoomId == room.Id && a.QuestionId == q.Id && a.UserId == userId);
                snapshot["has_answered"] = answer is not null;
                snapshot["my_answer_index"] = answer?.SelectedAnswerIndex;
                snapshot["answered_count"] = await db.RoomAnswers.CountAsync(a => a.RoomId == room.Id && a.QuestionId == q.Id);
            }
            else if (room.Status == "ShowingResults")
            {
                var answers = await db.RoomAnswers.Include(a => a.User).Where(a => a.RoomId == room.Id && a.QuestionId == q.Id).OrderBy(a => a.AnsweredAt).ToListAsync();
                snapshot["result"] = BuildQuestionResult(room, q, answers);
            }
        }
        return snapshot;
    }

    private static object BuildOverview(StudyRoom room)
    {
        UpdateRanks(room);
        return new
        {
            id = room.Id,
            code = room.Code,
            status = room.Status.ToLowerInvariant(),
            host = new { id = room.Host?.Id, name = room.Host?.Name, avatar_emoji = room.Host?.AvatarEmoji },
            quiz_id = room.QuizId,
            quiz_title = room.Quiz?.Title,
            max_players = room.MaxPlayers,
            duration_minutes = room.DurationMinutes,
            question_duration_seconds = room.RoundDurationSeconds,
            current_question_index = room.CurrentQuestionIndex,
            current_round_number = room.CurrentRoundNumber,
            current_round_started_at = room.CurrentRoundStartedAt,
            results_shown_at = room.RoundResultsShownAt,
            current_players = room.Members.Count,
            can_join = room.Status == "Waiting" && room.Members.Count < room.MaxPlayers,
            players = room.Members.Select(m => new
            {
                id = m.UserId,
                name = m.User?.Name ?? "Người chơi",
                avatar_emoji = m.User?.AvatarEmoji ?? "👤",
                score = m.Score ?? 0,
                correct_answers = m.CorrectAnswers ?? 0,
                rank = m.Rank
            })
        };
    }

    private static List<object> BuildLeaderboard(StudyRoom room)
    {
        UpdateRanks(room);
        return room.Members.OrderByDescending(m => m.Score ?? 0)
            .ThenByDescending(m => m.CorrectAnswers ?? 0).ThenBy(m => m.User?.Name)
            .Select((m, index) => (object)new
            {
                rank = index + 1,
                user_id = m.UserId,
                name = m.User?.Name ?? "Người chơi",
                avatar_emoji = m.User?.AvatarEmoji ?? "👤",
                score = m.Score ?? 0,
                correct_answers = m.CorrectAnswers ?? 0
            }).ToList();
    }

    private static void UpdateRanks(StudyRoom room)
    {
        var ranked = room.Members.OrderByDescending(m => m.Score ?? 0)
            .ThenByDescending(m => m.CorrectAnswers ?? 0).ThenBy(m => m.User?.Name).ToList();
        for (var i = 0; i < ranked.Count; i++) ranked[i].Rank = i + 1;
    }
}
