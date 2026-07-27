import {
  createCipheriv,
  createDecipheriv,
  createHmac,
  randomBytes,
} from "node:crypto";

export const RECOVERY_PROOF_COOKIE = "psy_recovery_proof";
export const RECOVERY_PROOF_TTL_SECONDS = 15 * 60;

export type RecoveryProofPhase = "password" | "revoke";

export type RecoverySessionEnvelope = {
  phase: RecoveryProofPhase;
  userId: string;
  accessToken: string;
  refreshToken: string;
  expiresAt: number;
};

type RecoveryProofPayload = RecoverySessionEnvelope & {
  version: 2;
};

function deriveEncryptionKey(serverSecret: string) {
  if (!serverSecret) throw new Error("Recovery proof encryption secret is unavailable.");
  return createHmac("sha256", serverSecret)
    .update("psy-market-auth-recovery-envelope-v2")
    .digest();
}

export function assertRecoveryProofConfiguration(serverSecret: string) {
  deriveEncryptionKey(serverSecret);
}

export function createRecoveryProof(
  input: RecoverySessionEnvelope,
  serverSecret: string
) {
  const payload: RecoveryProofPayload = { version: 2, ...input };
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", deriveEncryptionKey(serverSecret), iv);
  cipher.setAAD(Buffer.from("psy-recovery-v2"));
  const ciphertext = Buffer.concat([
    cipher.update(JSON.stringify(payload), "utf8"),
    cipher.final(),
  ]);
  const tag = cipher.getAuthTag();
  return [
    "v2",
    iv.toString("base64url"),
    ciphertext.toString("base64url"),
    tag.toString("base64url"),
  ].join(".");
}

export function verifyRecoveryProof(
  value: string | undefined,
  expectedPhase: RecoveryProofPhase,
  serverSecret: string,
  now = Date.now()
): RecoverySessionEnvelope | null {
  if (!value) return null;
  const [version, encodedIv, encodedCiphertext, encodedTag, extra] = value.split(".");
  if (version !== "v2" || !encodedIv || !encodedCiphertext || !encodedTag || extra) return null;

  try {
    const iv = Buffer.from(encodedIv, "base64url");
    const ciphertext = Buffer.from(encodedCiphertext, "base64url");
    const tag = Buffer.from(encodedTag, "base64url");
    if (iv.length !== 12 || tag.length !== 16 || ciphertext.length === 0) return null;

    const decipher = createDecipheriv("aes-256-gcm", deriveEncryptionKey(serverSecret), iv);
    decipher.setAAD(Buffer.from("psy-recovery-v2"));
    decipher.setAuthTag(tag);
    const payload = JSON.parse(Buffer.concat([
      decipher.update(ciphertext),
      decipher.final(),
    ]).toString("utf8")) as Partial<RecoveryProofPayload>;

    if (
      payload.version !== 2
      || payload.phase !== expectedPhase
      || typeof payload.userId !== "string"
      || !payload.userId
      || typeof payload.accessToken !== "string"
      || !payload.accessToken
      || typeof payload.refreshToken !== "string"
      || !payload.refreshToken
      || typeof payload.expiresAt !== "number"
      || !Number.isFinite(payload.expiresAt)
      || payload.expiresAt <= now
    ) {
      return null;
    }

    return {
      phase: payload.phase,
      userId: payload.userId,
      accessToken: payload.accessToken,
      refreshToken: payload.refreshToken,
      expiresAt: payload.expiresAt,
    };
  } catch {
    return null;
  }
}
