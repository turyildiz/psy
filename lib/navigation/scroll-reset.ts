export const SCROLL_RESET_KEY = "psy_scroll_top_after_navigation";
const LEGACY_SCROLL_RESET_KEY = "psy_scroll_top_after_login";

export type ScrollResetWindow = {
  sessionStorage: Pick<Storage, "getItem" | "setItem" | "removeItem">;
  history: { scrollRestoration: ScrollRestoration };
  scrollTo: (x: number, y: number) => void;
  requestAnimationFrame: (callback: FrameRequestCallback) => number;
  location: Pick<Location, "reload" | "assign">;
};

function currentWindow(): ScrollResetWindow {
  return window;
}

function prepareTopNavigation(target: ScrollResetWindow) {
  try {
    target.sessionStorage.setItem(SCROLL_RESET_KEY, "1");
  } catch {}
  target.history.scrollRestoration = "manual";
  target.scrollTo(0, 0);
}

export function reloadAtTop(target: ScrollResetWindow = currentWindow()) {
  prepareTopNavigation(target);
  target.location.reload();
}

export function assignAtTop(href: string, target: ScrollResetWindow = currentWindow()) {
  prepareTopNavigation(target);
  target.location.assign(href);
}

export function restoreTopAfterNavigation(target: ScrollResetWindow = currentWindow()) {
  let shouldRestore = false;
  try {
    shouldRestore = target.sessionStorage.getItem(SCROLL_RESET_KEY) === "1"
      || target.sessionStorage.getItem(LEGACY_SCROLL_RESET_KEY) === "1";
    if (!shouldRestore) return false;
    target.sessionStorage.removeItem(SCROLL_RESET_KEY);
    target.sessionStorage.removeItem(LEGACY_SCROLL_RESET_KEY);
  } catch {
    return false;
  }

  target.scrollTo(0, 0);
  target.requestAnimationFrame(() => {
    target.scrollTo(0, 0);
    target.history.scrollRestoration = "auto";
  });
  return true;
}
