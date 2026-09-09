import { z } from "zod";
import { env } from "../config/env";
import { Player } from "../models/Player";
import { AppError } from "../middleware/errorHandler";
import { signAuthToken } from "../services/tokenService";
import { sendPasswordResetEmail } from "../services/emailService";
import { asyncHandler } from "../middleware/asyncHandler";
import {
  createEmailVerificationToken,
  hashEmailVerificationToken,
  sendPlayerVerificationEmail
} from "../services/emailVerificationService";

export const registerSchema = z.object({
  firstName: z.string().min(1),
  lastName: z.string().min(1),
  email: z.string().email(),
  password: z.string().min(8),
  birthDate: z.coerce.date().optional(),
  birthYear: z.number().int().min(1900).max(new Date().getFullYear()).optional(),
  country: z.string().min(1),
  club: z.string().optional(),
  sport: z.string().min(1).default("tennis"),
  adminCode: z.string().optional()
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export const resendVerificationSchema = z.object({
  email: z.string().email()
});

export const forgotPasswordSchema = z.object({
  email: z.string().email()
});

export const resetPasswordSchema = z.object({
  token: z.string().min(1),
  password: z.string().min(8)
});

const emailFailureMessage = (error: unknown): string => {
  const details = error instanceof Error ? error.message : String(error);
  const suffix = env.nodeEnv === "production" ? "" : ` Detalji: ${details}`;

  return `Nalog nije kreiran jer email za potvrdu nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.${suffix}`;
};

export const register = asyncHandler(async (req, res) => {
  const role = req.body.adminCode && req.body.adminCode === env.adminRegistrationCode ? "admin" : "player";
  const birthDate = req.body.birthDate ?? new Date(`${req.body.birthYear}-01-01`);
  const verification = createEmailVerificationToken();
  const emailVerified = role === "admin" || !env.requireEmailVerification;

  const player = await Player.create({
    firstName: req.body.firstName,
    lastName: req.body.lastName,
    email: req.body.email,
    password: req.body.password,
    birthDate,
    country: req.body.country,
    club: req.body.club,
    sport: req.body.sport,
    emailVerified,
    emailVerificationToken: emailVerified ? undefined : verification.hashedToken,
    emailVerificationExpires: emailVerified ? undefined : verification.expiresAt,
    role
  });

  if (!player.emailVerified) {
    try {
      await sendPlayerVerificationEmail(player, verification.rawToken);
    } catch (error) {
      await Player.findByIdAndDelete(player.id);
      console.error("Email verification send failed", error);
      throw new AppError(502, emailFailureMessage(error));
    }
  }

  const emailVerificationRequired = env.requireEmailVerification && !player.emailVerified;
  const token = emailVerificationRequired ? undefined : signAuthToken(player);
  if (token) {
    player.lastActiveAt = new Date();
    await player.save();
  }

  res.status(201).json({ token, player, emailVerificationRequired });
});

export const login = asyncHandler(async (req, res) => {
  const player = await Player.findOne({ email: req.body.email }).select("+password");

  if (!player || !(await player.comparePassword(req.body.password))) {
    throw new AppError(401, "Email adresa ili lozinka nisu ispravne.");
  }

  if (!player.active) {
    throw new AppError(403, "Korisnički nalog nije aktivan.");
  }

  if (env.requireEmailVerification && !player.emailVerified) {
    throw new AppError(403, "Potvrdi email prije prijave");
  }

  const current = await Player.findOneAndUpdate({ _id: player._id, active: true },
    { $max: { lastActiveAt: new Date() } }, { new: true, timestamps: false });
  if (!current) throw new AppError(403, "Korisnički nalog nije aktivan.");
  const token = signAuthToken(current);

  res.json({ token, player: current });
});

export const verifyEmail = asyncHandler(async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : undefined;

  if (!token) {
    throw new AppError(400, "Nedostaje kod za potvrdu email adrese.");
  }

  const player = await Player.findOne({
    emailVerificationToken: hashEmailVerificationToken(token),
    emailVerificationExpires: { $gt: new Date() }
  }).select("+emailVerificationToken +emailVerificationExpires");

  if (!player) {
    throw new AppError(400, "Link za potvrdu email adrese je nevažeći ili je istekao.");
  }

  player.emailVerified = true;
  player.emailVerificationToken = undefined;
  player.emailVerificationExpires = undefined;
  await player.save();

  res.send("Email potvrđen. Možeš se vratiti u aplikaciju i prijaviti.");
});

export const resendVerification = asyncHandler(async (req, res) => {
  const player = await Player.findOne({ email: req.body.email }).select("+emailVerificationToken +emailVerificationExpires");

  if (!player) {
    throw new AppError(404, "Igrač nije pronađen.");
  }

  if (player.emailVerified) {
    return res.json({ message: "Email adresa je već potvrđena." });
  }

  const verification = createEmailVerificationToken();
  player.emailVerificationToken = verification.hashedToken;
  player.emailVerificationExpires = verification.expiresAt;
  await player.save();
  try {
    await sendPlayerVerificationEmail(player, verification.rawToken);
  } catch (error) {
    console.error("Email verification resend failed", error);
    throw new AppError(
      502,
      "Email za potvrdu nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen."
    );
  }

  res.json({ message: "Email za potvrdu je poslat." });
});

export const forgotPassword = asyncHandler(async (req, res) => {
  const player = await Player.findOne({ email: req.body.email }).select(
    "+passwordResetToken +passwordResetExpires"
  );

  if (!player) {
    return res.json({
      message: "Ako nalog postoji, poslali smo email za promjenu lozinke."
    });
  }

  const reset = createEmailVerificationToken();
  const resetUrl = `${env.appUrl}/api/auth/reset-password?token=${reset.rawToken}`;

  player.passwordResetToken = reset.hashedToken;
  player.passwordResetExpires = new Date(Date.now() + 30 * 60 * 1000);
  await player.save();

  try {
    await sendPasswordResetEmail({
      to: player.email,
      name: player.firstName,
      resetUrl
    });
  } catch (error) {
    player.passwordResetToken = undefined;
    player.passwordResetExpires = undefined;
    await player.save();
    console.error("Password reset email failed", error);
    throw new AppError(
      502,
      "Email za promjenu lozinke nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen."
    );
  }

  res.json({ message: "Ako nalog postoji, poslali smo email za promjenu lozinke." });
});

export const resetPassword = asyncHandler(async (req, res) => {
  const player = await Player.findOne({
    passwordResetToken: hashEmailVerificationToken(req.body.token),
    passwordResetExpires: { $gt: new Date() }
  }).select("+password +passwordResetToken +passwordResetExpires");

  if (!player) {
    throw new AppError(400, "Link za promjenu lozinke je nevažeći ili je istekao.");
  }

  player.password = req.body.password;
  player.passwordResetToken = undefined;
  player.passwordResetExpires = undefined;
  await player.save();

  res.json({ message: "Lozinka je promijenjena. Možeš se prijaviti." });
});

export const resetPasswordPage = asyncHandler(async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : "";

  if (!token) {
    throw new AppError(400, "Nedostaje kod za promjenu lozinke.");
  }

  res.type("html").send(`
    <!doctype html>
    <html lang="sr">
      <head>
        <meta charset="utf-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
        <title>Promjena lozinke</title>
        <style>
          body{margin:0;font-family:Arial,sans-serif;background:#f5f8ef;color:#17211c;display:grid;min-height:100vh;place-items:center;padding:20px}
          main{width:min(420px,100%);background:white;border-radius:24px;padding:28px;box-shadow:0 20px 60px rgba(23,33,28,.12)}
          h1{margin:0 0 8px;font-size:28px}
          p{color:#657166;line-height:1.45}
          label{display:block;font-weight:700;margin:18px 0 8px}
          input{box-sizing:border-box;width:100%;border:1px solid #dbe8dc;border-radius:16px;padding:16px;font-size:16px}
          button{width:100%;margin-top:18px;border:0;border-radius:999px;padding:15px 18px;background:#1f8a5b;color:white;font-weight:800;font-size:16px}
          #msg{margin-top:14px;font-weight:700}
        </style>
      </head>
      <body>
        <main>
          <h1>Promjena lozinke</h1>
          <p>Unesi novu lozinku. Mora imati najmanje 8 znakova.</p>
          <form id="form">
            <label for="password">Nova lozinka</label>
            <input id="password" name="password" type="password" minlength="8" required autocomplete="new-password" />
            <button type="submit">Sačuvaj novu lozinku</button>
          </form>
          <p id="msg"></p>
        </main>
        <script>
          const form = document.getElementById('form');
          const msg = document.getElementById('msg');
          form.addEventListener('submit', async (event) => {
            event.preventDefault();
            msg.textContent = 'Šaljem...';
            const response = await fetch('/api/auth/reset-password', {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ token: ${JSON.stringify(token)}, password: form.password.value })
            });
            const data = await response.json().catch(() => ({}));
            msg.textContent = data.message || (response.ok ? 'Lozinka je promijenjena.' : 'Promjena lozinke nije uspjela.');
            msg.style.color = response.ok ? '#1f8a5b' : '#c3422f';
            if (response.ok) form.reset();
          });
        </script>
      </body>
    </html>
  `);
});

export const me = asyncHandler(async (req, res) => {
  const player = await Player.findById(req.user!.id);

  if (!player) {
    throw new AppError(404, "Igrač nije pronađen.");
  }

  res.json({ player });
});

export const deleteMe = asyncHandler(async (req, res) => {
  const player = await Player.findById(req.user!.id).select(
    "+password +emailVerificationToken +emailVerificationExpires +passwordResetToken +passwordResetExpires +activityTrackingStartedAt"
  );

  if (!player) {
    throw new AppError(404, "Igrač nije pronađen.");
  }

  const deletedAt = Date.now();
  player.firstName = "Deleted";
  player.lastName = "Account";
  player.email = `deleted-${player.id}-${deletedAt}@deleted.coathematchmaker.local`;
  player.password = `deleted-${player.id}-${deletedAt}`;
  player.birthDate = new Date("1970-01-01");
  player.country = "Deleted";
  player.club = undefined;
  player.profileImage = undefined;
  player.emailVerified = false;
  player.emailVerificationToken = undefined;
  player.emailVerificationExpires = undefined;
  player.passwordResetToken = undefined;
  player.passwordResetExpires = undefined;
  player.active = false;
  player.playStatus = "unavailable";
  player.playStatusUpdatedAt = new Date();
  player.playStatusSource = "manual";
  player.lastActiveAt = undefined;
  player.activityTrackingStartedAt = undefined;
  await player.save();

  res.json({
    message: "Nalog je obrisan. Lični podaci su uklonjeni i nalog više nije moguće koristiti."
  });
});
