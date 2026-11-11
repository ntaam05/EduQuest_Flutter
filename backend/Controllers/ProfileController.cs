using System.Security.Claims;
using EduQuest.Api.Data;
using EduQuest.Api.Dtos;
using EduQuest.Api.Models;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Controllers;

[Authorize, ApiController, Route("api/profile")]
public class ProfileController(AppDbContext db) : ControllerBase
{
    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        var user = await db.Users.FindAsync(UserId);
        return user is null ? NotFound(new { message = "Không tìm thấy tài khoản." }) : Ok(ToDto(user));
    }

    [HttpPut]
    public async Task<IActionResult> Update(UpdateProfileRequest request)
    {
        var user = await db.Users.FindAsync(UserId);
        if (user is null) return NotFound(new { message = "Không tìm thấy tài khoản." });
        if (request.Name is not null)
        {
            if (string.IsNullOrWhiteSpace(request.Name)) return BadRequest(new { message = "Tên không được để trống." });
            user.Name = request.Name.Trim();
        }
        if (request.AvatarUrl is not null) user.AvatarUrl = request.AvatarUrl.Trim();
        if (request.AvatarEmoji is not null) user.AvatarEmoji = request.AvatarEmoji.Trim();
        if (request.DarkMode.HasValue) user.DarkMode = request.DarkMode.Value;
        if (request.NotificationsEnabled.HasValue) user.NotificationsEnabled = request.NotificationsEnabled.Value;
        if (request.Language is not null) user.Language = request.Language;
        await db.SaveChangesAsync();
        return Ok(ToDto(user));
    }

    [HttpGet("stats")]
    public async Task<IActionResult> Stats()
    {
        var attempts = await db.QuizAttempts.AsNoTracking()
            .Where(x => x.UserId == UserId && x.SubmittedAt != null)
            .OrderBy(x => x.SubmittedAt).ToListAsync();
        var cutoff = DateTime.UtcNow.AddDays(-7);
        var recent = attempts.Where(x => x.SubmittedAt.HasValue && x.SubmittedAt.Value >= cutoff).ToList();
        return Ok(new
        {
            total_quizzes = attempts.Count,
            total_questions = attempts.Sum(x => x.TotalQuestions),
            average_score = attempts.Count == 0 ? 0 : Math.Round(attempts.Average(x => x.ScorePercent), 2),
            weekly_completed = recent.Count,
            total_study_hours = Math.Round(attempts.Sum(x => x.TimeSpentSeconds) / 3600d, 2),
            weekly_scores = recent.Select(x => new { date = x.SubmittedAt, score = x.ScorePercent })
        });
    }

    private static object ToDto(AppUser user) => new
    {
        id = user.Id, name = user.Name, email = user.Email, role = user.Role,
        avatar_url = user.AvatarUrl, avatar_emoji = user.AvatarEmoji,
        total_quizzes = user.TotalQuizzes, total_questions = user.TotalQuestions,
        average_score = user.AverageScore, streak_days = user.StreakDays, xp = user.Xp,
        dark_mode = user.DarkMode, notifications_enabled = user.NotificationsEnabled,
        language = user.Language, created_at = user.CreatedAt
    };
}
