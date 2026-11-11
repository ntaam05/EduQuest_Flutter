import { type Extension, parseDocument } from "./parse.ts";

const BUCKET = "eduquest-documents";
const MAX_BYTES = 10 * 1024 * 1024;
const MAX_MULTIPART = MAX_BYTES + 64 * 1024;
const UUID = /^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$/i;
const extensions = new Set(["txt", "pdf", "docx", "xlsx"]);
const cors = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers":
    "authorization, apikey, x-client-info, content-type",
  "access-control-allow-methods": "POST, DELETE, OPTIONS",
};

type Fetch = typeof fetch;
type Config = { url: string; publicKey: string; serverKey: string };

class HttpError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

function reply(status: number, body: unknown): Response {
  return Response.json(body, {
    status,
    headers: { ...cors, "cache-control": "no-store" },
  });
}

function defaultKey(variable: string, fallback: string): string {
  const values = Deno.env.get(variable);
  return (values && JSON.parse(values).default) || Deno.env.get(fallback) || "";
}

export function configFromEnv(): Config {
  return {
    url: (Deno.env.get("SUPABASE_URL") ?? "").replace(/\/$/, ""),
    publicKey: defaultKey("SUPABASE_PUBLISHABLE_KEYS", "SUPABASE_ANON_KEY"),
    serverKey: defaultKey("SUPABASE_SECRET_KEYS", "SUPABASE_SERVICE_ROLE_KEY"),
  };
}

async function boundedForm(request: Request): Promise<FormData> {
  if (
    !(request.headers.get("content-type") ?? "").startsWith(
      "multipart/form-data",
    )
  ) {
    throw new HttpError(400, "Vui lòng chọn tệp tài liệu.");
  }
  const declared = Number(request.headers.get("content-length"));
  if (declared > MAX_MULTIPART) throw new HttpError(413, "Tệp tối đa 10 MB.");
  const reader = request.body?.getReader();
  if (!reader) throw new HttpError(400, "Tệp tải lên rỗng.");
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_MULTIPART) {
        await reader.cancel();
        throw new HttpError(413, "Tệp tối đa 10 MB.");
      }
      chunks.push(value);
    }
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  try {
    return await new Response(bytes, {
      headers: { "content-type": request.headers.get("content-type")! },
    }).formData();
  } catch {
    throw new HttpError(400, "Dữ liệu tệp tải lên không hợp lệ.");
  }
}

export function makeHandler(config: Config, send: Fetch = fetch) {
  const admin = new Headers({ apikey: config.serverKey });
  if (!config.serverKey.startsWith("sb_secret_")) {
    admin.set("authorization", "Bearer " + config.serverKey);
  }
  const request = (path: string, init: RequestInit) =>
    send(config.url + path, { ...init, redirect: "error" });

  async function adminJson(path: string, method: string, data: unknown) {
    const headers = new Headers(admin);
    headers.set("content-type", "application/json");
    const response = await request(path, {
      method,
      headers,
      body: JSON.stringify(data),
    });
    if (!response.ok) {
      const error = await response.json().catch(() => null);
      if (
        typeof error?.code === "string" && /^PT4\d\d$/.test(error.code) &&
        typeof error.message === "string"
      ) {
        throw new HttpError(Number(error.code.slice(2)), error.message);
      }
      if (response.status === 400) {
        throw new HttpError(400, "Dữ liệu bài thi không hợp lệ.");
      }
      console.error(
        "EduQuest Supabase operation failed",
        response.status,
        error?.code,
      );
      throw new HttpError(
        502,
        "Supabase chưa lưu được thay đổi. Vui lòng thử lại.",
      );
    }
    return await response.json();
  }

  async function removeObject(path: string) {
    try {
      await adminJson("/storage/v1/object/" + BUCKET, "DELETE", {
        prefixes: [path],
      });
      return true;
    } catch {
      console.error("EduQuest could not remove a private object", path);
      return false;
    }
  }

  return async (incoming: Request): Promise<Response> => {
    if (incoming.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: cors });
    }
    if (incoming.method !== "POST" && incoming.method !== "DELETE") {
      return reply(405, { message: "Phương thức không được hỗ trợ." });
    }
    try {
      if (!config.url || !config.publicKey || !config.serverKey) {
        throw new HttpError(503, "Supabase chưa được cấu hình.");
      }
      const token = incoming.headers.get("authorization");
      if (!token?.startsWith("Bearer ")) {
        throw new HttpError(401, "Bạn chưa đăng nhập.");
      }
      const auth = await request("/auth/v1/user", {
        headers: { authorization: token, apikey: config.publicKey },
      });
      if (!auth.ok) {
        if (auth.status === 401 || auth.status === 403) {
          throw new HttpError(401, "Phiên đăng nhập không hợp lệ.");
        }
        throw new HttpError(502, "Chưa kiểm tra được phiên đăng nhập.");
      }
      const { id } = await auth.json();
      if (typeof id !== "string" || !UUID.test(id)) {
        throw new HttpError(401, "Phiên đăng nhập không hợp lệ.");
      }

      if (incoming.method === "DELETE") {
        const quizId = new URL(incoming.url).searchParams.get("quiz_id") ?? "";
        if (!UUID.test(quizId)) {
          throw new HttpError(400, "Mã bài thi không hợp lệ.");
        }
        const result = await adminJson(
          "/rest/v1/rpc/eduquest_delete_quiz",
          "POST",
          { p_user_id: id, p_quiz_id: quizId },
        );
        const path = result.object_path;
        if (typeof path === "string" && path.startsWith(id + "/")) {
          await removeObject(path);
        }
        return reply(200, { deleted: true });
      }

      const form = await boundedForm(incoming);
      const file = form.get("file");
      if (!(file instanceof File) || file.size < 1) {
        throw new HttpError(400, "Vui lòng chọn tệp có nội dung.");
      }
      if (file.size > MAX_BYTES) throw new HttpError(413, "Tệp tối đa 10 MB.");
      const name = file.name.split(/[\\/]/).at(-1)?.trim() ?? "";
      const extension = name.split(".").at(-1)?.toLowerCase() ?? "";
      if (
        !name.includes(".") || !extensions.has(extension) || name.length > 255
      ) {
        throw new HttpError(
          400,
          "Chỉ hỗ trợ PDF, DOCX, XLSX, TXT với tên tệp tối đa 255 ký tự.",
        );
      }
      const field = (key: string) => {
        const value = form.get(key);
        return typeof value === "string" ? value.trim() : "";
      };
      const title = field("title");
      const subject = field("subject");
      const description = field("description");
      if (
        !title || title.length > 200 || !subject || subject.length > 100 ||
        description.length > 2000
      ) {
        throw new HttpError(400, "Tên bài, môn học hoặc mô tả chưa hợp lệ.");
      }
      const parsed = await parseDocument(
        new Uint8Array(await file.arrayBuffer()),
        extension as Extension,
      );
      const path = id + "/" + crypto.randomUUID() + "." + extension;
      const headers = new Headers(admin);
      headers.set("content-type", "application/octet-stream");
      const stored = await request(
        "/storage/v1/object/" + BUCKET + "/" + path,
        {
          method: "POST",
          headers,
          body: file,
        },
      );
      if (!stored.ok) {
        throw new HttpError(502, "Không lưu được tệp vào Supabase Storage.");
      }
      await stored.body?.cancel();

      let result;
      try {
        result = await adminJson("/rest/v1/rpc/eduquest_store_upload", "POST", {
          p_user_id: id,
          p_upload: {
            title,
            subject,
            description,
            original_name: name,
            object_path: path,
            extension,
            size_bytes: file.size,
            questions: parsed.questions,
          },
        });
      } catch (error) {
        // A clear rejection means the database did not commit. Keep the object on ambiguous network failures.
        if (error instanceof HttpError && error.status < 500) {
          await removeObject(path);
        }
        throw error;
      }
      return reply(200, {
        ...result,
        parsing_mode: parsed.mode,
        warnings: parsed.warnings,
        message: parsed.questions.length
          ? `Đã lưu tài liệu và trích xuất ${parsed.questions.length} câu hỏi.`
          : "Đã lưu tài liệu thành bản nháp.",
      });
    } catch (error) {
      if (error instanceof HttpError) {
        return reply(error.status, { message: error.message });
      }
      console.error(
        "EduQuest upload request failed",
        error instanceof Error ? error.name : "unknown",
      );
      return reply(502, {
        message: "Chưa hoàn tất yêu cầu tài liệu. Vui lòng thử lại.",
      });
    }
  };
}
