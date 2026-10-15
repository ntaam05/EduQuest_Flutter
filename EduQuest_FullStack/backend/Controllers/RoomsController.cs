using System.Security.Claims;
using EduQuest.Api.Data;
using EduQuest.Api.Dtos;
using EduQuest.Api.Models;
using EduQuest.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Controllers;

[Authorize, ApiController, Route("api/rooms")]
public sealed class RoomsController(AppDbContext db, RoomGameService games) : ControllerBase
{
    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> List()
    {
        var rows = await db.StudyRooms
            .Where(x => x.Status == "Waiting" || x.Status == "Playing" || x.Status == "ShowingResults")
            .Include(x => x.Host).Include(x => x.Quiz)
            .Include(x => x.Members).ThenInclude(x => x.User).AsNoTracking()
            .OrderByDescending(x => x.CreatedAt).ToListAsync();
        return Ok(rows.Select(Dto));
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateRoomRequest request)
    {
        var quiz = await db.Quizzes.Include(x => x.Questions).ThenInclude(x => x.Options)
            .FirstOrDefaultAsync(x => x.Id == request.QuizId);
        if (quiz is null) return NotFound(new { message = "Không tìm thấy bài thi." });
        if (quiz.Questions.Count == 0) return Conflict(new { message = "Bài nháp chưa có câu hỏi nên chưa thể tạo phòng thi." });
        if (request.QuestionDurationSeconds is < 20 or > 30)
            return BadRequest(new { message = "Thời gian mỗi câu phải từ 20 đến 30 giây." });

        var room = new StudyRoom
        {
            Id = Guid.NewGuid().ToString("N"),
            Code = await NewCodeAsync(),
            HostId = UserId,
            QuizId = request.QuizId,
            MaxPlayers = request.MaxPlayers,
            DurationMinutes = request.DurationMinutes,
            RoundDurationSeconds = request.QuestionDurationSeconds,
            Status = "Waiting"
        };
        room.Members.Add(new RoomMember { UserId = UserId, Score = 0, CorrectAnswers = 0 });
        db.StudyRooms.Add(room);
        await db.SaveChangesAsync();
        var loaded = await Load(room.Id);
        return CreatedAtAction(nameof(Get), new { id = room.Id }, Dto(loaded!));
    }

    [HttpGet("code/{code}")]
    public async Task<IActionResult> GetByCode(string code)
    {
        var normalized = code.Trim().ToUpperInvariant();
        var room = await db.StudyRooms.AsNoTracking().Where(r => r.Code == normalized)
            .Select(r => new { r.Id }).FirstOrDefaultAsync();
        if (room is null) return NotFound(new { message = "Không tìm thấy phòng." });
        var loaded = await Load(room.Id);
        if (loaded is null) return NotFound(new { message = "Không tìm thấy phòng." });
        return Ok(Dto(loaded));
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> Get(string id)
    {
        var room = await Load(id);
        return room is null ? NotFound(new { message = "Không tìm thấy phòng." }) : Ok(Dto(room));
    }

    [HttpGet("{id}/game-state")]
    public async Task<IActionResult> GameState(string id)
    {
        var snapshot = await games.GetSnapshotAsync(id, UserId);
        return snapshot is null
            ? NotFound(new { message = "Không tìm thấy phòng hoặc bạn không phải thành viên." })
            : Ok(snapshot);
    }

    [HttpPost("join")]
    public async Task<IActionResult> Join([FromBody] JoinRoomRequest request)
    {
        var normalized = request.Code.Trim().ToUpperInvariant();
        var room = await db.StudyRooms.Include(x => x.Members).FirstOrDefaultAsync(x => x.Code == normalized);
        if (room is null) return NotFound(new { message = "Không tìm thấy phòng." });
        // Allow a prior member to reopen/reconnect to the same room after app/network reconnect.
        if (room.Members.Any(x => x.UserId == UserId)) return Ok(Dto((await Load(room.Id))!));
        if (room.Status != "Waiting") return Conflict(new { message = "Trận đã bắt đầu; người mới không thể vào giữa trận." });
        if (room.Members.Count >= room.MaxPlayers) return Conflict(new { message = "Phòng đã đầy." });
        room.Members.Add(new RoomMember { UserId = UserId, Score = 0, CorrectAnswers = 0 });
        await db.SaveChangesAsync();
        var loaded = (await Load(room.Id))!;
        return Ok(Dto(loaded));
    }

    public sealed record SubmitRoomAnswerRequest(int QuestionId, int SelectedAnswerIndex);

    [HttpPost("{id}/answers")]
    public async Task<IActionResult> SubmitAnswerHttp(string id, [FromBody] SubmitRoomAnswerRequest request)
    {
        try
        {
            var result = await games.SubmitAnswerAsync(id, UserId, request.QuestionId, request.SelectedAnswerIndex);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    [HttpPost("{id}/leave")]
    public async Task<IActionResult> Leave(string id)
    {
        var room = await db.StudyRooms.Include(x => x.Members).FirstOrDefaultAsync(x => x.Id == id);
        if (room is null) return NotFound(new { message = "Không tìm thấy phòng." });
        // Kết quả của một vòng phải giữ được cả khi người chơi đóng app/mất mạng.
        if (room.Status is "Playing" or "ShowingResults")
            return Conflict(new { message = "Trận đang diễn ra. Bạn có thể rời màn hình, nhưng không thể xóa tư cách thành viên giữa trận." });
        var member = room.Members.FirstOrDefault(x => x.UserId == UserId);
        if (member is not null) db.RoomMembers.Remove(member);
        if (room.HostId == UserId && room.Status == "Waiting") db.StudyRooms.Remove(room);
        await db.SaveChangesAsync();
        return NoContent();
    }

    [HttpPost("{id}/start")]
    public async Task<IActionResult> Start(string id)
    {
        var room = await db.StudyRooms.AsNoTracking().FirstOrDefaultAsync(x => x.Id == id);
        if (room is null) return NotFound(new { message = "Không tìm thấy phòng." });
        if (room.HostId != UserId) return Forbid();
        try
        {
            await games.StartAsync(id, UserId);
            return Ok(await games.GetRoomOverviewAsync(id));
        }
        catch (InvalidOperationException ex)
        {
            return Conflict(new { message = ex.Message });
        }
    }

    private async Task<StudyRoom?> Load(string id) => await db.StudyRooms
        .Include(x => x.Host)
        .Include(x => x.Quiz).ThenInclude(x => x!.Questions).ThenInclude(x => x.Options)
        .Include(x => x.Members).ThenInclude(x => x.User)
        .AsNoTracking().FirstOrDefaultAsync(x => x.Id == id);

    private async Task<string> NewCodeAsync()
    {
        const string chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
        var random = Random.Shared;
        for (var attempt = 0; attempt < 30; attempt++)
        {
            var code = new string(Enumerable.Range(0, 6).Select(_ => chars[random.Next(chars.Length)]).ToArray());
            if (!await db.StudyRooms.AnyAsync(x => x.Code == code)) return code;
        }
        throw new InvalidOperationException("Không thể sinh mã phòng duy nhất; vui lòng thử lại.");
    }

    private static object Dto(StudyRoom room) => new
    {
        id = room.Id,
        code = room.Code,
        host = new { id = room.Host?.Id, name = room.Host?.Name, avatar_emoji = room.Host?.AvatarEmoji },
        quiz_id = room.QuizId,
        quiz_title = room.Quiz?.Title,
        max_players = room.MaxPlayers,
        duration_minutes = room.DurationMinutes,
        question_duration_seconds = room.RoundDurationSeconds,
        status = room.Status.ToLowerInvariant(),
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
        }).ToList()
    };
}
