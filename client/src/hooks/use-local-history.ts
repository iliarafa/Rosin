import { useState, useCallback, useEffect } from "react";
import { type StageOutput, type VerificationSummary, type LLMModel } from "@shared/schema";

// ── Local-only verification history (localStorage) ─────────────────
// All history data stays 100% on the user's device. No server calls,
// no cloud sync, no data collection. Uses localStorage with JSON encoding.

const STORAGE_KEY = "rosin_local_history";
const MAX_ITEMS = 50;

/** A single saved verification session — contains the full pipeline result
 *  so every expandable section (stages, judge verdict, provenance, scores)
 *  works when replaying a past session. */
export interface LocalHistoryItem {
  id: string;
  query: string;
  chain: LLMModel[];
  stages: StageOutput[];
  summary: VerificationSummary | null;
  adversarialMode: boolean;
  createdAt: string;
}

/** Read all history items from localStorage */
function readItems(): LocalHistoryItem[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    return JSON.parse(raw) as LocalHistoryItem[];
  } catch {
    return [];
  }
}

/** Write items to localStorage */
function writeItems(items: LocalHistoryItem[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(items));
  } catch (e) {
    // localStorage full — drop oldest items and retry
    const trimmed = items.slice(0, Math.floor(items.length / 2));
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(trimmed));
    } catch {
      console.error("localStorage full, unable to save history");
    }
  }
}

/** Hook for managing local-only verification history.
 *  Returns the items list and CRUD operations. */
export function useLocalHistory() {
  const [items, setItems] = useState<LocalHistoryItem[]>([]);

  // Load from localStorage on mount
  useEffect(() => {
    setItems(readItems());
  }, []);

  /** Save a new verification result (prepends, caps at MAX_ITEMS) */
  const save = useCallback((item: Omit<LocalHistoryItem, "id" | "createdAt">) => {
    const newItem: LocalHistoryItem = {
      ...item,
      id: crypto.randomUUID(),
      createdAt: new Date().toISOString(),
    };
    setItems((prev) => {
      const updated = [newItem, ...prev].slice(0, MAX_ITEMS);
      writeItems(updated);
      return updated;
    });
  }, []);

  /** Get a single item by ID */
  const getById = useCallback((id: string): LocalHistoryItem | undefined => {
    return readItems().find((item) => item.id === id);
  }, []);

  /** Delete a single item by ID */
  const remove = useCallback((id: string) => {
    setItems((prev) => {
      const updated = prev.filter((item) => item.id !== id);
      writeItems(updated);
      return updated;
    });
  }, []);

  /** Clear all history — 100% local deletion */
  const clearAll = useCallback(() => {
    localStorage.removeItem(STORAGE_KEY);
    setItems([]);
  }, []);

  return { items, save, getById, remove, clearAll };
}
