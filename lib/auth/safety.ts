const AUTH_ORIGINS = new Set([
  "https://psy.market",
  "https://www.psy.market",
  "https://psy.heyturgay.com",
]);

export function getAllowedAuthOrigin(
  requestUrl: string,
  configuredSiteUrl?: string,
  allowLocalDevelopment = false
) {
  const allowed = new Set(AUTH_ORIGINS);
  let configuredOrigin: string | null = null;

  if (configuredSiteUrl) {
    try {
      const parsed = new URL(configuredSiteUrl);
      if (parsed.protocol === "https:" || (allowLocalDevelopment && parsed.protocol === "http:")) {
        configuredOrigin = parsed.origin;
        allowed.add(configuredOrigin);
      }
    } catch {}
  }

  if (allowLocalDevelopment) {
    allowed.add("http://localhost:3000");
    allowed.add("http://localhost:3030");
    allowed.add("http://127.0.0.1:3000");
    allowed.add("http://127.0.0.1:3030");
  }

  try {
    const requestOrigin = new URL(requestUrl).origin;
    if (allowed.has(requestOrigin)) return requestOrigin;
  } catch {}

  return configuredOrigin ?? "https://psy.market";
}

export function getSafeRedirect(
  value: string | null | undefined,
  allowedOrigin: string,
  fallback = "/"
) {
  if (!value) return fallback;

  const candidate = value.trim();
  if (!candidate || /[\u0000-\u001f\u007f]/.test(candidate)) return fallback;
  if (!candidate.startsWith("/") && !/^https?:\/\//i.test(candidate)) return fallback;

  try {
    const origin = new URL(allowedOrigin).origin;
    const target = new URL(candidate, origin);
    if (target.origin !== origin) return fallback;
    if (!target.pathname.startsWith("/") || target.pathname.startsWith("//")) return fallback;
    return `${target.pathname}${target.search}${target.hash}`;
  } catch {
    return fallback;
  }
}

export function normalizeHandle(handle: string) {
  return handle.trim().toLowerCase();
}

export function validateHandle(handle: string) {
  const normalized = normalizeHandle(handle);
  if (normalized.length < 3) return "Handle must be at least 3 characters.";
  if (normalized.length > 30) return "Handle must be 30 characters or fewer.";
  if (!/^[a-z0-9_]+$/.test(normalized)) return "Use only letters, numbers, and underscores.";
  return null;
}

export function isExistingSignupUser(user: { identities?: unknown[] | null }) {
  return Array.isArray(user.identities) && user.identities.length === 0;
}

export function getFriendlySignupError(message?: string | null) {
  const normalized = (message ?? "").toLowerCase();

  if (normalized.includes("handle is reserved") || normalized.includes("reserved handle")) {
    return "This handle is reserved. Please choose another.";
  }
  if (
    normalized.includes("profiles_handle_lower_key") ||
    normalized.includes("duplicate key") ||
    normalized.includes("handle already taken")
  ) {
    return "This handle is already taken.";
  }
  if (
    normalized.includes("handle must contain") ||
    normalized.includes("invalid handle")
  ) {
    return "Use a handle with 3–30 letters, numbers, or underscores.";
  }
  if (
    normalized.includes("already registered") ||
    normalized.includes("already been registered")
  ) {
    return "That email is already registered. Try logging in instead.";
  }
  if (normalized.includes("rate limit")) {
    return "Too many signup attempts. Please wait a moment and try again.";
  }

  return "We couldn’t create your account. Please try again.";
}
