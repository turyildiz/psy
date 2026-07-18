import config from "./policy.json" with { type: "json" };

const UUID = "[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}";
const EXTENSION = "(?:jpg|png|webp)";

function publicKeyFromUrl(value: string, publicBaseUrl: string) {
  try {
    const base = new URL(publicBaseUrl.endsWith("/") ? publicBaseUrl : `${publicBaseUrl}/`);
    const candidate = new URL(value);
    if (candidate.origin !== base.origin) return null;
    const basePath = base.pathname.endsWith("/") ? base.pathname : `${base.pathname}/`;
    if (!candidate.pathname.startsWith(basePath)) return null;
    const key = decodeURIComponent(candidate.pathname.slice(basePath.length));
    return key && !key.startsWith("/") ? key : null;
  } catch {
    return null;
  }
}

export function mediaValuesReferenceKey(values: unknown[], key: string, publicBaseUrl: string): boolean {
  for (const value of values) {
    if (Array.isArray(value)) {
      if (mediaValuesReferenceKey(value, key, publicBaseUrl)) return true;
      continue;
    }
    if (typeof value === "string" && publicKeyFromUrl(value, publicBaseUrl) === key) return true;
  }
  return false;
}

export function promotedKeyCandidatesForPending(pendingKey: string) {
  const match = new RegExp(`^pending/(${UUID})/(${UUID}\\.${EXTENSION})$`).exec(pendingKey);
  if (!match) return [];
  const [, userId, filename] = match;
  return Object.values(config.purposes).map(({ folder }) => `${folder}/${userId}/${filename}`);
}
