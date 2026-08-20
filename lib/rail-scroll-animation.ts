const RAIL_SCROLL_DURATION_MS = 420;

function easeInOutCubic(progress: number) {
  return progress < 0.5
    ? 4 * progress * progress * progress
    : 1 - Math.pow(-2 * progress + 2, 3) / 2;
}

export function getRailItemTargetLeft(rail: HTMLElement, item: HTMLElement, startInset = 0) {
  const railRect = rail.getBoundingClientRect();
  const itemRect = item.getBoundingClientRect();
  return rail.scrollLeft + itemRect.left - railRect.left - startInset;
}

export function animateRailScroll(rail: HTMLElement, requestedLeft: number, reducedMotion: boolean) {
  const targetLeft = Math.max(0, Math.min(requestedLeft, rail.scrollWidth - rail.clientWidth));
  const startLeft = rail.scrollLeft;
  const previousSnapType = rail.style.scrollSnapType;
  const previousScrollBehavior = rail.style.scrollBehavior;
  let animationFrame = 0;
  let startTime: number | null = null;
  let restored = false;

  const restoreRailBehavior = () => {
    if (restored) return;
    restored = true;
    if (previousSnapType) rail.style.scrollSnapType = previousSnapType;
    else rail.style.removeProperty("scroll-snap-type");
    if (previousScrollBehavior) rail.style.scrollBehavior = previousScrollBehavior;
    else rail.style.removeProperty("scroll-behavior");
  };

  if (reducedMotion || Math.abs(targetLeft - startLeft) <= 0.5) {
    rail.scrollLeft = targetLeft;
    return restoreRailBehavior;
  }

  rail.style.scrollSnapType = "none";
  rail.style.scrollBehavior = "auto";

  const step = (timestamp: number) => {
    startTime ??= timestamp;
    const progress = Math.min((timestamp - startTime) / RAIL_SCROLL_DURATION_MS, 1);
    rail.scrollLeft = startLeft + (targetLeft - startLeft) * easeInOutCubic(progress);

    if (progress < 1) {
      animationFrame = requestAnimationFrame(step);
      return;
    }

    rail.scrollLeft = targetLeft;
    restoreRailBehavior();
  };

  animationFrame = requestAnimationFrame(step);

  return () => {
    if (animationFrame) cancelAnimationFrame(animationFrame);
    restoreRailBehavior();
  };
}
