using System.Security.Claims;
using EduQuest.Api.Data;
using EduQuest.Api.Dtos;
using EduQuest.Api.Models;
using EduQuest.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Controllers;

[ApiController, Route("api/auth")]
public class AuthController(AppDbContext db, TokenService tokens) : ControllerBase
{
    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    /// Đăng ký tài khoản mới, trả về token để đăng nhập luôn.
    [HttpPost("register")]
    public async Task<IActionResult> Register(RegisterRequest r)
    {
        var name = r.Name.Trim();
        var email = r.Email.Trim().ToLowerInvariant();
        if (name.Length == 0) return BadRequest(new { message = "Vui lòng nhập họ tên." });
        if (await db.Users.AnyAsync(x => x.Email == email))
            return Conflict(new { message = "Email đã được sử dụng." });

        var user = new AppUser
        {
            Name = name,
            Email = email,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(r.Password),
            AvatarEmoji = "👤"
        };
        db.Users.Add(user);
        await db.SaveChangesAsync();
        return Ok(new { token = tokens.Create(user), user = PublicUser(user) });
    }

    /// Đăng nhập bằng email + mật khẩu.
    [HttpPost("login")]
    public async Task<IActionResult> Login(LoginRequest r)
    {
        var email = r.Email.Trim().ToLowerInvariant();
        var user = await db.Users.SingleOrDefaultAsync(x => x.Email == email);
        if (user is null || !BCrypt.Net.BCrypt.Verify(r.Password, user.PasswordHash))
            return Unauthorized(new { message = "Email hoặc mật khẩu không đúng." });
        return Ok(new { token = tokens.Create(user), user = PublicUser(user) });
    }

    /// Thông tin tài khoản đang đăng nhập; app dùng để kiểm tra token còn hiệu lực khi mở lại.
    [Authorize, HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var user = await db.Users.AsNoTracking().FirstOrDefaultAsync(x => x.Id == UserId);
        if (user is null) return Unauthorized(new { message = "Tài khoản không còn tồn tại." });
        return Ok(PublicUser(user));
    }

    /// Đổi mật khẩu (sai mật khẩu hiện tại trả 400, không trả 401 để app không tự đăng xuất).
    [Authorize, HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword(ChangePasswordRequest r)
    {
        var user = await db.Users.FirstOrDefaultAsync(x => x.Id == UserId);
        if (user is null) return Unauthorized(new { message = "Tài khoản không còn tồn tại." });
        if (!BCrypt.Net.BCrypt.Verify(r.CurrentPassword, user.PasswordHash))
            return BadRequest(new { message = "Mật khẩu hiện tại không đúng." });
        if (r.CurrentPassword == r.NewPassword)
            return BadRequest(new { message = "Mật khẩu mới phải khác mật khẩu hiện tại." });
        user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(r.NewPassword);
        await db.SaveChangesAsync();
        return NoContent();
    }

    private static object PublicUser(AppUser u) => new
    {
        id = u.Id,
        name = u.Name,
        email = u.Email,
        role = u.Role,
        avatar_url = u.AvatarUrl,
        avatar_emoji = u.AvatarEmoji,
        total_quizzes = u.TotalQuizzes,
        total_questions = u.TotalQuestions,
        average_score = u.AverageScore,
        streak_days = u.StreakDays,
        xp = u.Xp
    };
}
