export const POST_BODY_MAX = 2000;

export type PostBodyToken = {
  type: "text" | "link";
  value: string;
};

export function getPostCharacterCount(value: string) {
  return Array.from(value).length;
}

export function validatePostBody(value: string) {
  if (!value.trim()) return "Write something before publishing.";
  if (getPostCharacterCount(value) > POST_BODY_MAX) return "Posts can be up to 2,000 characters.";
  return null;
}

export function getPostWriteErrorMessage(
  error: unknown,
  action: "publish" | "save" | "delete"
) {
  const record = typeof error === "object" && error !== null
    ? error as Record<string, unknown>
    : {};
  const databaseText = [record.code, record.message, record.details, record.hint]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();

  if (databaseText.includes("burst limit")) {
    return "You’re posting too quickly. Please wait a few minutes and try again.";
  }
  if (databaseText.includes("blocked link")) {
    return "One of your links isn’t allowed. Remove it and try again.";
  }
  if (databaseText.includes("between 1 and 2000") || databaseText.includes("posts_body_check")) {
    return "Posts need some text and can be up to 2,000 characters.";
  }
  if (
    databaseText.includes("post images")
    || databaseText.includes("post image url")
    || databaseText.includes("posts_images_check")
  ) {
    return "Posts can contain up to five valid images. Please review your images and try again.";
  }
  if (databaseText.includes("banned users cannot")) {
    return "Your account can’t publish posts.";
  }

  if (action === "publish") return "Could not publish this post. Please try again.";
  if (action === "save") return "Could not save your changes. Please try again.";
  return "Could not delete this post. Please try again.";
}

export function tokenizePostBody(body: string): PostBodyToken[] {
  const tokens: PostBodyToken[] = [];
  const pushText = (value: string) => {
    if (!value) return;
    const previous = tokens[tokens.length - 1];
    if (previous?.type === "text") previous.value += value;
    else tokens.push({ type: "text", value });
  };
  const matcher = /https?:\/\/[^\s<>"']+/gi;
  let cursor = 0;

  let match: RegExpExecArray | null;
  while ((match = matcher.exec(body)) !== null) {
    const index = match.index;
    if (index > cursor) pushText(body.slice(cursor, index));

    const candidate = match[0];
    const url = candidate.replace(/[),.!?;:\]}]+$/g, "");
    const punctuation = candidate.slice(url.length);
    tokens.push({ type: "link", value: url });
    pushText(punctuation);
    cursor = index + candidate.length;
  }

  if (cursor < body.length) pushText(body.slice(cursor));
  return tokens.length > 0 ? tokens : [{ type: "text", value: body }];
}
