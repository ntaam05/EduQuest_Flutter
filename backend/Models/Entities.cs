using System.ComponentModel.DataAnnotations;
namespace EduQuest.Api.Models;

public class AppUser {
    public int Id { get; set; }
    [MaxLength(120)] public string Name { get; set; } = "";
    [Required, MaxLength(256)] public string Email { get; set; } = "";
    [Required] public string PasswordHash { get; set; } = "";
    [MaxLength(20)] public string Role { get; set; } = "Student";
    [MaxLength(500)] public string? AvatarUrl { get; set; }
    [MaxLength(16)] public string? AvatarEmoji { get; set; } = "👤";
    public int TotalQuizzes { get; set; }
    public int TotalQuestions { get; set; }
    public double AverageScore { get; set; }
    public int StreakDays { get; set; }
    public int Xp { get; set; }
    public bool DarkMode { get; set; }
    public bool NotificationsEnabled { get; set; } = true;
    [MaxLength(5)] public string Language { get; set; } = "vi";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
public class Quiz {
    [Key, MaxLength(80)] public string Id { get; set; } = Guid.NewGuid().ToString("N");
    [Required, MaxLength(200)] public string Title { get; set; } = "";
    [Required, MaxLength(100)] public string Subject { get; set; } = "";
    [MaxLength(2000)] public string? Description { get; set; }
    public int DurationMinutes { get; set; } = 15;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    [MaxLength(500)] public string? ThumbnailUrl { get; set; }
    [MaxLength(16)] public string? IconEmoji { get; set; } = "📝";
    public int? OwnerId { get; set; }
    public AppUser? Owner { get; set; }
    public List<Question> Questions { get; set; } = [];
}
public class Question {
    public int Id { get; set; }
    [Required, MaxLength(3000)] public string Text { get; set; } = "";
    public int Order { get; set; }
    public List<QuestionOption> Options { get; set; } = [];
    public int CorrectAnswerIndex { get; set; }
    [MaxLength(3000)] public string? Explanation { get; set; }
    public string QuizId { get; set; } = "";
    public Quiz? Quiz { get; set; }
}
public class QuestionOption {
    public int Id { get; set; }
    [Required, MaxLength(1000)] public string Text { get; set; } = "";
    public int Order { get; set; }
    public int QuestionId { get; set; }
    public Question? Question { get; set; }
}
public class QuizAttempt {
    public long Id { get; set; }
    public int UserId { get; set; }
    public AppUser? User { get; set; }
    public string QuizId { get; set; } = "";
    public Quiz? Quiz { get; set; }
    public DateTime StartedAt { get; set; } = DateTime.UtcNow;
    public DateTime? SubmittedAt { get; set; }
    public int TotalQuestions { get; set; }
    public int CorrectAnswers { get; set; }
    public double ScorePercent { get; set; }
    public int TimeSpentSeconds { get; set; }
    public string AnswersJson { get; set; } = "{}";
    public string Status { get; set; } = "InProgress";
}
public class StudyRoom {
    [Key, MaxLength(80)] public string Id { get; set; } = Guid.NewGuid().ToString("N");
    [Required, MaxLength(6)] public string Code { get; set; } = "";
    public int HostId { get; set; }
    public AppUser? Host { get; set; }
    public string QuizId { get; set; } = "";
    public Quiz? Quiz { get; set; }
    public int MaxPlayers { get; set; } = 10;
    public int DurationMinutes { get; set; } = 15;
    /// <summary>Thời gian cho mỗi câu hỏi, tính bằng giây (mặc định 25s).</summary>
    public int RoundDurationSeconds { get; set; } = 25;
    /// <summary>Waiting, Playing, ShowingResults, Finished.</summary>
    [MaxLength(20)] public string Status { get; set; } = "Waiting";
    public int CurrentQuestionIndex { get; set; } = -1;
    public int CurrentRoundNumber { get; set; }
    public DateTime? CurrentRoundStartedAt { get; set; }
    public DateTime? RoundResultsShownAt { get; set; }
    public DateTime? FinishedAt { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public List<RoomMember> Members { get; set; } = [];
    public List<RoomAnswer> Answers { get; set; } = [];
}
public class RoomAnswer {
    public long Id { get; set; }
    [Required, MaxLength(80)] public string RoomId { get; set; } = "";
    public StudyRoom? Room { get; set; }
    public int QuestionId { get; set; }
    public Question? Question { get; set; }
    public int UserId { get; set; }
    public AppUser? User { get; set; }
    public int SelectedAnswerIndex { get; set; }
    public bool IsCorrect { get; set; }
    public int Points { get; set; }
    public long ElapsedMilliseconds { get; set; }
    public DateTime AnsweredAt { get; set; } = DateTime.UtcNow;
}
public class RoomMember {
    public int Id { get; set; }
    public string RoomId { get; set; } = "";
    public StudyRoom? Room { get; set; }
    public int UserId { get; set; }
    public AppUser? User { get; set; }
    public DateTime JoinedAt { get; set; } = DateTime.UtcNow;
    public int? Score { get; set; }
    public int? CorrectAnswers { get; set; }
    public int? Rank { get; set; }
}
public class UploadedFile {
    public long Id { get; set; }
    public int OwnerId { get; set; }
    public AppUser? Owner { get; set; }
    [MaxLength(255)] public string OriginalName { get; set; } = "";
    [MaxLength(500)] public string StoredPath { get; set; } = "";
    [MaxLength(10)] public string Extension { get; set; } = "";
    public long SizeBytes { get; set; }
    public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    public string? QuizId { get; set; }
    public Quiz? Quiz { get; set; }
}
