import { jwtVerify, createRemoteJWKSet } from "jose";

const APPLE_JWKS = createRemoteJWKSet(new URL("https://appleid.apple.com/auth/keys"));
const APPLE_ISSUER = "https://appleid.apple.com";

export interface AppleIdentity {
  sub: string;
  email?: string;
  emailVerified: boolean;
}

/** Verifies an Apple Sign In identity token (the one iOS's ASAuthorizationAppleIDCredential returns).
 *  Audience must match APPLE_CLIENT_ID (our bundle identifier).
 *  Apple only includes the email claim on the FIRST authorization; subsequent sign-ins
 *  return sub only — callers must re-link by providerSubject. */
export async function verifyAppleIdentityToken(idToken: string): Promise<AppleIdentity> {
  const audience = process.env.APPLE_CLIENT_ID;
  if (!audience) throw new Error("APPLE_CLIENT_ID not set");
  const { payload } = await jwtVerify(idToken, APPLE_JWKS, { issuer: APPLE_ISSUER, audience });
  const sub = String(payload.sub ?? "");
  const email = typeof payload.email === "string" ? payload.email : undefined;
  if (!sub) {
    throw new Error("Apple token missing sub");
  }
  return {
    sub,
    email,
    emailVerified: payload.email_verified === true || payload.email_verified === "true",
  };
}
