import { useEffect, useState } from "react";
import { useLocation } from "wouter";
import { requestEmailCode, verifyEmailCode, signInWithAppleToken } from "@/lib/auth-api";
import { useAuth } from "@/hooks/use-auth";

type Phase = "choose" | "email-input" | "code-input";

export default function SignInPage() {
  const [, nav] = useLocation();
  const { refresh } = useAuth();
  const [phase, setPhase] = useState<Phase>("choose");
  const [email, setEmail] = useState("");
  const [code, setCode] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [sending, setSending] = useState(false);

  // Read Turnstile token from the widget when we add it. For dev (no TURNSTILE_SECRET_KEY set server-side), we can pass empty and server bypasses.
  const [turnstileToken, setTurnstileToken] = useState<string>("");

  useEffect(() => {
    if (phase !== "choose") return;
    const servicesId = import.meta.env.VITE_APPLE_SERVICES_ID;
    const returnURL = import.meta.env.VITE_APPLE_RETURN_URL;
    if (!servicesId || !returnURL) return; // dev mode — Apple button is inert
    // @ts-ignore — SDK-provided global
    if (typeof AppleID === "undefined") return;
    // @ts-ignore
    AppleID.auth.init({
      clientId: servicesId,
      scope: "email",
      redirectURI: returnURL,
      usePopup: true,
    });

    function onSuccess(evt: any) {
      const token = evt?.detail?.authorization?.id_token;
      if (!token) return;
      (async () => {
        try {
          await signInWithAppleToken(token);
          await refresh();
          nav("/");
        } catch (err) {
          setError(err instanceof Error ? err.message : "Apple sign-in failed");
        }
      })();
    }
    function onFailure(evt: any) {
      setError(evt?.detail?.error || "Apple sign-in cancelled");
    }
    document.addEventListener("AppleIDSignInOnSuccess", onSuccess);
    document.addEventListener("AppleIDSignInOnFailure", onFailure);
    return () => {
      document.removeEventListener("AppleIDSignInOnSuccess", onSuccess);
      document.removeEventListener("AppleIDSignInOnFailure", onFailure);
    };
  }, [phase, nav, refresh]);

  async function onRequestCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSending(true);
    try {
      await requestEmailCode(email, turnstileToken || undefined);
      setPhase("code-input");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed");
    } finally {
      setSending(false);
    }
  }

  async function onVerifyCode(e: React.FormEvent) {
    e.preventDefault();
    setError(null);
    setSending(true);
    try {
      await verifyEmailCode(email, code);
      await refresh();
      nav("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Failed");
    } finally {
      setSending(false);
    }
  }

  return (
    <div className="min-h-screen bg-black text-zinc-100 font-mono flex items-center justify-center px-6">
      <div className="w-full max-w-md space-y-6">
        <div className="text-center space-y-2">
          <div className="text-green-500 text-sm">● ROSIN</div>
          <div className="text-zinc-500 text-xs uppercase tracking-widest">[ SIGN IN ]</div>
        </div>

        {phase === "choose" && (
          <div className="space-y-3">
            <a
              href="/api/auth/google/start"
              className="block text-center border border-zinc-700 hover:border-green-500 rounded px-4 py-3"
              data-testid="signin-google"
            >
              Continue with Google
            </a>
            <button
              type="button"
              onClick={() => setPhase("email-input")}
              className="w-full border border-zinc-700 hover:border-green-500 rounded px-4 py-3"
              data-testid="signin-email"
            >
              Continue with Email
            </button>
            {/* Apple button mounted in Task 13b below if APPLE_SERVICES_ID is configured */}
            <div id="appleid-signin" data-color="white" data-border="true" data-type="sign-in" className="w-full" />
            <p className="text-[10px] text-zinc-600 text-center pt-2">
              We only use your email to keep track of your 3 free verifications.
            </p>
          </div>
        )}

        {phase === "email-input" && (
          <form onSubmit={onRequestCode} className="space-y-3">
            <label htmlFor="signin-email-input-field" className="block text-xs text-zinc-500 uppercase tracking-widest">Email</label>
            <input
              id="signin-email-input-field"
              type="email"
              required
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="w-full bg-zinc-900 border border-zinc-700 rounded px-3 py-2 focus:border-green-500 outline-none"
              data-testid="signin-email-input"
            />
            {/* Turnstile widget placeholder — wire up @marsidev/react-turnstile or a script tag if VITE_TURNSTILE_SITE_KEY is configured */}
            <button
              type="submit"
              disabled={sending}
              className="w-full border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-4 py-3 disabled:opacity-50"
              data-testid="signin-email-submit"
            >
              {sending ? "Sending..." : "Send code"}
            </button>
          </form>
        )}

        {phase === "code-input" && (
          <form onSubmit={onVerifyCode} className="space-y-3">
            <p className="text-xs text-zinc-400">Check your email for a 6-digit code.</p>
            <input
              type="text"
              inputMode="numeric"
              pattern="\d{6}"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value.replace(/\D/g, "").slice(0, 6))}
              className="w-full bg-zinc-900 border border-zinc-700 rounded px-3 py-2 text-center tracking-[0.5em] focus:border-green-500 outline-none"
              data-testid="signin-code-input"
            />
            <button
              type="submit"
              disabled={sending || code.length !== 6}
              className="w-full border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-4 py-3 disabled:opacity-50"
              data-testid="signin-code-submit"
            >
              {sending ? "Verifying..." : "Verify"}
            </button>
          </form>
        )}

        <div role="alert" aria-live="polite" className="text-xs text-red-500 text-center min-h-[1rem]">
          {error ?? ""}
        </div>
      </div>
    </div>
  );
}
