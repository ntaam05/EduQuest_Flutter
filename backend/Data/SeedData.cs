using EduQuest.Api.Models;
using Microsoft.EntityFrameworkCore;
namespace EduQuest.Api.Data;
public static class SeedData {
 public static async Task InitializeAsync(AppDbContext db) {
  if (!await db.Users.AnyAsync()) {
   db.Users.Add(new AppUser { Name="Nguyễn Văn A", Email="student@eduquest.local", PasswordHash=BCrypt.Net.BCrypt.HashPassword("Student@123"), AvatarEmoji="🧑‍💻", Role="Student", Xp=0 });
   await db.SaveChangesAsync();
  }
  if (await db.Quizzes.AnyAsync()) return;
  db.Quizzes.AddRange(
   Make("quiz_flutter_01","Flutter Cơ Bản","Lập trình di động","Kiểm tra kiến thức cơ bản về Flutter framework và Dart.",15,"📱",[
    ("Flutter được phát triển bởi công ty nào?",new[]{"Microsoft","Google","Apple","Meta"},1,"Flutter được phát triển bởi Google."),
    ("Ngôn ngữ lập trình chính của Flutter là gì?",new[]{"JavaScript","Kotlin","Dart","Swift"},2,"Flutter sử dụng Dart."),
    ("Widget nào sắp xếp phần tử theo chiều dọc?",new[]{"Row","Stack","Column","Wrap"},2,"Column sắp xếp theo chiều dọc.")
   ]),
   Make("quiz_db_01","Cơ Sở Dữ Liệu","Cơ sở dữ liệu","Ôn tập SQL và các khái niệm database quan trọng.",20,"🗄️",[
    ("SQL là viết tắt của gì?",new[]{"Structured Query Language","Simple Query Logic","Standard Query List","System Query Language"},0,"SQL là Structured Query Language."),
    ("Lệnh nào dùng để lấy dữ liệu?",new[]{"INSERT","UPDATE","SELECT","DELETE"},2,"SELECT truy vấn dữ liệu."),
    ("Primary Key có đặc điểm gì?",new[]{"Có thể trùng","Có thể NULL","Duy nhất và không NULL","Chỉ dùng một bảng"},2,"Khóa chính là duy nhất và không NULL.")
   ]),
   Make("quiz_oop_01","Lập Trình Hướng Đối Tượng","Lập trình","Các khái niệm OOP quan trọng.",15,"🏗️",[
    ("Đóng gói (Encapsulation) nhằm mục đích gì?",new[]{"Ẩn và kiểm soát dữ liệu","Tạo nhiều tiến trình","Biên dịch code","Xóa class"},0,"Đóng gói kiểm soát truy cập dữ liệu."),
    ("Kế thừa trong OOP cho phép?",new[]{"Một lớp kế thừa đặc điểm lớp khác","Chỉ tạo biến","Chỉ gọi hàm tĩnh","Xóa đối tượng"},0,"Inheritance tái sử dụng đặc điểm lớp cha.")
   ])
  );
  await db.SaveChangesAsync();
 }
 static Quiz Make(string id,string title,string subject,string desc,int duration,string emoji,(string q,string[] opts,int correct,string exp)[] items) {
  var quiz=new Quiz{Id=id,Title=title,Subject=subject,Description=desc,DurationMinutes=duration,IconEmoji=emoji,CreatedAt=DateTime.UtcNow};
  var i=0; foreach(var item in items) { var q=new Question{Text=item.q,Order=i++,CorrectAnswerIndex=item.correct,Explanation=item.exp}; var j=0; foreach(var opt in item.opts) q.Options.Add(new QuestionOption{Text=opt,Order=j++}); quiz.Questions.Add(q); }
  return quiz;
 }
}
