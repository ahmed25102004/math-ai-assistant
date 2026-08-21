import { createClient, type SupportedStorage } from "@supabase/supabase-js";
// @ts-ignore
import WebSocket from "ws";
import { env } from "@/config/env";
import { STORAGE_KEYS } from "@/constants";

/**
 * THE single Supabase client for the whole application.
 *
 * This is the only place `@supabase/supabase-js` is instantiated. Every
 * feature (auth, data, storage) must reuse this exported singleton instead of
 * creating its own client, so we always talk to the same project with the same
 * session and options.
 *
 * All configuration is read from `src/config/env.ts` — no env vars are
 * duplicated here. The anon key lives in `env.SUPABASE_ANON_KEY` today, so we
 * resolve `env.SUPABASE_KEY` through it without re-declaring the variable.
 */
const config = env as typeof env & { SUPABASE_KEY?: string };
const supabaseKey = config.SUPABASE_KEY ?? config.SUPABASE_ANON_KEY;

/**
 * Remember-me aware storage adapter.
 *
 * When the user checked "Remember me" on login (`cortexa.remember` !== "0")
 * the session token is written to localStorage, so it survives full page
 * reloads. When the box is unchecked the token only lives in memory and is
 * dropped as soon as the tab is closed.
 *
 * The adapter decides where to write at *write* time based on the flag, so the
 * same Supabase client serves both modes with no re-instantiation.
 */
function isRemembered(): boolean {
  if (typeof window === "undefined") return true;
  return window.localStorage.getItem(STORAGE_KEYS.remember) !== "0";
}

const memoryStorage = new Map<string, string>();

const supabaseStorage: SupportedStorage = {
  getItem(key: string): string | null {
    if (isRemembered()) {
      return typeof window === "undefined" ? null : window.localStorage.getItem(key);
    }
    return memoryStorage.get(key) ?? null;
  },
  setItem(key: string, value: string): void {
    if (isRemembered()) {
      if (typeof window !== "undefined") window.localStorage.setItem(key, value);
    } else {
      memoryStorage.set(key, value);
    }
  },
  removeItem(key: string): void {
    if (isRemembered()) {
      if (typeof window !== "undefined") window.localStorage.removeItem(key);
    } else {
      memoryStorage.delete(key);
    }
  },
};

const validUrl =
  env.SUPABASE_URL && env.SUPABASE_URL.startsWith("http")
    ? env.SUPABASE_URL
    : "https://retwsdbhkmxdtvoaaevy.supabase.co";
const validKey =
  supabaseKey && supabaseKey.length > 0
    ? supabaseKey
    : "sb_publishable_wa8namvqCW6LNcJD80-1SQ_CFGXP48b";

export const supabase = createClient(validUrl, validKey, {
  auth: {
    persistSession: typeof window !== "undefined",
    autoRefreshToken: typeof window !== "undefined",
    detectSessionInUrl: typeof window !== "undefined",
    storage: supabaseStorage,
  },
  realtime: {
    transport: typeof window !== "undefined" ? undefined : (WebSocket as any),
  },
});
