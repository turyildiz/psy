export const LISTING_DESCRIPTION_MIN = 20;
export const LISTING_DESCRIPTION_MAX = 2000;
export const LISTING_DESCRIPTION_ERROR = "Description must be between 20 and 2,000 characters.";

export function validateListingDescription(value: string) {
  const length = value.trim().length;
  return length < LISTING_DESCRIPTION_MIN || length > LISTING_DESCRIPTION_MAX
    ? LISTING_DESCRIPTION_ERROR
    : null;
}

export function getListingWriteErrorMessage(error: unknown, action: "publish" | "save") {
  const record = typeof error === "object" && error !== null
    ? error as Record<string, unknown>
    : {};
  const databaseText = [record.code, record.message, record.details, record.hint]
    .filter((value): value is string => typeof value === "string")
    .join(" ")
    .toLowerCase();

  if (databaseText.includes("description_length")) return LISTING_DESCRIPTION_ERROR;
  return action === "publish"
    ? "Could not publish listing. Please try again."
    : "Could not save changes. Please try again.";
}
