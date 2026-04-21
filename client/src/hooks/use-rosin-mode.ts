import { useEffect, useState } from "react";

export type RosinMode = "novice" | "pro";

const STORAGE_KEY = "rosin.mode";

export function useRosinMode(): [RosinMode, (mode: RosinMode) => void] {
  const [mode, setMode] = useState<RosinMode>(() => {
    if (typeof window === "undefined") return "novice";
    const stored = window.localStorage.getItem(STORAGE_KEY);
    return stored === "pro" ? "pro" : "novice";
  });

  useEffect(() => {
    window.localStorage.setItem(STORAGE_KEY, mode);
  }, [mode]);

  return [mode, setMode];
}
