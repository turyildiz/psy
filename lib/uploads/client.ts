"use client";

import {
  CLIENT_IMAGE_QUALITY,
  getClientResizeDimensions,
  isAllowedImageType,
  validateUploadDeclaration,
  type UploadPurpose,
} from "./policy";

type UploadOptions = {
  purpose: UploadPurpose;
  ownerId: string;
  resourceId?: string;
  index?: number;
};

type PresignResponse = {
  uploadUrl: string;
  uploadToken: string;
  headers: Record<string, string>;
};

type FinalizeResponse = {
  publicUrl: string;
};

async function responseError(response: Response, fallback: string) {
  try {
    const body = await response.json() as { error?: string };
    return body.error || fallback;
  } catch {
    return fallback;
  }
}

function canvasBlob(canvas: HTMLCanvasElement, type: "image/webp" | "image/jpeg") {
  return new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, type, CLIENT_IMAGE_QUALITY));
}

async function decodeImage(file: File) {
  if (typeof createImageBitmap === "function") {
    const bitmap = await createImageBitmap(file);
    return {
      source: bitmap as CanvasImageSource,
      width: bitmap.width,
      height: bitmap.height,
      cleanup: () => bitmap.close(),
    };
  }

  const objectUrl = URL.createObjectURL(file);
  const image = new Image();
  image.decoding = "async";
  image.src = objectUrl;
  try {
    await image.decode();
  } catch (error) {
    URL.revokeObjectURL(objectUrl);
    throw error;
  }
  return {
    source: image as CanvasImageSource,
    width: image.naturalWidth,
    height: image.naturalHeight,
    cleanup: () => URL.revokeObjectURL(objectUrl),
  };
}

export async function prepareImageForUpload(file: File, purpose: UploadPurpose) {
  if (!isAllowedImageType(file.type)) throw new Error("Only JPEG, PNG, and WebP images are allowed.");

  const decoded = await decodeImage(file);
  try {
    const { width, height } = getClientResizeDimensions(decoded.width, decoded.height);
    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const context = canvas.getContext("2d");
    if (!context) throw new Error("This browser cannot process images for upload.");

    context.drawImage(decoded.source, 0, 0, width, height);
    let blob = await canvasBlob(canvas, "image/webp");
    let contentType: "image/webp" | "image/jpeg" = "image/webp";

    if (!blob || blob.type !== "image/webp") {
      contentType = "image/jpeg";
      const jpegCanvas = document.createElement("canvas");
      jpegCanvas.width = width;
      jpegCanvas.height = height;
      const jpegContext = jpegCanvas.getContext("2d");
      if (!jpegContext) throw new Error("This browser cannot process images for upload.");
      jpegContext.fillStyle = "#ffffff";
      jpegContext.fillRect(0, 0, width, height);
      jpegContext.drawImage(decoded.source, 0, 0, width, height);
      blob = await canvasBlob(jpegCanvas, "image/jpeg");
    }

    if (!blob) throw new Error("Image processing failed. Please try another image.");
    const validationError = validateUploadDeclaration(purpose, contentType, blob.size);
    if (validationError) throw new Error(validationError);

    const extension = contentType === "image/webp" ? "webp" : "jpg";
    return new File([blob], `upload.${extension}`, { type: contentType, lastModified: Date.now() });
  } finally {
    decoded.cleanup();
  }
}

export async function uploadToR2(file: File, options: UploadOptions): Promise<string> {
  const prepared = await prepareImageForUpload(file, options.purpose);
  const presign = await fetch("/api/r2/presign", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      contentType: prepared.type,
      size: prepared.size,
      purpose: options.purpose,
      ownerId: options.ownerId,
      resourceId: options.resourceId,
      index: options.index,
    }),
  });
  if (!presign.ok) throw new Error(await responseError(presign, "Could not authorize the upload."));

  const intent = await presign.json() as PresignResponse;
  if (!intent.uploadUrl || !intent.uploadToken || !intent.headers) throw new Error("The upload authorization response was invalid.");

  const upload = await fetch(intent.uploadUrl, {
    method: "PUT",
    headers: intent.headers,
    body: prepared,
  });
  if (!upload.ok) throw new Error("The image upload failed.");

  const finalize = await fetch("/api/r2/finalize", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ uploadToken: intent.uploadToken }),
  });
  if (!finalize.ok) throw new Error(await responseError(finalize, "The uploaded image could not be verified."));

  const result = await finalize.json() as FinalizeResponse;
  if (!result.publicUrl) throw new Error("The verified upload URL was missing.");
  return result.publicUrl;
}
