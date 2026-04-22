/** Verifies a Cloudflare Turnstile client token server-side. Returns true if passed, false otherwise.
 *  If TURNSTILE_SECRET_KEY is unset, treats verification as bypassed (dev mode). */
export async function verifyTurnstile(token: string | undefined | null, remoteIp?: string): Promise<boolean> {
  const secret = process.env.TURNSTILE_SECRET_KEY;
  if (!secret) {
    console.warn("[turnstile] TURNSTILE_SECRET_KEY not set — bypassing verification (dev mode)");
    return true;
  }
  if (!token) return false;

  const body = new URLSearchParams({ secret, response: token });
  if (remoteIp) body.set("remoteip", remoteIp);

  const res = await fetch("https://challenges.cloudflare.com/turnstile/v0/siteverify", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!res.ok) return false;
  const json = (await res.json()) as { success: boolean };
  return json.success === true;
}
