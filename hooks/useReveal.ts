"use client";

import { useState, useEffect, useCallback } from "react";

export function useReveal(threshold = 0.08) {
  const [el, setEl] = useState<HTMLDivElement | null>(null);
  const [vis, setVis] = useState(false);

  const ref = useCallback((node: HTMLDivElement | null) => setEl(node), []);

  useEffect(() => {
    if (!el) return;
    if (el.getBoundingClientRect().top < window.innerHeight) {
      setVis(true);
      return;
    }
    const obs = new IntersectionObserver(
      ([e]) => {
        if (e.isIntersecting) {
          setVis(true);
          obs.disconnect();
        }
      },
      { threshold }
    );
    obs.observe(el);
    return () => obs.disconnect();
  }, [el, threshold]);

  return [ref, vis] as const;
}
