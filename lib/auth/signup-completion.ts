import { getSignupUserKind, type SignupUserKind } from "./safety.ts";

export type SignupCompletionUser = {
  id: string;
  identities?: unknown[] | null;
  user_metadata?: Record<string, unknown> | null;
};

export type SignupCompletionDependencies = {
  clearAttemptMarker: (userId: string) => Promise<{ error: unknown | null }>;
  updateProfile: (input: {
    userId: string;
    handle: string;
    displayName: string;
  }) => Promise<{ data: { id: string } | null; error: unknown | null }>;
  deleteUser: (userId: string) => Promise<{ error: unknown | null }>;
};

export type SignupCompletionResult =
  | { kind: "success"; userKind: SignupUserKind }
  | { kind: "failure"; error: unknown; cleanupFailed: boolean };

export function getSuccessfulSignupResponse(userKind: SignupUserKind) {
  if (userKind === "confirmed-duplicate") {
    return {
      status: 400,
      body: { error: "That email is already registered. Try logging in instead." },
    } as const;
  }
  return { status: 200, body: { success: true } } as const;
}

type SignupCompletionInput = {
  user: SignupCompletionUser;
  signupAttemptId: string;
  handle: string;
  displayName: string;
};

export async function handleSignupProfileCompletion(
  input: SignupCompletionInput,
  dependencies: SignupCompletionDependencies
): Promise<SignupCompletionResult> {
  const userKind = getSignupUserKind(input.user, input.signupAttemptId);
  if (userKind !== "new") {
    return { kind: "success", userKind };
  }

  const failAndDeleteNewUser = async (error: unknown): Promise<SignupCompletionResult> => {
    try {
      const cleanup = await dependencies.deleteUser(input.user.id);
      return { kind: "failure", error, cleanupFailed: Boolean(cleanup.error) };
    } catch {
      return { kind: "failure", error, cleanupFailed: true };
    }
  };

  try {
    const markerCleanup = await dependencies.clearAttemptMarker(input.user.id);
    if (markerCleanup.error) return failAndDeleteNewUser(markerCleanup.error);

    const profileUpdate = await dependencies.updateProfile({
      userId: input.user.id,
      handle: input.handle,
      displayName: input.displayName,
    });
    if (profileUpdate.error || !profileUpdate.data) {
      return failAndDeleteNewUser(profileUpdate.error ?? new Error("Profile update returned no row."));
    }
  } catch (error) {
    return failAndDeleteNewUser(error);
  }

  return { kind: "success", userKind: "new" };
}
