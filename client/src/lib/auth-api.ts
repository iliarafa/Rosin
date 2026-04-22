import type { AccountPublic } from "@shared/schema";

async function handle<T>(res: Response): Promise<T> {
  if (!res.ok) {
    const body = await res.json().catch(() => ({}));
    throw new Error(body.error || `HTTP ${res.status}`);
  }
  return (await res.json()) as T;
}

export async function requestEmailCode(email: string, turnstileToken?: string): Promise<void> {
  await handle(
    await fetch("/api/auth/email/request", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, turnstileToken }),
      credentials: "include",
    }),
  );
}

export async function verifyEmailCode(email: string, code: string): Promise<{ account: AccountPublic }> {
  return handle(
    await fetch("/api/auth/email/verify", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ email, code }),
      credentials: "include",
    }),
  );
}

export async function me(): Promise<{ account: AccountPublic } | null> {
  const res = await fetch("/api/auth/me", { credentials: "include" });
  if (res.status === 401) return null;
  return handle(res);
}

export async function signOut(): Promise<void> {
  await fetch("/api/auth/logout", { method: "POST", credentials: "include" });
}

export async function signInWithAppleToken(identityToken: string): Promise<{ account: AccountPublic }> {
  return handle(
    await fetch("/api/auth/apple/token", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      credentials: "include",
      body: JSON.stringify({ identityToken }),
    }),
  );
}
