type AuthRefreshObservation = {
  userId: string | null;
  refreshes: Promise<unknown>[];
};

type AuthUiTransitionState = {
  cancelled: boolean;
  expectedUserId: string | undefined;
  pendingParticipants: Set<symbol>;
  observations: Map<symbol, AuthRefreshObservation>;
  refreshes: Promise<unknown>[];
  ready: Promise<void>;
  markReady: () => void;
};

export type AuthUiTransition = {
  expect: (userId: string) => void;
  wait: () => Promise<void>;
  cancel: () => void;
};

export type AuthUiRefreshParticipant = {
  track: <T>(userId: string | null, refresh: Promise<T>) => Promise<T>;
  unregister: () => void;
};

const registeredParticipants = new Set<symbol>();
let activeTransition: AuthUiTransitionState | null = null;

function resolveIfReady(state: AuthUiTransitionState) {
  if (state.expectedUserId !== undefined && state.pendingParticipants.size === 0) {
    state.markReady();
  }
}

function acceptMatchingObservation(state: AuthUiTransitionState, participantId: symbol) {
  const observation = state.observations.get(participantId);
  if (
    observation
    && observation.userId === state.expectedUserId
    && state.pendingParticipants.delete(participantId)
  ) {
    state.refreshes.push(...observation.refreshes);
    resolveIfReady(state);
  }
}

export function registerAuthUiRefreshParticipant(): AuthUiRefreshParticipant {
  const participantId = Symbol("auth-ui-refresh-participant");
  registeredParticipants.add(participantId);
  let registered = true;

  return {
    track(userId, refresh) {
      const state = activeTransition;
      if (state && state.pendingParticipants.has(participantId)) {
        const existingObservation = state.observations.get(participantId);
        if (existingObservation?.userId === userId) {
          existingObservation.refreshes.push(refresh);
        } else {
          state.observations.set(participantId, { userId, refreshes: [refresh] });
        }
        acceptMatchingObservation(state, participantId);
      }
      return refresh;
    },
    unregister() {
      if (!registered) return;
      registered = false;
      registeredParticipants.delete(participantId);
      const state = activeTransition;
      if (state?.pendingParticipants.delete(participantId)) resolveIfReady(state);
    },
  };
}

export function tryBeginAuthUiTransition(): AuthUiTransition | null {
  if (activeTransition) return null;

  let markReady: () => void = () => undefined;
  const ready = new Promise<void>((resolve) => { markReady = resolve; });
  const state: AuthUiTransitionState = {
    cancelled: false,
    expectedUserId: undefined,
    pendingParticipants: new Set(registeredParticipants),
    observations: new Map(),
    refreshes: [],
    ready,
    markReady,
  };
  activeTransition = state;

  return {
    expect(userId) {
      if (state.cancelled || state.expectedUserId !== undefined) return;
      state.expectedUserId = userId;
      for (const participantId of Array.from(state.pendingParticipants)) {
        acceptMatchingObservation(state, participantId);
      }
      resolveIfReady(state);
    },
    async wait() {
      await state.ready;
      if (!state.cancelled) await Promise.allSettled(state.refreshes);
      if (activeTransition === state) activeTransition = null;
    },
    cancel() {
      state.cancelled = true;
      state.markReady();
      if (activeTransition === state) activeTransition = null;
    },
  };
}
