using System.ComponentModel.DataAnnotations;
using Microsoft.AspNetCore.Http;
namespace EduQuest.Api.Dtos;
public record RegisterRequest([Required,MaxLength(120)] string Name,[Required,EmailAddress,MaxLength(256)] string Email,[Required,MinLength(8),MaxLength(100)] string Password);
public record LoginRequest([Required,EmailAddress] string Email,[Required] string Password);
public record ChangePasswordRequest([Required] string CurrentPassword,[Required,MinLength(8),MaxLength(100)] string NewPassword);
public record UpdateProfileRequest([MaxLength(120)] string? Name,string? AvatarUrl,[MaxLength(16)] string? AvatarEmoji,bool? DarkMode,bool? NotificationsEnabled,[RegularExpression("^(vi|en)$")] string? Language);
public record OptionRequest([Required,MaxLength(1000)] string Text);
public record QuestionRequest([Required,MaxLength(3000)] string Text,[MinLength(2)] List<OptionRequest> Options,[Range(0,20)] int CorrectAnswerIndex,string? Explanation);
public record CreateQuizRequest([Required,MaxLength(200)] string Title,[Required,MaxLength(100)] string Subject,string? Description,[Range(1,300)] int DurationMinutes,string? IconEmoji,string? ThumbnailUrl,[MinLength(1)] List<QuestionRequest> Questions);
public record SubmitAttemptRequest(Dictionary<int,int> Answers,int TimeSpentSeconds);
public record CreateRoomRequest([Required] string QuizId,[Range(2,100)] int MaxPlayers,[Range(1,300)] int DurationMinutes,[Range(20,30)] int QuestionDurationSeconds=25);
public record JoinRoomRequest([Required,MinLength(6),MaxLength(6)] string Code);
public class UploadQuizFileRequest
{
    public IFormFile? File { get; set; }
    public string Title { get; set; } = string.Empty;
    public string Subject { get; set; } = string.Empty;
    public string? Description { get; set; }
}