import { Link } from "wouter";

export function AuthGate() {
  return (
    <div className="max-w-md mx-auto text-center mt-16 space-y-4">
      <div className="text-xs text-zinc-500 uppercase tracking-widest">[ SIGN IN REQUIRED ]</div>
      <p className="text-sm text-zinc-300">
        Verifying across multiple AIs uses shared compute. Sign in for 3 free verifications.
      </p>
      <Link
        href="/sign-in"
        className="inline-block border border-green-500 text-green-500 hover:bg-green-500 hover:text-black rounded px-6 py-3 text-sm"
        data-testid="novice-sign-in"
      >
        Sign in to verify
      </Link>
    </div>
  );
}
