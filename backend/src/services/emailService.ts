import { env } from "../config/env";

interface SendVerificationEmailParams {
  to: string;
  name: string;
  verificationUrl: string;
}

interface SendPasswordResetEmailParams {
  to: string;
  name: string;
  resetUrl: string;
}

const sendEmail = async ({
  to,
  subject,
  html
}: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> => {
  if (!env.resendApiKey) {
    console.log(`${subject} for ${to}: ${html}`);
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
      subject,
      html
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Failed to send email: ${text}`);
  }
};

export const sendVerificationEmail = async ({ to, name, verificationUrl }: SendVerificationEmailParams): Promise<void> => {
  await sendEmail({
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
  });
};

export const sendPasswordResetEmail = async ({ to, name, resetUrl }: SendPasswordResetEmailParams): Promise<void> => {
  await sendEmail({
    to,
    subject: "Promjena lozinke za COA The Matchmaker",
    html: `
        <div style="font-family:Arial,sans-serif;line-height:1.5;color:#17211c">
          <h2>Zdravo ${name},</h2>
          <p>Dobili smo zahtjev za promjenu lozinke. Link važi 30 minuta.</p>
          <p><a href="${resetUrl}" style="background:#1f8a5b;color:white;padding:12px 18px;border-radius:8px;text-decoration:none">Promijeni lozinku</a></p>
          <p>Ako nisi tražio promjenu lozinke, zanemari ovu poruku.</p>
          <p>Ako dugme ne radi, otvori ovaj link:</p>
          <p>${resetUrl}</p>
        </div>
      `
  });
};
