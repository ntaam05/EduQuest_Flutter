using System.Security.Claims;
using System.Text.Json;
using EduQuest.Api.Data;
using EduQuest.Api.Dtos;
using EduQuest.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Controllers;

[Authorize, ApiController, Route("api/quizzes")]
public class QuizzesController(AppDbContext db) : ControllerBase
{
    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> List([FromQuery] string? search, [FromQuery] string? subject)
    {
        // Chỉ đưa bài đã có câu hỏi vào thư viện để người dùng không thể mở bản nháp rỗng.
        var query = db.Quizzes
            .Include(x => x.Questions).ThenInclude(x => x.Options)
            .Where(x => x.Questions.Any())
            .AsNoTracking().AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
        {
            var term = search.Trim();
            query = query.Where(x => x.Title.Contains(term) || x.Subject.Contains(term) ||
                                     (x.Description != null && x.Description.Contains(term)));
        }
        if (!string.IsNullOrWhiteSpace(subject)) query = query.Where(x => x.Subject == subject.Trim());

        var quizzes = await query.OrderByDescending(x => x.CreatedAt).ToListAsync();
        var attempts = await db.QuizAttempts.AsNoTracking()
            .Where(x => x.UserId == UserId)
            .OrderByDescending(x => x.StartedAt)
            .ToListAsync();

        return Ok(quizzes.Select(q =>
        {
            var latest = attempts.FirstOrDefault(a => a.QuizId == q.Id);
            var status = latest == null ? "notStarted" : latest.SubmittedAt == null ? "inProgress" : "completed";
            var score = latest?.SubmittedAt == null ? (double?)null : latest.ScorePercent / 10d;
            return ToDto(q, status, score, latest?.SubmittedAt == null ? 0d : 1d, q.OwnerId == UserId);
        }));
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(string id)
    {
        var quiz = await db.Quizzes
            .Include(x => x.Questions.OrderBy(y => y.Order))
            .ThenInclude(x => x.Options.OrderBy(y => y.Order))
            .AsNoTracking().FirstOrDefaultAsync(x => x.Id == id);
        if (quiz is null) return NotFound(new { message = "Không tìm thấy bài trắc nghiệm." });

        var latest = await db.QuizAttempts.AsNoTracking()
            .Where(x => x.UserId == UserId && x.QuizId == id)
            .OrderByDescending(x => x.StartedAt).FirstOrDefaultAsync();
        var status = latest == null ? "notStarted" : latest.SubmittedAt == null ? "inProgress" : "completed";
        double? score = latest?.SubmittedAt == null ? null : latest.ScorePercent / 10d;
        return Ok(ToDto(quiz, status, score, latest?.SubmittedAt == null ? 0d : 1d, quiz.OwnerId == UserId));
    }

    [HttpPost]
    public async Task<IActionResult> Create(CreateQuizRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Subject))
            return BadRequest(new { message = "Tên bài và môn học không được để trống." });
        if (request.Questions is null || request.Questions.Count == 0)
            return BadRequest(new { message = "Bài thi phải có ít nhất một câu hỏi." });

        var quiz = new Quiz
        {
            Id = Guid.NewGuid().ToString("N"),
            Title = request.Title.Trim(), Subject = request.Subject.Trim(),
            Description = request.Description?.Trim(), DurationMinutes = request.DurationMinutes,
            IconEmoji = request.IconEmoji, ThumbnailUrl = request.ThumbnailUrl,
            OwnerId = UserId, CreatedAt = DateTime.UtcNow
        };

        foreach (var (item, index) in request.Questions.Select((question, i) => (question, i)))
        {
            if (string.IsNullOrWhiteSpace(item.Text))
                return BadRequest(new { message = $"Nội dung câu {index + 1} không được để trống." });
            if (item.Options is null || item.Options.Count < 2)
                return BadRequest(new { message = $"Câu {index + 1} phải có ít nhất 2 phương án." });
            if (item.Options.Any(option => string.IsNullOrWhiteSpace(option.Text)))
                return BadRequest(new { message = $"Câu {index + 1} có phương án trống." });
            if (item.CorrectAnswerIndex < 0 || item.CorrectAnswerIndex >= item.Options.Count)
                return BadRequest(new { message = $"Câu {index + 1}: chỉ số đáp án đúng không hợp lệ." });

            var question = new Question
            {
                Text = item.Text.Trim(), Order = index,
                CorrectAnswerIndex = item.CorrectAnswerIndex, Explanation = item.Explanation?.Trim()
            };
            for (var optionIndex = 0; optionIndex < item.Options.Count; optionIndex++)
                question.Options.Add(new QuestionOption { Text = item.Options[optionIndex].Text.Trim(), Order = optionIndex });
            quiz.Questions.Add(question);
        }

        db.Quizzes.Add(quiz);
        await db.SaveChangesAsync();
        return CreatedAtAction(nameof(Get), new { id = quiz.Id }, ToDto(quiz, "notStarted", null, 0, true));
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(string id)
    {
        var quiz = await db.Quizzes.Include(x => x.Questions).FirstOrDefaultAsync(x => x.Id == id);
        if (quiz is null) return NotFound(new { message = "Không tìm thấy bài trắc nghiệm." });
        if (quiz.OwnerId != UserId && !User.IsInRole("Admin"))
            return StatusCode(StatusCodes.Status403Forbidden, new { message = "Chỉ người tạo bài mới được xóa." });

        // Không xóa khi còn phòng đang chờ/đang chơi dùng bài này.
        var rooms = await db.StudyRooms.Where(x => x.QuizId == id).ToListAsync();
        if (rooms.Any(r => r.Status != "Finished"))
            return Conflict(new { message = "Bài này đang được dùng trong một phòng thi chưa kết thúc." });

        // Xóa phòng đã kết thúc (kéo theo thành viên/đáp án), tệp đã upload và lượt làm bài (cascade).
        db.StudyRooms.RemoveRange(rooms);
        var uploads = await db.UploadedFiles.Where(x => x.QuizId == id).ToListAsync();
        foreach (var upload in uploads)
        {
            try { if (System.IO.File.Exists(upload.StoredPath)) System.IO.File.Delete(upload.StoredPath); }
            catch { /* Không để lỗi xóa file vật lý chặn việc xóa bài. */ }
        }
        db.UploadedFiles.RemoveRange(uploads);
        db.Quizzes.Remove(quiz);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/attempts")]
    public async Task<IActionResult> StartAttempt(string id)
    {
        var quiz = await db.Quizzes.Include(x => x.Questions).FirstOrDefaultAsync(x => x.Id == id);
        if (quiz is null) return NotFound(new { message = "Không tìm thấy bài trắc nghiệm." });
        if (quiz.Questions.Count == 0) return Conflict(new { message = "Bài nháp chưa có câu hỏi nên chưa thể bắt đầu." });

        var attempt = new QuizAttempt { UserId = UserId, QuizId = id, TotalQuestions = quiz.Questions.Count };
        db.QuizAttempts.Add(attempt);
        await db.SaveChangesAsync();
        return Ok(new { id = attempt.Id, quiz_id = id, started_at = attempt.StartedAt, total_questions = attempt.TotalQuestions });
    }

    [HttpPost("attempts/{attemptId:long}/submit")]
    public async Task<IActionResult> Submit(long attemptId, SubmitAttemptRequest request)
    {
        var attempt = await db.QuizAttempts
            .Include(x => x.Quiz!).ThenInclude(x => x.Questions).ThenInclude(x => x.Options)
            .FirstOrDefaultAsync(x => x.Id == attemptId && x.UserId == UserId);
        if (attempt is null) return NotFound(new { message = "Không tìm thấy lượt làm bài." });
        if (attempt.SubmittedAt is not null) return Conflict(new { message = "Lượt làm bài đã được nộp." });
        if (request.TimeSpentSeconds < 0) return BadRequest(new { message = "Thời gian làm bài không hợp lệ." });
        if (request.Answers is null) return BadRequest(new { message = "Thiếu danh sách câu trả lời." });

        var questions = attempt.Quiz!.Questions;
        var validQuestionIds = questions.Select(q => q.Id).ToHashSet();
        if (request.Answers.Any(pair => !validQuestionIds.Contains(pair.Key) || pair.Value < 0 || pair.Value >= questions.First(q => q.Id == pair.Key).Options.Count))
            return BadRequest(new { message = "Đáp án gửi lên không hợp lệ." });

        var correct = questions.Count(q => request.Answers.TryGetValue(q.Id, out var selected) && selected == q.CorrectAnswerIndex);
        attempt.CorrectAnswers = correct;
        attempt.TotalQuestions = questions.Count;
        attempt.ScorePercent = questions.Count == 0 ? 0 : Math.Round(100d * correct / questions.Count, 2);
        attempt.TimeSpentSeconds = Math.Max(0, (int)Math.Round((DateTime.UtcNow - attempt.StartedAt).TotalSeconds));
        attempt.AnswersJson = JsonSerializer.Serialize(request.Answers);
        attempt.SubmittedAt = DateTime.UtcNow;
        attempt.Status = "Completed";

        var user = await db.Users.FindAsync(UserId);
        if (user is not null)
        {
            // Aggregate previous submissions excluding the current unsaved attempt,
            // then include this result once to avoid double counting.
            var prior = await db.QuizAttempts.AsNoTracking()
                .Where(x => x.UserId == UserId && x.Id != attempt.Id && x.SubmittedAt != null)
                .Select(x => new { x.TotalQuestions, x.ScorePercent })
                .ToListAsync();
            user.TotalQuizzes = prior.Count + 1;
            user.TotalQuestions = prior.Sum(x => x.TotalQuestions) + questions.Count;
            user.AverageScore = Math.Round((prior.Sum(x => x.ScorePercent) + attempt.ScorePercent) / user.TotalQuizzes, 2);
            user.Xp = prior.Sum(x => (int)Math.Round(x.ScorePercent)) + (int)Math.Round(attempt.ScorePercent);

            var previousSubmissionDates = await db.QuizAttempts.AsNoTracking()
                .Where(x => x.UserId == UserId && x.Id != attempt.Id && x.SubmittedAt != null)
                .Select(x => x.SubmittedAt)
                .ToListAsync();
            var submissionDays = previousSubmissionDates.Where(x => x.HasValue).Select(x => x!.Value.Date).ToHashSet();
            submissionDays.Add(attempt.SubmittedAt.Value.Date);
            var cursor = DateTime.UtcNow.Date;
            if (!submissionDays.Contains(cursor)) cursor = cursor.AddDays(-1);
            var streak = 0;
            while (submissionDays.Contains(cursor)) { streak++; cursor = cursor.AddDays(-1); }
            user.StreakDays = streak;
        }
        await db.SaveChangesAsync();

        return Ok(new
        {
            id = attempt.Id, quiz_id = attempt.QuizId, correct_answers = correct,
            total_questions = questions.Count, score_percent = attempt.ScorePercent,
            score_out_of_10 = Math.Round(attempt.ScorePercent / 10d, 2),
            time_spent_seconds = attempt.TimeSpentSeconds, answers = request.Answers,
            submitted_at = attempt.SubmittedAt, xp_earned = (int)Math.Round(attempt.ScorePercent),
            review_questions = questions.OrderBy(q => q.Order).Select(q => new
            {
                id = q.Id, correct_answer = q.CorrectAnswerIndex, explanation = q.Explanation
            })
        });
    }

    [HttpGet("attempts/mine")]
    public async Task<IActionResult> Mine() => Ok(await db.QuizAttempts
        .Where(x => x.UserId == UserId)
        .OrderByDescending(x => x.StartedAt)
        .Select(x => new
        {
            id = x.Id, quiz_id = x.QuizId, quiz_title = x.Quiz!.Title,
            started_at = x.StartedAt, submitted_at = x.SubmittedAt,
            score_percent = x.ScorePercent, correct_answers = x.CorrectAnswers,
            total_questions = x.TotalQuestions, status = x.Status
        }).ToListAsync());

    private static object ToDto(Quiz quiz, string status, double? lastScore, double progress, bool isOwner = false) => new
    {
        is_owner = isOwner,
        id = quiz.Id, title = quiz.Title, subject = quiz.Subject, description = quiz.Description,
        duration_minutes = quiz.DurationMinutes, created_at = quiz.CreatedAt,
        thumbnail_url = quiz.ThumbnailUrl, icon_emoji = quiz.IconEmoji,
        question_count = quiz.Questions.Count, status, last_score = lastScore, progress,
        questions = quiz.Questions.OrderBy(x => x.Order).Select(question => new
        {
            id = question.Id, question = question.Text,
            options = question.Options.OrderBy(x => x.Order).Select(option => option.Text),
            // Không gửi khóa đáp án trước khi nộp bài.
            correct_answer = (int?)null, explanation = (string?)null
        })
    };
}
