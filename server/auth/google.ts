import { randomBytes, createHash } from "crypto";

/** State payload embedded in `state` query param. Signed via HMAC? We use a short opaque nonce stored in cookie+DB is overkill; instead we sign the JSON with the cookie secret. For v1, we use a plain base64url — users can only harm their own flow. */
export interface OAuthState {
  mode: "web" | "mobile";
  redirectBack?: string; // web: post-signin SPA path; mobile: custom URL scheme
  codeChallenge?: string; // mobile PKCE
  codeChallengeMethod?: "S256";
}

export function encodeState(state: OAuthState): string {
  return Buffer.from(JSON.stringify(state)).toString("base64url");
}

export function decodeState(raw: string): OAuthState | null {
  try {
    return JSON.parse(Buffer.from(raw, "base64url").toString("utf8"));
  } catch {
    return null;
  }
}

export function buildGoogleAuthUrl(state: OAuthState): string {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const redirect = process.env.GOOGLE_OAUTH_REDIRECT_URL;
  if (!clientId || !redirect) throw new Error("Google OAuth env vars missing");

  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirect,
    response_type: "code",
    scope: "openid email profile",
    state: encodeState(state),
    access_type: "online",
    prompt: "select_account",
  });
  if (state.codeChallenge && state.codeChallengeMethod) {
    params.set("code_challenge", state.codeChallenge);
    params.set("code_challenge_method", state.codeChallengeMethod);
  }
  return `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
}

export interface GoogleIdentity {
  sub: string;
  email: string;
  emailVerified: boolean;
}

export async function exchangeGoogleCode(code: string, codeVerifier?: string): Promise<GoogleIdentity> {
  const clientId = process.env.GOOGLE_OAUTH_CLIENT_ID;
  const clientSecret = process.env.GOOGLE_OAUTH_CLIENT_SECRET;
  const redirect = process.env.GOOGLE_OAUTH_REDIRECT_URL;
  if (!clientId || !clientSecret || !redirect) throw new Error("Google OAuth env vars missing");

  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirect,
    grant_type: "authorization_code",
  });
  if (codeVerifier) body.set("code_verifier", codeVerifier);

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body,
  });
  if (!tokenRes.ok) {
    const t = await tokenRes.text();
    throw new Error(`Google token exchange failed: ${tokenRes.status} ${t}`);
  }
  const tokens = (await tokenRes.json()) as { id_token?: string; access_token?: string };
  if (!tokens.id_token) throw new Error("Google id_token missing");

  // Decode without full JWKS — we trust Google over HTTPS since we just fetched this directly from their token endpoint.
  const payloadRaw = tokens.id_token.split(".")[1];
  const payload = JSON.parse(Buffer.from(payloadRaw, "base64url").toString("utf8"));
  if (!payload.email) throw new Error("Google id_token missing email");
  return {
    sub: String(payload.sub),
    email: String(payload.email),
    emailVerified: payload.email_verified === true,
  };
}

/** Helper exposed for tests/mobile PKCE challenge generation on the server if ever needed. */
export function pkcePair(): { verifier: string; challenge: string } {
  const verifier = randomBytes(32).toString("base64url");
  const challenge = createHash("sha256").update(verifier).digest("base64url");
  return { verifier, challenge };
}
