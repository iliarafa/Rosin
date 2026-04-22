import { randomInt, createHash } from "crypto";
import { Resend } from "resend";

export const EMAIL_CODE_TTL_MS = 10 * 60 * 1000; // 10 minutes
export const EMAIL_CODE_MAX_ATTEMPTS = 5;

export function generateEmailCode(): string {
  return String(randomInt(0, 1_000_000)).padStart(6, "0");
}

export function hashEmailCode(code: string, email: string): string {
  return createHash("sha256").update(`${normalizeEmail(email)}:${code}`).digest("hex");
}

export function normalizeEmail(email: string): string {
  return email.trim().toLowerCase();
}

let resendClient: Resend | null = null;
function getResend(): Resend {
  if (!resendClient) {
    if (!process.env.RESEND_API_KEY) throw new Error("RESEND_API_KEY not set");
    resendClient = new Resend(process.env.RESEND_API_KEY);
  }
  return resendClient;
}

export async function sendEmailCode(email: string, code: string): Promise<void> {
  const from = process.env.RESEND_FROM_EMAIL || "login@rosin.app";
  await getResend().emails.send({
    from,
    to: email,
    subject: `Rosin sign-in code: ${code}`,
    text:
      `Your Rosin sign-in code is: ${code}\n\n` +
      `This code expires in 10 minutes. If you didn't request it, ignore this email.`,
  });
}
