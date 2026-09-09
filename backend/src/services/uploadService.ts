import fs from "fs/promises";
import path from "path";
import { AppError } from "../middleware/errorHandler";

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

const parseMultipartFile = (body: Buffer, contentType: string | undefined, fieldName: string): MultipartFile => {
  const boundary = contentType?.match(/boundary=(?:"([^"]+)"|([^;]+))/)?.[1] ?? contentType?.match(/boundary=(?:"([^"]+)"|([^;]+))/)?.[2];

  if (!boundary) {
    throw new AppError(400, "Zahtjev za slanje slike nije ispravan.");
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

    if (name === fieldName && nextBoundary !== -1) {
      return {
        buffer: body.subarray(dataStart, nextBoundary),
        mimeType,
        originalName
      };
    }

    start = body.indexOf(delimiter, dataStart);
  }

  throw new AppError(400, `Nedostaje slika u polju ${fieldName}.`);
};

const extensionFromContent = (file: MultipartFile): string | undefined => {
  const byMime = allowedMimeTypes.get(file.mimeType.toLowerCase());

  if (byMime) {
    return byMime;
  }

  const lowerName = file.originalName.toLowerCase();
  const byName = lowerName.match(/\.(jpe?g|png|webp)$/)?.[1]?.replace("jpeg", "jpg");

  if (byName) {
    return byName;
  }

  if (file.buffer.subarray(0, 3).equals(Buffer.from([0xff, 0xd8, 0xff]))) {
    return "jpg";
  }

  if (file.buffer.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) {
    return "png";
  }

  if (file.buffer.subarray(0, 4).toString("ascii") === "RIFF" && file.buffer.subarray(8, 12).toString("ascii") === "WEBP") {
    return "webp";
  }

  return undefined;
};

export const saveUploadedImage = async (
  body: Buffer,
  contentType: string | undefined,
  options: { fieldName: string; folder: string; maxSizeMb?: number }
): Promise<string> => {
  const file = parseMultipartFile(body, contentType, options.fieldName);
  const extension = extensionFromContent(file);

  if (!extension) {
    throw new AppError(400, "Dozvoljene su samo slike u formatima JPG, PNG i WebP.");
  }

  const maxSizeMb = options.maxSizeMb ?? 5;

  if (file.buffer.length > maxSizeMb * 1024 * 1024) {
    throw new AppError(400, `Veličina slike mora biti manja od ${maxSizeMb} MB.`);
  }

  const uploadDir = path.resolve(process.cwd(), "uploads", options.folder);
  await fs.mkdir(uploadDir, { recursive: true });

  const safeBaseName = file.originalName.replace(/[^a-z0-9.-]/gi, "-").toLowerCase();
  const filename = `${Date.now()}-${Math.round(Math.random() * 1e9)}-${safeBaseName || `image.${extension}`}`;
  const finalName = filename.endsWith(`.${extension}`) ? filename : `${filename}.${extension}`;
  const finalPath = path.join(uploadDir, finalName);

  await fs.writeFile(finalPath, file.buffer);

  return `/uploads/${options.folder}/${finalName}`;
};

export const saveProfileImage = (body: Buffer, contentType?: string): Promise<string> => {
  return saveUploadedImage(body, contentType, { fieldName: "profileImage", folder: "profile-images" });
};
