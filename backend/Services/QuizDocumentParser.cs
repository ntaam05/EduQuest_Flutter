using System.IO.Compression;
using System.Text;
using System.Text.RegularExpressions;
using System.Security.Cryptography;
using System.Xml.Linq;
using UglyToad.PdfPig;

namespace EduQuest.Api.Services;

/// <summary>
/// Đọc văn bản từ PDF/DOCX/XLSX/TXT và chuyển nội dung có cấu trúc thành câu hỏi trắc nghiệm.
/// Không đoán đáp án khi tài liệu không có đáp án rõ ràng. Với tài liệu ghi chú, chỉ tạo câu hỏi
/// khi trích xuất được cặp khái niệm - định nghĩa đủ tin cậy.
/// </summary>
public sealed class QuizDocumentParser
{
    private static readonly Regex QuestionHeader = new(
        @"^\s*(?:câu|cau|question|q)\s*\d+\s*[\.:\)\-]?\s*(.*)$",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex OptionLine = new(
        @"^\s*([A-E])\s*[\.)\:]\s*(.+?)\s*$",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);
    private static readonly Regex AnswerLine = new(
        @"^\s*(?:đáp\s*án(?:\s*đúng)?|dap\s*an(?:\s*dung)?|correct\s*answer|answer|đúng\s*là|dung\s*la)\s*[:\-]?\s*([A-E])\b(?:\s*[-\.:]\s*(.*))?$",
        RegexOptions.IgnoreCase | RegexOptions.Compiled);

    public async Task<QuizDocumentParseResult> ParseAsync(string path, string extension, CancellationToken cancellationToken = default)
    {
        var ext = extension.Trim().TrimStart('.').ToLowerInvariant();
        string text;
        List<List<string>>? table = null;
        switch (ext)
        {
            case "txt":
                text = await File.ReadAllTextAsync(path, Encoding.UTF8, cancellationToken);
                break;
            case "pdf":
                text = ExtractPdf(path);
                break;
            case "docx":
                text = ExtractDocx(path);
                break;
            case "xlsx":
                (text, table) = ExtractXlsx(path);
                break;
            default:
                throw new InvalidOperationException("Định dạng tài liệu chưa được hỗ trợ.");
        }

        if (string.IsNullOrWhiteSpace(text))
            return new QuizDocumentParseResult([], "none", ["Không trích xuất được văn bản. Nếu đây là PDF scan/ảnh, cần chuyển sang PDF có lớp văn bản hoặc OCR trước."]);

        if (table is not null)
        {
            var tableQuestions = ParseQuestionTable(table);
            if (tableQuestions.Count > 0)
                return new QuizDocumentParseResult(tableQuestions, "spreadsheet-questions", ["Đã đọc câu hỏi từ các cột trong bảng tính. Hãy rà soát nội dung và đáp án trước khi sử dụng."]);
        }

        var explicitQuestions = ParseExplicitQuestions(text);
        if (explicitQuestions.Count > 0)
            return new QuizDocumentParseResult(explicitQuestions, "formatted-questions", ["Đã nhận diện câu hỏi/đáp án trong tài liệu. Vui lòng kiểm tra bản trích xuất trước khi tổ chức thi."]);

        var definitions = ExtractDefinitions(text);
        var generated = GenerateDefinitionQuestions(definitions);
        if (generated.Count > 0)
            return new QuizDocumentParseResult(generated, "definition-based", ["Câu hỏi được tạo theo mẫu từ các cặp khái niệm–định nghĩa trích nguyên văn; hãy rà soát trước khi sử dụng."]);

        return new QuizDocumentParseResult([], "none", ["Đã lưu tài liệu nhưng chưa nhận diện được cấu trúc câu hỏi/đáp án hoặc cặp khái niệm–định nghĩa đủ tin cậy. Hãy dùng định dạng mẫu trong README hoặc bổ sung nội dung câu hỏi và đáp án rõ ràng."]);
    }

    private static string ExtractPdf(string path)
    {
        using var pdf = PdfDocument.Open(path);
        return string.Join("\n", pdf.GetPages().Select(p => p.Text));
    }

    private static string ExtractDocx(string path)
    {
        using var archive = ZipFile.OpenRead(path);
        var entry = archive.GetEntry("word/document.xml") ?? throw new InvalidDataException("DOCX không chứa word/document.xml.");
        using var stream = entry.Open();
        var xml = XDocument.Load(stream);
        return string.Join("\n", xml.Descendants().Where(x => x.Name.LocalName == "p")
            .Select(p => string.Concat(p.Descendants().Where(x => x.Name.LocalName == "t").Select(t => t.Value)).Trim())
            .Where(p => p.Length > 0));
    }

    private static (string Text, List<List<string>> Rows) ExtractXlsx(string path)
    {
        using var archive = ZipFile.OpenRead(path);
        var worksheet = GetFirstWorksheetEntry(archive);
        var shared = new List<string>();
        var sharedEntry = archive.GetEntry("xl/sharedStrings.xml");
        if (sharedEntry is not null)
        {
            using var sharedStream = sharedEntry.Open();
            var sharedXml = XDocument.Load(sharedStream);
            shared = sharedXml.Descendants().Where(x => x.Name.LocalName == "si")
                .Select(si => string.Concat(si.Descendants().Where(x => x.Name.LocalName == "t").Select(t => t.Value))).ToList();
        }

        using var sheetStream = worksheet.Open();
        var sheetXml = XDocument.Load(sheetStream);
        var rows = new List<List<string>>();
        foreach (var row in sheetXml.Descendants().Where(x => x.Name.LocalName == "row"))
        {
            var values = new List<string>();
            var cells = row.Elements().Where(x => x.Name.LocalName == "c").ToList();
            foreach (var cell in cells)
            {
                var refValue = (string?)cell.Attribute("r") ?? "";
                var colIndex = ColumnIndex(refValue);
                while (values.Count <= colIndex) values.Add("");
                var type = (string?)cell.Attribute("t");
                string value;
                if (type == "inlineStr")
                    value = string.Concat(cell.Descendants().Where(x => x.Name.LocalName == "t").Select(t => t.Value));
                else
                {
                    var raw = cell.Elements().FirstOrDefault(x => x.Name.LocalName == "v")?.Value ?? "";
                    value = type == "s" && int.TryParse(raw, out var sharedIndex) && sharedIndex >= 0 && sharedIndex < shared.Count ? shared[sharedIndex] : raw;
                }
                values[colIndex] = value.Trim();
            }
            rows.Add(values);
        }
        var text = string.Join("\n", rows.Select(r => string.Join(" | ", r)));
        return (text, rows);
    }

    private static ZipArchiveEntry GetFirstWorksheetEntry(ZipArchive archive)
    {
        var workbookEntry = archive.GetEntry("xl/workbook.xml");
        var relationshipsEntry = archive.GetEntry("xl/_rels/workbook.xml.rels");
        if (workbookEntry is not null && relationshipsEntry is not null)
        {
            using var workbookStream = workbookEntry.Open();
            using var relationshipsStream = relationshipsEntry.Open();
            var workbook = XDocument.Load(workbookStream);
            var relationships = XDocument.Load(relationshipsStream);
            var firstSheet = workbook.Descendants().FirstOrDefault(x => x.Name.LocalName == "sheet");
            var relationshipId = firstSheet?.Attributes().FirstOrDefault(a => a.Name.LocalName == "id")?.Value;
            if (!string.IsNullOrWhiteSpace(relationshipId))
            {
                var target = relationships.Descendants().FirstOrDefault(x =>
                    x.Name.LocalName == "Relationship" && (string?)x.Attribute("Id") == relationshipId)?.Attribute("Target")?.Value;
                if (!string.IsNullOrWhiteSpace(target))
                {
                    var normalized = target.Replace('\\', '/').TrimStart('/');
                    var entryPath = normalized.StartsWith("xl/", StringComparison.OrdinalIgnoreCase)
                        ? normalized
                        : "xl/" + normalized;
                    var entry = archive.GetEntry(entryPath);
                    if (entry is not null) return entry;
                }
            }
        }
        return archive.GetEntry("xl/worksheets/sheet1.xml")
            ?? throw new InvalidDataException("XLSX không có sheet đầu tiên có thể đọc.");
    }

    private static int ColumnIndex(string cellRef)
    {
        var letters = new string(cellRef.TakeWhile(char.IsLetter).ToArray()).ToUpperInvariant();
        var index = 0;
        foreach (var c in letters) index = index * 26 + (c - 'A' + 1);
        return Math.Max(0, index - 1);
    }

    private static List<ParsedQuestion> ParseQuestionTable(List<List<string>> rows)
    {
        if (rows.Count < 2) return [];
        var header = rows[0].Select(NormalizeHeader).ToList();
        int Find(params string[] names) => header.FindIndex(h => names.Any(n => h == n || h.Contains(n, StringComparison.Ordinal)));
        var questionCol = Find("cau hoi", "question", "noi dung cau hoi", "question text");
        int FindOption(string letter) => header.FindIndex(h =>
            h == letter || h == $"dap an {letter}" || h == $"option {letter}" || h == $"phuong an {letter}" || h == $"phuong an {letter.ToUpperInvariant()}");
        var optionCols = new[] { FindOption("a"), FindOption("b"), FindOption("c"), FindOption("d"), FindOption("e") };
        // Resolve full answer-column names before any broad matching. In particular,
        // "Đáp án A" is an option column and must never be mistaken for the answer key.
        var answerHeaders = new HashSet<string>(StringComparer.Ordinal)
        { "dap an dung", "dap an chinh xac", "correct answer", "correct option", "answer key", "dap an", "answer" };
        var answerCol = header.FindIndex(h => answerHeaders.Contains(h));
        if (answerCol < 0)
            answerCol = header.FindIndex(h => h.StartsWith("dap an dung", StringComparison.Ordinal) ||
                h.StartsWith("dap an chinh xac", StringComparison.Ordinal) ||
                h.StartsWith("correct answer ", StringComparison.Ordinal) || h.StartsWith("answer key ", StringComparison.Ordinal));
        var explanationCol = Find("giai thich", "explanation", "ly do");
        if (questionCol < 0 || answerCol < 0 || optionCols.Count(i => i >= 0) < 2) return [];

        var result = new List<ParsedQuestion>();
        foreach (var row in rows.Skip(1))
        {
            string Cell(int i) => i >= 0 && i < row.Count ? row[i].Trim() : "";
            var question = Cell(questionCol);
            var answerToken = Cell(answerCol).Trim().ToUpperInvariant();
            var answerIndex = answerToken.Length > 0 && answerToken[0] is >= 'A' and <= 'E' ? answerToken[0] - 'A' : -1;
            var options = optionCols.Select(Cell).ToList();
            // Preserve the A-E indices by rejecting missing intermediate options.
            while (options.Count > 0 && string.IsNullOrWhiteSpace(options[^1])) options.RemoveAt(options.Count - 1);
            if (string.IsNullOrWhiteSpace(question) || options.Count < 2 || options.Any(string.IsNullOrWhiteSpace) || answerIndex < 0 || answerIndex >= options.Count) continue;
            result.Add(new ParsedQuestion(question, options, answerIndex, Cell(explanationCol)));
        }
        return result;
    }

    private static List<ParsedQuestion> ParseExplicitQuestions(string text)
    {
        var result = new List<ParsedQuestion>();
        string? currentQuestion = null;
        var options = new SortedDictionary<int, string>();
        int? answerIndex = null;
        string? explanation = null;
        var inExplanation = false;

        void Flush()
        {
            if (!string.IsNullOrWhiteSpace(currentQuestion) && answerIndex.HasValue && options.Count >= 2)
            {
                var lastIndex = options.Keys.Max();
                // A-E options must be contiguous so the answer index maps to the rendered order.
                if (options.Keys.SequenceEqual(Enumerable.Range(0, lastIndex + 1)))
                {
                    var values = options.Values.ToList();
                    if (answerIndex.Value < values.Count && values.All(v => !string.IsNullOrWhiteSpace(v)))
                        result.Add(new ParsedQuestion(currentQuestion.Trim(), values, answerIndex.Value, explanation?.Trim() ?? ""));
                }
            }
            currentQuestion = null;
            options = new SortedDictionary<int, string>();
            answerIndex = null;
            explanation = null;
            inExplanation = false;
        }

        foreach (var rawLine in text.Replace("\r", "").Split('\n'))
        {
            var line = rawLine.Trim();
            if (line.Length == 0) continue;
            var questionMatch = QuestionHeader.Match(line);
            if (questionMatch.Success)
            {
                Flush();
                currentQuestion = questionMatch.Groups[1].Value.Trim();
                continue;
            }

            var answerMatch = AnswerLine.Match(line);
            if (answerMatch.Success && currentQuestion is not null)
            {
                answerIndex = char.ToUpperInvariant(answerMatch.Groups[1].Value[0]) - 'A';
                if (answerMatch.Groups[2].Success) explanation = answerMatch.Groups[2].Value.Trim();
                inExplanation = false;
                continue;
            }

            if (currentQuestion is null) continue;
            var optionMatch = OptionLine.Match(line);
            if (optionMatch.Success)
            {
                options[char.ToUpperInvariant(optionMatch.Groups[1].Value[0]) - 'A'] = optionMatch.Groups[2].Value.Trim();
                inExplanation = false;
                continue;
            }
            if (Regex.IsMatch(line, @"^(giải thích|giai thich|explanation)\s*[:\-]", RegexOptions.IgnoreCase))
            {
                explanation = Regex.Replace(line, @"^(giải thích|giai thich|explanation)\s*[:\-]\s*", "", RegexOptions.IgnoreCase);
                inExplanation = true;
                continue;
            }
            if (inExplanation && explanation is not null) explanation += " " + line;
            else if (options.Count == 0) currentQuestion += " " + line;
            else
            {
                var last = options.Keys.Max();
                options[last] += " " + line;
            }
        }
        Flush();
        return result;
    }

    private static List<(string Term, string Definition)> ExtractDefinitions(string text)
    {
        var result = new List<(string Term, string Definition)>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        foreach (var raw in text.Replace("\r", "").Split('\n'))
        {
            var line = Regex.Replace(raw.Trim(), @"^[\-•*\d\.\)\s]+", "").Trim();
            if (line.Length < 18 || line.Length > 700) continue;
            // Definition lines: 
            var match = Regex.Match(line,
                @"^(.{2,90}?)\s+(?:được định nghĩa là|được hiểu là|có nghĩa là|is defined as|refers to|consists of|means|bao gồm|là)\s+(.{8,500})$",
                RegexOptions.IgnoreCase);
            if (!match.Success)
                match = Regex.Match(line, @"^(.{2,90}?)\s*[:–—]\s*(.{10,500})$", RegexOptions.IgnoreCase);
            if (!match.Success) continue;
            var term = match.Groups[1].Value.Trim(' ', ':', '-', '–', '—', '.');
            var definition = match.Groups[2].Value.Trim().TrimEnd('.', ';');
            if (term.Length < 2 || term.Length > 90 || definition.Length < 10 || definition.Length > 500) continue;
            if (Regex.IsMatch(term, @"^(câu|question|ví dụ|example|ghi chú|note|mục|section)\b", RegexOptions.IgnoreCase)) continue;
            if (seen.Add(term)) result.Add((term, definition));
        }
        return result;
    }

    private static List<ParsedQuestion> GenerateDefinitionQuestions(List<(string Term, string Definition)> definitions)
    {
        if (definitions.Count < 2) return [];
        var results = new List<ParsedQuestion>();
        for (var i = 0; i < definitions.Count && results.Count < 40; i++)
        {
            var current = definitions[i];
            var optionsWithCorrect = new List<(string Text, bool Correct)> { (current.Definition, true) };
            foreach (var other in definitions.Where((_, index) => index != i))
            {
                if (optionsWithCorrect.Count >= 4) break;
                if (!optionsWithCorrect.Any(x => string.Equals(x.Text, other.Definition, StringComparison.OrdinalIgnoreCase)))
                    optionsWithCorrect.Add((other.Definition, false));
            }
            if (optionsWithCorrect.Count < 2) continue;
            // Stable ordering helps users inspect the same parsed quiz consistently across restarts.
            optionsWithCorrect = optionsWithCorrect
                .OrderBy(x => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(current.Term + "|" + x.Text))), StringComparer.Ordinal)
                .ToList();
            var correctIndex = optionsWithCorrect.FindIndex(x => x.Correct);
            results.Add(new ParsedQuestion($"Theo tài liệu, “{current.Term}” được hiểu là gì?",
                optionsWithCorrect.Select(x => x.Text).ToList(), correctIndex,
                "Câu hỏi được tạo từ định nghĩa trích xuất; nên kiểm tra trước khi sử dụng."));
        }
        return results;
    }

    private static string NormalizeHeader(string value)
    {
        var normalized = value.Trim().ToLowerInvariant().Normalize(NormalizationForm.FormD);
        var chars = normalized.Where(c => System.Globalization.CharUnicodeInfo.GetUnicodeCategory(c) != System.Globalization.UnicodeCategory.NonSpacingMark).ToArray();
        return new string(chars).Replace('đ', 'd').Replace("_", " ").Trim();
    }
}

public sealed record ParsedQuestion(string Text, List<string> Options, int CorrectAnswerIndex, string? Explanation);
public sealed record QuizDocumentParseResult(List<ParsedQuestion> Questions, string Mode, List<string> Warnings);
