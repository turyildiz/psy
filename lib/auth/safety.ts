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

export function isAllowedAuthRequestOrigin(
  origin: string | null,
  configuredSiteUrl?: string,
  allowLocalDevelopment = false
) {
  if (!origin) return false;
  try {
    const parsedOrigin = new URL(origin).origin;
    return parsedOrigin === origin
      && getAllowedAuthOrigin(origin, configuredSiteUrl, allowLocalDevelopment) === origin;
  } catch {
    return false;
  }
}

export function getRecoveryToken(fragment: string) {
  if (!fragment.startsWith("#")) return null;
  const params = new URLSearchParams(fragment.slice(1));
  const types = params.getAll("type");
  const tokenHashes = params.getAll("token_hash");
  if (types.length !== 1 || types[0] !== "recovery" || tokenHashes.length !== 1) return null;
  const tokenHash = tokenHashes[0].trim();
  return tokenHash || null;
}

export function getAuthCallbackCredentials(search: string, hash: string) {
  const params = new URLSearchParams(search.startsWith("?") ? search.slice(1) : search);
  const hashParams = new URLSearchParams(hash.startsWith("#") ? hash.slice(1) : hash);
  const isRecovery = [
    ...params.getAll("type"),
    ...hashParams.getAll("type"),
  ].includes("recovery");
  return {
    isRecovery,
    code: isRecovery ? null : params.get("code"),
    accessToken: isRecovery ? null : hashParams.get("access_token"),
    refreshToken: isRecovery ? null : hashParams.get("refresh_token"),
    signupTokenHash:
      isRecovery
        ? null
        : hashParams.get("type") === "signup"
          ? hashParams.get("token_hash")
          : params.get("type") === "signup"
            ? params.get("token_hash")
            : null,
  };
}

export function getRecoveryVerificationErrorStatus(error: {
  name?: string;
  status?: number;
} | null | undefined): 400 | 429 | 503 {
  if (error?.status === 429) return 429;
  if (
    error?.name === "AuthRetryableFetchError"
    || error?.status === 0
    || (typeof error?.status === "number" && error.status >= 500)
  ) {
    return 503;
  }
  return 400;
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

type HandleAvailabilityResult = {
  profileExists?: boolean;
  blockedExists?: boolean;
  profileError?: boolean;
  blockedError?: boolean;
};

export function getHandleAvailabilityError(result: HandleAvailabilityResult) {
  if (result.profileError || result.blockedError) {
    return "We couldn’t check this handle. Please try again.";
  }
  if (result.blockedExists) {
    return "This handle is reserved. Please choose another.";
  }
  if (result.profileExists) {
    return "This handle is already taken.";
  }
  return null;
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
