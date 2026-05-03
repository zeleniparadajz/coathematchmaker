import { env } from "../config/env";

interface SendVerificationEmailParams {
  to: string;
  name: string;
  verificationUrl: string;
}

export const sendVerificationEmail = async ({ to, name, verificationUrl }: SendVerificationEmailParams): Promise<void> => {
  if (!env.resendApiKey) {
    console.log(`Email verification link for ${to}: ${verificationUrl}`);
    return;
  }

  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${env.resendApiKey}`,
      "Content-Type": "application/json"
    },
    body: JSON.stringify({
      from: env.emailFrom,
      to,
      subject: "Potvrdi Coa The Matchmaker nalog",
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.5;color:#17211c">
          <h2>Zdravo ${name},</h2>
          <p>Potvrdi email adresu da aktiviraš nalog.</p>
          <p><a href="${verificationUrl}" style="background:#1f8a5b;color:white;padding:12px 18px;border-radius:8px;text-decoration:none">Potvrdi email</a></p>
          <p>Ako dugme ne radi, otvori ovaj link:</p>
          <p>${verificationUrl}</p>
        </div>
      `
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to send verification email: ${text}`);
  }
};
