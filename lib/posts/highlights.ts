export const POST_HIGHLIGHT_LIMIT_MESSAGE = "You can highlight up to 5 posts; unhighlight one first.";

export function getPostHighlightErrorMessage(error: unknown) {
  const record = typeof error === "object" && error !== null
    ? error as Record<string, unknown>
    : {};

  if (record.message === POST_HIGHLIGHT_LIMIT_MESSAGE) {
    return POST_HIGHLIGHT_LIMIT_MESSAGE;
  }

  const databaseText = [record.message, record.details, record.hint]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();

  if (databaseText.includes("burst limit")) {
    return "You’re changing highlights too quickly. Please wait a few minutes and try again.";
  }

  return "Could not update this highlight. Please try again.";
}

export function getPostHighlightPreview(body: string, maxCharacters = 80) {
  const compact = body.trim().replace(/\s+/g, " ");
  const characters = Array.from(compact);
  if (characters.length <= maxCharacters) return compact;
  return `${characters.slice(0, maxCharacters).join("")}…`;
}
