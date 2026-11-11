using System.Diagnostics;
using System.Security.Claims;
using System.Text;
using EduQuest.Api.Data;
using EduQuest.Api.Dtos;
using EduQuest.Api.Models;
using EduQuest.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace EduQuest.Api.Controllers;

[Authorize, ApiController, Route("api/uploads")]
public sealed class UploadsController(AppDbContext db, IWebHostEnvironment env, QuizDocumentParser parser) : ControllerBase
{
    private static readonly HashSet<string> Allowed = [".pdf", ".docx", ".xlsx", ".txt"];
    private const long MaxBytes = 10 * 1024 * 1024;
    private static readonly SemaphoreSlim PickLock = new(1, 1);

    private int UserId => int.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)!);

    // Thư mục trên MÁY TÍNH chạy API: người dùng chép file vào đây, app (kể cả trên Android Emulator) sẽ thấy và nhập được.
    private string InboxPath
    {
        get
        {
            var path = Path.Combine(env.ContentRootPath, "inbox");
            Directory.CreateDirectory(path);
            return path;
        }
    }

    private string UploadRoot
    {
        get
        {
            var path = Path.Combine(env.ContentRootPath, "uploads");
            Directory.CreateDirectory(path);
            return path;
        }
    }

    public sealed record ImportInboxRequest(string FileName, string Title, string Subject, string? Description);

    [HttpPost("quiz-file")]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(11 * 1024 * 1024)]
    public async Task<IActionResult> Upload([FromForm] UploadQuizFileRequest request, CancellationToken cancellationToken)
    {
        var file = request.File;
        if (file is null || file.Length == 0) return BadRequest(new { message = "Vui lòng chọn file." });
        if (file.Length > MaxBytes) return BadRequest(new { message = "File tối đa 10 MB." });
        var extension = Path.GetExtension(file.FileName).ToLowerInvariant();
        if (!Allowed.Contains(extension)) return BadRequest(new { message = "Chỉ hỗ trợ PDF, DOCX, XLSX, TXT." });
        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Subject))
            return BadRequest(new { message = "Tên bài và môn học là bắt buộc." });

        var path = Path.Combine(UploadRoot, Guid.NewGuid().ToString("N") + extension);
        await using (var output = System.IO.File.Create(path)) await file.CopyToAsync(output, cancellationToken);

        return await CreateQuizFromStoredFileAsync(path, Path.GetFileName(file.FileName), file.Length, extension,
            request.Title, request.Subject, request.Description, cancellationToken);
    }

    /// Mở hộp thoại "Chọn file" của Windows NGAY TRÊN MÁY TÍNH chạy API (dùng cho Android Emulator/điện thoại).
    /// File được chọn sẽ được chép vào thư mục inbox rồi nhập bằng POST /api/uploads/inbox/import.
    /// Chỉ hoạt động khi API chạy ở chế độ Development trên Windows.
    [HttpPost("pick-from-pc")]
    public async Task<IActionResult> PickFromPc(CancellationToken cancellationToken)
    {
        if (!env.IsDevelopment() || !OperatingSystem.IsWindows())
            return StatusCode(StatusCodes.Status501NotImplemented,
                new { message = "Hộp thoại chọn file trên máy tính chỉ chạy khi API ở chế độ Development trên Windows." });
        if (!await PickLock.WaitAsync(0, cancellationToken))
            return Conflict(new { message = "Đang có một hộp thoại chọn file mở trên máy tính." });

        try
        {
            const string script = """
                Add-Type -AssemblyName System.Windows.Forms
                [System.Windows.Forms.Application]::EnableVisualStyles()
                $top = New-Object System.Windows.Forms.Form
                $top.TopMost = $true
                $top.ShowInTaskbar = $false
                $top.Opacity = 0
                $top.StartPosition = 'CenterScreen'
                $top.Show()
                $dialog = New-Object System.Windows.Forms.OpenFileDialog
                $dialog.Title = 'EduQuest - Chon tai lieu cau hoi'
                $dialog.Filter = 'Tai lieu (*.pdf;*.docx;*.xlsx;*.txt)|*.pdf;*.docx;*.xlsx;*.txt'
                $dialog.CheckFileExists = $true
                if ($dialog.ShowDialog($top) -eq [System.Windows.Forms.DialogResult]::OK) {
                    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
                    Write-Output $dialog.FileName
                }
                $top.Close()
                """;
            var startInfo = new ProcessStartInfo("powershell.exe")
            {
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true,
                StandardOutputEncoding = Encoding.UTF8
            };
            startInfo.ArgumentList.Add("-NoProfile");
            startInfo.ArgumentList.Add("-STA");
            startInfo.ArgumentList.Add("-ExecutionPolicy");
            startInfo.ArgumentList.Add("Bypass");
            startInfo.ArgumentList.Add("-EncodedCommand");
            startInfo.ArgumentList.Add(Convert.ToBase64String(Encoding.Unicode.GetBytes(script)));

            using var process = Process.Start(startInfo);
            if (process is null)
                return StatusCode(StatusCodes.Status501NotImplemented, new { message = "Không mở được PowerShell trên máy tính." });

            using var timeout = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
            timeout.CancelAfter(TimeSpan.FromMinutes(5));
            string output;
            try
            {
                output = (await process.StandardOutput.ReadToEndAsync(timeout.Token)).Trim();
                await process.WaitForExitAsync(timeout.Token);
            }
            catch (OperationCanceledException)
            {
                try { process.Kill(entireProcessTree: true); } catch { /* đã đóng */ }
                if (cancellationToken.IsCancellationRequested) throw;
                return Ok(new { picked = false, message = "Hết thời gian chờ chọn file." });
            }

            var picked = output.Split('\n', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).FirstOrDefault();
            if (string.IsNullOrWhiteSpace(picked) || !System.IO.File.Exists(picked))
                return Ok(new { picked = false });

            var extension = Path.GetExtension(picked).ToLowerInvariant();
            if (!Allowed.Contains(extension)) return BadRequest(new { message = "Chỉ hỗ trợ PDF, DOCX, XLSX, TXT." });
            var length = new FileInfo(picked).Length;
            if (length == 0) return BadRequest(new { message = "File rỗng." });
            if (length > MaxBytes) return BadRequest(new { message = "File tối đa 10 MB." });

            // Chép vào inbox (đổi tên nếu trùng) để dùng lại luồng import có sẵn.
            var name = Path.GetFileName(picked);
            var target = Path.Combine(InboxPath, name);
            if (System.IO.File.Exists(target))
            {
                name = $"{Path.GetFileNameWithoutExtension(name)}_{DateTime.Now:yyyyMMdd_HHmmss}{extension}";
                target = Path.Combine(InboxPath, name);
            }
            System.IO.File.Copy(picked, target);
            return Ok(new { picked = true, name, size_bytes = length });
        }
        finally
        {
            PickLock.Release();
        }
    }

    /// Liệt kê file trong thư mục inbox trên máy tính chạy API.
    [HttpGet("inbox")]
    public IActionResult ListInbox()
    {
        var folder = InboxPath;
        var files = new DirectoryInfo(folder).EnumerateFiles()
            .Where(f => Allowed.Contains(f.Extension.ToLowerInvariant()))
            .OrderByDescending(f => f.LastWriteTimeUtc)
            .Select(f => new { name = f.Name, size_bytes = f.Length, modified_at = f.LastWriteTimeUtc })
            .ToList();
        return Ok(new { folder, files });
    }

    /// Nhập một file trong inbox thành bài trắc nghiệm (cùng logic với upload thường).
    [HttpPost("inbox/import")]
    public async Task<IActionResult> ImportFromInbox([FromBody] ImportInboxRequest request, CancellationToken cancellationToken)
    {
        // Chỉ nhận tên file thuần, không cho phép đường dẫn để tránh đọc file ngoài thư mục inbox.
        var name = Path.GetFileName(request.FileName ?? string.Empty);
        if (string.IsNullOrWhiteSpace(name) || name != request.FileName)
            return BadRequest(new { message = "Tên file không hợp lệ." });
        var source = Path.Combine(InboxPath, name);
        if (!System.IO.File.Exists(source)) return NotFound(new { message = "Không tìm thấy file trong thư mục inbox." });

        var extension = Path.GetExtension(name).ToLowerInvariant();
        if (!Allowed.Contains(extension)) return BadRequest(new { message = "Chỉ hỗ trợ PDF, DOCX, XLSX, TXT." });
        var length = new FileInfo(source).Length;
        if (length == 0) return BadRequest(new { message = "File rỗng." });
        if (length > MaxBytes) return BadRequest(new { message = "File tối đa 10 MB." });
        if (string.IsNullOrWhiteSpace(request.Title) || string.IsNullOrWhiteSpace(request.Subject))
            return BadRequest(new { message = "Tên bài và môn học là bắt buộc." });

        var path = Path.Combine(UploadRoot, Guid.NewGuid().ToString("N") + extension);
        System.IO.File.Copy(source, path);

        return await CreateQuizFromStoredFileAsync(path, name, length, extension,
            request.Title, request.Subject, request.Description, cancellationToken);
    }

    private async Task<IActionResult> CreateQuizFromStoredFileAsync(
        string path, string originalName, long sizeBytes, string extension,
        string title, string subject, string? description, CancellationToken cancellationToken)
    {
        var userId = UserId;

        QuizDocumentParseResult parsed;
        try
        {
            parsed = await parser.ParseAsync(path, extension, cancellationToken);
        }
        catch (OperationCanceledException) { throw; }
        catch (Exception ex)
        {
            // Keep the upload as a draft even if one parser fails; do not lose the user's file.
            parsed = new QuizDocumentParseResult([], "none", [$"Không phân tích được nội dung tự động: {ex.Message}"]);
        }

        var quiz = new Quiz
        {
            Id = Guid.NewGuid().ToString("N"),
            Title = title.Trim(),
            Subject = subject.Trim(),
            Description = description?.Trim(),
            DurationMinutes = 15,
            IconEmoji = "📄",
            OwnerId = userId,
            Questions = parsed.Questions.Select((q, index) => new Question
            {
                Text = q.Text,
                Order = index,
                CorrectAnswerIndex = q.CorrectAnswerIndex,
                Explanation = q.Explanation,
                Options = q.Options.Select((option, optionIndex) => new QuestionOption
                {
                    Text = option,
                    Order = optionIndex
                }).ToList()
            }).ToList()
        };
        var uploaded = new UploadedFile
        {
            OwnerId = userId,
            OriginalName = originalName,
            StoredPath = path,
            Extension = extension.TrimStart('.'),
            SizeBytes = sizeBytes,
            Quiz = quiz
        };
        db.Quizzes.Add(quiz);
        db.UploadedFiles.Add(uploaded);
        await db.SaveChangesAsync(cancellationToken);

        var questionCount = parsed.Questions.Count;
        return Ok(new
        {
            message = questionCount > 0
                ? $"Đã lưu tài liệu và trích xuất {questionCount} câu hỏi. Hãy rà soát nội dung/đáp án trước khi dùng."
                : "Đã lưu tài liệu thành bản nháp nhưng chưa tìm được câu hỏi có đáp án đáng tin cậy.",
            file_id = uploaded.Id,
            quiz_id = quiz.Id,
            title = quiz.Title,
            subject = quiz.Subject,
            extension,
            size_bytes = sizeBytes,
            questions_count = questionCount,
            parsing_mode = parsed.Mode,
            warnings = parsed.Warnings,
            status = questionCount > 0 ? "ready_for_review" : "draft"
        });
    }

    [HttpGet("mine")]
    public async Task<IActionResult> Mine()
    {
        var userId = UserId;
        var rows = await db.UploadedFiles.Where(x => x.OwnerId == userId)
            .OrderByDescending(x => x.UploadedAt)
            .Select(x => new
            {
                id = x.Id,
                original_name = x.OriginalName,
                extension = x.Extension,
                size_bytes = x.SizeBytes,
                uploaded_at = x.UploadedAt,
                quiz_id = x.QuizId,
                quiz_title = x.Quiz!.Title,
                questions_count = x.Quiz!.Questions.Count
            }).ToListAsync();
        return Ok(rows);
    }
}
