export type InitialAuthSnapshotGate<T> = {
  applyInitial: (value: T) => void;
  applyEvent: (value: T) => void;
};

export type WallAuthRefreshMode = "none" | "initial" | "silent" | "secure-reset";

export function getWallAuthRefreshMode(
  previousUserId: string | null | undefined,
  nextUserId: string | null
): WallAuthRefreshMode {
  if (previousUserId === nextUserId) return "none";
  if (previousUserId === undefined) return "initial";
  if (nextUserId !== null && previousUserId === null) return "silent";
  return "secure-reset";
}

export type WallAuthRefreshCoordinator = {
  observe: (nextUserId: string | null) => Promise<void>;
};

export function createWallAuthRefreshCoordinator({
  clearSensitiveRows,
  refresh,
}: {
  clearSensitiveRows: () => void;
  refresh: (options: { silent: boolean }) => Promise<void>;
}): WallAuthRefreshCoordinator {
  let previousUserId: string | null | undefined;

  return {
    async observe(nextUserId) {
      const mode = getWallAuthRefreshMode(previousUserId, nextUserId);
      previousUserId = nextUserId;
      if (mode === "none") return;
      if (mode === "secure-reset") clearSensitiveRows();
      await refresh({ silent: mode === "silent" });
    },
  };
}

export function createInitialAuthSnapshotGate<T>(
  applyLatest: (value: T) => void
): InitialAuthSnapshotGate<T> {
  let eventObserved = false;

  return {
    applyInitial(value) {
      if (!eventObserved) applyLatest(value);
    },
    applyEvent(value) {
      eventObserved = true;
      applyLatest(value);
    },
  };
}
