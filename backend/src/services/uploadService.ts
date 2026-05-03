import fs from "fs/promises";
import path from "path";
import { AppError } from "../middleware/errorHandler";

const uploadDir = path.resolve(process.cwd(), "uploads", "profile-images");
const allowedMimeTypes = new Map([
  ["image/jpeg", "jpg"],
  ["image/png", "png"],
  ["image/webp", "webp"]
]);

interface MultipartFile {
  buffer: Buffer;
  mimeType: string;
  originalName: string;
}

const parseMultipartFile = (body: Buffer, contentType?: string): MultipartFile => {
  const boundary = contentType?.match(/boundary=(?:"([^"]+)"|([^;]+))/)?.[1] ?? contentType?.match(/boundary=(?:"([^"]+)"|([^;]+))/)?.[2];

  if (!boundary) {
    throw new AppError(400, "Multipart boundary is missing");
  }

  const delimiter = Buffer.from(`--${boundary}`);
  let start = body.indexOf(delimiter);

  while (start !== -1) {
    const headerStart = start + delimiter.length + 2;
    const headerEnd = body.indexOf(Buffer.from("\r\n\r\n"), headerStart);

    if (headerEnd === -1) {
      break;
    }

    const headers = body.subarray(headerStart, headerEnd).toString("utf8");
    const name = headers.match(/name="([^"]+)"/)?.[1];
    const originalName = headers.match(/filename="([^"]*)"/)?.[1] ?? "profile-image";
    const mimeType = headers.match(/Content-Type:\s*([^\r\n]+)/i)?.[1]?.trim() ?? "application/octet-stream";
    const dataStart = headerEnd + 4;
    const nextBoundary = body.indexOf(Buffer.from(`\r\n--${boundary}`), dataStart);

    if (name === "profileImage" && nextBoundary !== -1) {
      return {
        buffer: body.subarray(dataStart, nextBoundary),
        mimeType,
        originalName
      };
    }

    start = body.indexOf(delimiter, dataStart);
  }

  throw new AppError(400, "profileImage file is required");
};

export const saveProfileImage = async (body: Buffer, contentType?: string): Promise<string> => {
  const file = parseMultipartFile(body, contentType);
  const extension = allowedMimeTypes.get(file.mimeType);

  if (!extension) {
    throw new AppError(400, "Only jpg, png and webp images are allowed");
  }

  if (file.buffer.length > 5 * 1024 * 1024) {
    throw new AppError(400, "Image must be smaller than 5MB");
  }

  await fs.mkdir(uploadDir, { recursive: true });

  const safeBaseName = file.originalName.replace(/[^a-z0-9.-]/gi, "-").toLowerCase();
  const filename = `${Date.now()}-${Math.round(Math.random() * 1e9)}-${safeBaseName || `profile.${extension}`}`;
  const finalName = filename.endsWith(`.${extension}`) ? filename : `${filename}.${extension}`;
  const finalPath = path.join(uploadDir, finalName);

  await fs.writeFile(finalPath, file.buffer);

  return `/uploads/profile-images/${finalName}`;
};
