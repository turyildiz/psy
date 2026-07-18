import config from "./policy.json" with { type: "json" };

export type UploadPurpose = keyof typeof config.purposes;
export type AllowedImageType = (typeof config.allowedImageTypes)[number];

export const ALLOWED_IMAGE_TYPES = [...config.allowedImageTypes] as AllowedImageType[];
export const IMAGE_ACCEPT = ALLOWED_IMAGE_TYPES.join(",");
export const CLIENT_LONGEST_EDGE = config.clientLongestEdge;
export const CLIENT_IMAGE_QUALITY = config.clientImageQuality;

export function getUploadPolicy(purpose: UploadPurpose) {
  const { folder, maxBytes, maxCount } = config.purposes[purpose];
  return { folder, maxBytes, maxCount };
}

export function isUploadPurpose(value: unknown): value is UploadPurpose {
  return typeof value === "string" && Object.prototype.hasOwnProperty.call(config.purposes, value);
}

export function isAllowedImageType(value: unknown): value is AllowedImageType {
  return typeof value === "string" && ALLOWED_IMAGE_TYPES.includes(value as AllowedImageType);
}

export function getSafeExtension(contentType: string) {
  if (contentType === "image/jpeg") return "jpg";
  if (contentType === "image/png") return "png";
  if (contentType === "image/webp") return "webp";
  return null;
}

export function validateUploadDeclaration(purpose: UploadPurpose, contentType: string, size: number) {
  if (!isAllowedImageType(contentType)) return "Only JPEG, PNG, and WebP images are allowed.";
  if (!Number.isSafeInteger(size) || size <= 0) return "The image file is empty.";

  const policy = config.purposes[purpose];
  if (size > policy.maxBytes) {
    const megabytes = policy.maxBytes / 1024 / 1024;
    return `${policy.label} must be ${megabytes} MB or smaller.`;
  }

  return null;
}

export function getClientResizeDimensions(width: number, height: number) {
  if (!Number.isFinite(width) || !Number.isFinite(height) || width <= 0 || height <= 0) {
    throw new Error("Invalid image dimensions.");
  }
  const scale = Math.min(1, CLIENT_LONGEST_EDGE / Math.max(width, height));
  return {
    width: Math.max(1, Math.round(width * scale)),
    height: Math.max(1, Math.round(height * scale)),
  };
}

export function detectImageContentType(bytes: Uint8Array): AllowedImageType | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
    bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a
  ) return "image/png";
  if (
    bytes.length >= 12 &&
    String.fromCharCode(bytes[0], bytes[1], bytes[2], bytes[3]) === "RIFF" &&
    String.fromCharCode(bytes[8], bytes[9], bytes[10], bytes[11]) === "WEBP"
  ) return "image/webp";
  return null;
}
