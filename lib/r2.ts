export type R2Folder = "listings" | "avatars" | "headers" | "posts";

export async function uploadToR2(file: File, folder: R2Folder = "listings"): Promise<string> {
  // Get presigned URL from our API
  const res = await fetch("/api/r2/presign", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ filename: file.name, contentType: file.type, folder }),
  });
  if (!res.ok) throw new Error("Failed to get upload URL");
  const { uploadUrl, publicUrl } = await res.json();

  // Upload directly to R2
  const upload = await fetch(uploadUrl, {
    method: "PUT",
    headers: { "Content-Type": file.type },
    body: file,
  });
  if (!upload.ok) throw new Error("Upload to R2 failed");

  return publicUrl;
}
