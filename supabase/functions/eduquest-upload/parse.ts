import { DOMParser } from "npm:@xmldom/xmldom@0.9.12";
import { unzipSync } from "npm:fflate@0.8.3";
import { getDocumentProxy } from "npm:unpdf@2.1.0";

export type Extension = "txt" | "pdf" | "docx" | "xlsx";
type Question = {
  text: string;
  options: { text: string }[];
  correct_answer_index: number;
  explanation?: string;
};
type ParseResult = { questions: Question[]; mode: string; warnings: string[] };

const MAX_TEXT = 600_000;
const MAX_QUESTIONS = 300;
const decoder = new TextDecoder();
const optionLetters = ["a", "b", "c", "d", "e"];
const questionHeader = /^(?:câu|cau|question|q)\s*\d+\s*[.:)\-]?\s*(.*)$/i;
const optionLine = /^([A-E])\s*[.):]\s*(.+)$/i;
const answerLine =
  /^(?:đáp\s*án(?:\s*đúng)?|dap\s*an(?:\s*dung)?|correct\s*answer|answer|đúng\s*là)\s*[:\-]?\s*([A-E])\b(?:\s*[-.:]\s*(.*))?$/i;
const explanationLine =
  /^(?:giải thích|giai thich|explanation)\s*[:\-]\s*(.*)$/i;

function makeQuestion(
  text: string,
  options: string[],
  correct: number,
  explanation?: string,
): Question | null {
  const title = text.trim();
  const trimmed = options.map((option) => option.trim());
  if (
    !title || title.length > 3000 || trimmed.length < 2 ||
    trimmed.some((option) => !option || option.length > 1000) ||
    !Number.isInteger(correct) || correct < 0 || correct >= trimmed.length
  ) return null;
  return {
    text: title,
    options: trimmed.map((text) => ({ text })),
    correct_answer_index: correct,
    explanation: explanation?.trim().slice(0, 3000),
  };
}

function explicitQuestions(text: string): Question[] {
  const questions: Question[] = [];
  let question: string | null = null;
  let options: string[] = [];
  let index = -1;
  let explanation = "";
  let section = "question";
  let activeOption = -1;

  function finish() {
    if (question !== null) {
      const row = makeQuestion(
        question,
        Array.from(options, (o) => o ?? ""),
        index,
        explanation,
      );
      if (row) questions.push(row);
    }
    options = [];
    index = -1;
    explanation = "";
    section = "question";
    activeOption = -1;
  }

  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const header = questionHeader.exec(line);
    if (header) {
      finish();
      if (questions.length >= MAX_QUESTIONS) return questions;
      question = header[1];
      continue;
    }
    if (question === null) continue;
    const answer = answerLine.exec(line);
    const option = optionLine.exec(line);
    const note = explanationLine.exec(line);
    if (answer) {
      index = optionLetters.indexOf(answer[1].toLowerCase());
      explanation = answer[2] ?? explanation;
      section = "explanation";
    } else if (option) {
      activeOption = optionLetters.indexOf(option[1].toLowerCase());
      options[activeOption] = option[2];
      section = "option";
    } else if (note) {
      explanation = note[1];
      section = "explanation";
    } else if (section === "question") {
      question += " " + line;
    } else if (section === "option") {
      options[activeOption] += " " + line;
    } else {
      explanation += " " + line;
    }
  }
  finish();
  return questions;
}

function definitionQuestions(text: string): Question[] {
  const definitions = new Map<string, string>();
  for (const line of text.split(/\r?\n/)) {
    const entry = line.trim().replace(/^[\s\d.\-•*)]+/, "");
    if (entry.length > 700) continue;
    const pair =
      /^(.{2,90}?)\s+(?:được định nghĩa là|được hiểu là|có nghĩa là|is defined as|refers to|consists of|means|bao gồm|là)\s+(.{10,500})$/i
        .exec(entry) ??
        /^(.{2,90}?)\s*[:–—]\s*(.{10,500})$/.exec(entry);
    if (!pair) continue;
    const term = pair[1].trim();
    if (
      /^(?:câu|question|ví dụ|example|ghi chú|note|mục|section|đáp án|giải thích)(?:\s|$)/i
        .test(term)
    ) continue;
    if (!definitions.has(term)) {
      definitions.set(term, pair[2].trim().replace(/[.;]+$/, ""));
    }
    if (definitions.size >= 60) break;
  }
  const result: Question[] = [];
  for (const [term, correct] of definitions) {
    const distractors = [...new Set(definitions.values())].filter((item) =>
      item !== correct
    ).slice(0, 3);
    if (distractors.length === 0) continue;
    const index = result.length % (distractors.length + 1);
    distractors.splice(index, 0, correct);
    const question = makeQuestion(
      `Theo tài liệu, “${term}” được hiểu là gì?`,
      distractors,
      index,
      "Câu hỏi được tạo từ định nghĩa trích xuất. Hãy kiểm tra trước khi sử dụng.",
    );
    if (question) result.push(question);
    if (result.length === 40) break;
  }
  return result;
}

function readOfficeParts(bytes: Uint8Array, names: string[]) {
  let total = 0;
  return unzipSync(bytes, {
    filter: (file) => {
      if (!names.includes(file.name)) return false;
      total += file.originalSize;
      if (total > 6_000_000) {
        throw new Error("Văn bản Office vượt giới hạn phân tích.");
      }
      return true;
    },
  });
}

function readXml(bytes: Uint8Array) {
  const source = decoder.decode(bytes);
  if (/<!DOCTYPE|<!ENTITY/i.test(source)) {
    throw new Error("XML chứa khai báo thực thể.");
  }
  return new DOMParser().parseFromString(source, "text/xml");
}

function docxText(bytes: Uint8Array): string {
  const parts = readOfficeParts(bytes, ["word/document.xml"]);
  const main = parts["word/document.xml"];
  if (!main) throw new Error("Thiếu nội dung DOCX.");
  const doc = readXml(main);
  return Array.from(
    doc.getElementsByTagNameNS("*", "p"),
    (p) =>
      Array.from(p.getElementsByTagNameNS("*", "t"), (t) => t.textContent ?? "")
        .join(""),
  ).join("\n");
}

function xlsxRows(bytes: Uint8Array): string[][] {
  const index = readOfficeParts(bytes, [
    "xl/workbook.xml",
    "xl/_rels/workbook.xml.rels",
  ]);
  let sheet = "xl/worksheets/sheet1.xml";
  if (index["xl/workbook.xml"] && index["xl/_rels/workbook.xml.rels"]) {
    const workbook = readXml(index["xl/workbook.xml"]);
    const relationships = readXml(index["xl/_rels/workbook.xml.rels"]);
    const first = workbook.getElementsByTagNameNS("*", "sheet").item(0);
    const id = first &&
      Array.from(first.attributes).find((item) => item.localName === "id")
        ?.value;
    const target = Array.from(
      relationships.getElementsByTagNameNS("*", "Relationship"),
    )
      .find((item) => item.getAttribute("Id") === id)?.getAttribute("Target");
    if (target) {
      const normalized = target.replaceAll("\\", "/").replace(/^\//, "");
      sheet = normalized.startsWith("xl/") ? normalized : "xl/" + normalized;
    }
  }
  const parts = readOfficeParts(bytes, [sheet, "xl/sharedStrings.xml"]);
  if (!parts[sheet]) throw new Error("Thiếu sheet đầu tiên của XLSX.");
  const shared = parts["xl/sharedStrings.xml"]
    ? Array.from(
      readXml(parts["xl/sharedStrings.xml"]).getElementsByTagNameNS("*", "si"),
      (item) =>
        Array.from(
          item.getElementsByTagNameNS("*", "t"),
          (t) => t.textContent ?? "",
        ).join(""),
    )
    : [];
  return Array.from(readXml(parts[sheet]).getElementsByTagNameNS("*", "row"))
    .slice(0, 1000).map((row) => {
      const cells: string[] = [];
      for (const cell of Array.from(row.getElementsByTagNameNS("*", "c"))) {
        const letters = /^[A-Z]{1,3}/i.exec(cell.getAttribute("r") ?? "")?.[0]
          .toUpperCase();
        let column = 0;
        for (const letter of letters ?? "") {
          column = column * 26 + letter.charCodeAt(0) - 64;
        }
        if (column < 1 || column > 128) continue;
        const raw =
          cell.getElementsByTagNameNS("*", "v").item(0)?.textContent ?? "";
        const type = cell.getAttribute("t");
        cells[column - 1] = type === "s"
          ? shared[Number(raw)] ?? ""
          : type === "inlineStr"
          ? Array.from(cell.getElementsByTagNameNS("*", "t"), (t) =>
            t.textContent ?? "").join("")
          : raw;
      }
      return cells;
    });
}

function normalized(value: string): string {
  return value.toLowerCase().normalize("NFD").replace(/\p{M}/gu, "").replaceAll(
    "đ",
    "d",
  ).trim();
}

function tableQuestions(rows: string[][]): Question[] {
  const headerAt = rows.findIndex((row) =>
    row.some((value) => !!value?.trim())
  );
  if (headerAt < 0) return [];
  const headers = rows[headerAt].map(normalized);
  const questionCol = headers.findIndex((x) =>
    /cau hoi|question/.test(x ?? "")
  );
  const answerCol = headers.findIndex((x) =>
    /^(?:dap an(?: dung| chinh xac)?|correct answer|correct option|answer key|answer)$/
      .test(x ?? "")
  );
  const explanationCol = headers.findIndex((x) =>
    /giai thich|explanation|ly do/.test(x ?? "")
  );
  const optionCols = optionLetters.map((letter) =>
    headers.findIndex((x) =>
      [letter, `dap an ${letter}`, `option ${letter}`, `phuong an ${letter}`]
        .includes(x)
    )
  );
  if (
    questionCol < 0 || answerCol < 0 ||
    optionCols.filter((i) => i >= 0).length < 2
  ) return [];
  const result: Question[] = [];
  for (const row of rows.slice(headerAt + 1)) {
    const options = optionCols.map((i) => row[i]?.trim() ?? "");
    while (options.length && !options.at(-1)) options.pop();
    const letter =
      /^([a-e])\b/i.exec(row[answerCol]?.trim() ?? "")?.[1].toLowerCase() ?? "";
    const question = makeQuestion(
      row[questionCol] ?? "",
      options,
      optionLetters.indexOf(letter),
      row[explanationCol],
    );
    if (question) result.push(question);
    if (result.length === MAX_QUESTIONS) break;
  }
  return result;
}

async function pdfText(bytes: Uint8Array): Promise<string> {
  const document = await getDocumentProxy(bytes);
  let text = "";
  try {
    if (document.numPages > 50) throw new Error("PDF vượt giới hạn 50 trang.");
    for (let index = 1; index <= document.numPages; index++) {
      const page = await document.getPage(index);
      const content = await page.getTextContent();
      let previousY: number | undefined;
      for (const item of content.items) {
        if (!("str" in item)) continue;
        const y = item.transform[5];
        if (
          previousY !== undefined && Math.abs(y - previousY) > 3 &&
          !text.endsWith("\n")
        ) text += "\n";
        text += item.str + (item.hasEOL ? "\n" : " ");
        previousY = y;
        if (text.length > MAX_TEXT) {
          throw new Error("Văn bản PDF vượt giới hạn phân tích.");
        }
      }
      text += "\n";
      page.cleanup();
    }
  } finally {
    await document.loadingTask.destroy();
  }
  return text;
}

export async function parseDocument(
  bytes: Uint8Array,
  extension: Extension,
): Promise<ParseResult> {
  let text: string;
  try {
    switch (extension) {
      case "txt":
        text = decoder.decode(bytes);
        break;
      case "docx":
        text = docxText(bytes);
        break;
      case "xlsx": {
        const rows = xlsxRows(bytes);
        const questions = tableQuestions(rows);
        if (questions.length) {
          return {
            questions,
            mode: "spreadsheet-questions",
            warnings: ["Hãy kiểm tra câu hỏi và đáp án đọc từ bảng tính."],
          };
        }
        text = rows.map((row) => row.join(" | ")).join("\n");
        break;
      }
      case "pdf":
        text = await pdfText(bytes);
        break;
    }
    if (text.length > MAX_TEXT) {
      throw new Error("Văn bản vượt giới hạn phân tích.");
    }
  } catch {
    return {
      questions: [],
      mode: "none",
      warnings: [
        "Đã lưu bản nháp. Tệp không đọc được hoặc vượt giới hạn phân tích. Thử chia nhỏ tệp hoặc dùng mẫu TXT.",
      ],
    };
  }
  const questions = explicitQuestions(text);
  if (questions.length) {
    return {
      questions,
      mode: "formatted-questions",
      warnings: ["Hãy kiểm tra câu hỏi và đáp án trước khi sử dụng."],
    };
  }
  const definitions = definitionQuestions(text);
  if (definitions.length) {
    return {
      questions: definitions,
      mode: "definition-based",
      warnings: [
        "Câu hỏi được tạo từ định nghĩa. Hãy kiểm tra đáp án trước khi sử dụng.",
      ],
    };
  }
  return {
    questions: [],
    mode: "none",
    warnings: [
      "Chưa tìm được câu hỏi có đáp án rõ ràng. Dùng mẫu TXT, hoặc OCR trước nếu PDF là bản scan.",
    ],
  };
}
