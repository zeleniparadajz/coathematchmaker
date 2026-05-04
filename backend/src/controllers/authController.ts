import { z } from "zod";
import { env } from "../config/env";
import { Player } from "../models/Player";
import { AppError } from "../middleware/errorHandler";
import { signAuthToken } from "../services/tokenService";
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

const emailFailureMessage = (error: unknown): string => {
  const details = error instanceof Error ? error.message : String(error);
  const suffix = env.nodeEnv === "production" ? "" : ` Detalji: ${details}`;

  return `Nalog nije kreiran jer verification email nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.${suffix}`;
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

  res.status(201).json({ token, player, emailVerificationRequired });
});

export const login = asyncHandler(async (req, res) => {
  const player = await Player.findOne({ email: req.body.email }).select("+password");

  if (!player || !(await player.comparePassword(req.body.password))) {
    throw new AppError(401, "Invalid email or password");
  }

  if (!player.active) {
    throw new AppError(403, "Player account is inactive");
  }

  if (env.requireEmailVerification && !player.emailVerified) {
    throw new AppError(403, "Potvrdi email prije prijave");
  }

  const token = signAuthToken(player);

  res.json({ token, player });
});

export const verifyEmail = asyncHandler(async (req, res) => {
  const token = typeof req.query.token === "string" ? req.query.token : undefined;

  if (!token) {
    throw new AppError(400, "Verification token is required");
  }

  const player = await Player.findOne({
    emailVerificationToken: hashEmailVerificationToken(token),
    emailVerificationExpires: { $gt: new Date() }
  }).select("+emailVerificationToken +emailVerificationExpires");

  if (!player) {
    throw new AppError(400, "Verification token is invalid or expired");
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
    throw new AppError(404, "Player not found");
  }

  if (player.emailVerified) {
    return res.json({ message: "Email is already verified" });
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
      "Verification email nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen."
    );
  }

  res.json({ message: "Verification email sent" });
});

export const me = asyncHandler(async (req, res) => {
  const player = await Player.findById(req.user!.id);

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});
