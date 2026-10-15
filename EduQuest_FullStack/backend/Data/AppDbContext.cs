using EduQuest.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace EduQuest.Api.Data;
public class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options) {
 public DbSet<AppUser> Users => Set<AppUser>();
 public DbSet<Quiz> Quizzes => Set<Quiz>();
 public DbSet<Question> Questions => Set<Question>();
 public DbSet<QuestionOption> QuestionOptions => Set<QuestionOption>();
 public DbSet<QuizAttempt> QuizAttempts => Set<QuizAttempt>();
 public DbSet<StudyRoom> StudyRooms => Set<StudyRoom>();
 public DbSet<RoomMember> RoomMembers => Set<RoomMember>();
 public DbSet<RoomAnswer> RoomAnswers => Set<RoomAnswer>();
 public DbSet<UploadedFile> UploadedFiles => Set<UploadedFile>();
 protected override void OnModelCreating(ModelBuilder b) {
  b.Entity<AppUser>().HasIndex(x=>x.Email).IsUnique();
  b.Entity<StudyRoom>().HasIndex(x=>x.Code).IsUnique();
  b.Entity<RoomMember>().HasIndex(x=>new{x.RoomId,x.UserId}).IsUnique();
  b.Entity<RoomAnswer>().HasIndex(x=>new{x.RoomId,x.QuestionId,x.UserId}).IsUnique();
  b.Entity<Quiz>().HasMany(x=>x.Questions).WithOne(x=>x.Quiz).HasForeignKey(x=>x.QuizId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<Question>().HasMany(x=>x.Options).WithOne(x=>x.Question).HasForeignKey(x=>x.QuestionId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<QuizAttempt>().HasOne(x=>x.User).WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<QuizAttempt>().HasOne(x=>x.Quiz).WithMany().HasForeignKey(x=>x.QuizId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<StudyRoom>().HasOne(x=>x.Host).WithMany().HasForeignKey(x=>x.HostId).OnDelete(DeleteBehavior.Restrict);
  b.Entity<StudyRoom>().HasOne(x=>x.Quiz).WithMany().HasForeignKey(x=>x.QuizId).OnDelete(DeleteBehavior.Restrict);
  b.Entity<RoomMember>().HasOne(x=>x.Room).WithMany(x=>x.Members).HasForeignKey(x=>x.RoomId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<RoomMember>().HasOne(x=>x.User).WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<RoomAnswer>().HasOne(x=>x.Room).WithMany(x=>x.Answers).HasForeignKey(x=>x.RoomId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<RoomAnswer>().HasOne(x=>x.Question).WithMany().HasForeignKey(x=>x.QuestionId).OnDelete(DeleteBehavior.Cascade);
  b.Entity<RoomAnswer>().HasOne(x=>x.User).WithMany().HasForeignKey(x=>x.UserId).OnDelete(DeleteBehavior.Cascade);
 }
}
