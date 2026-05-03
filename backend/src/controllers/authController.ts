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
  adminCode: z.string().optional()
});

export const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1)
});

export const resendVerificationSchema = z.object({
  email: z.string().email()
});

export const register = asyncHandler(async (req, res) => {
  const role = req.body.adminCode && req.body.adminCode === env.adminRegistrationCode ? "admin" : "player";
  const birthDate = req.body.birthDate ?? new Date(`${req.body.birthYear}-01-01`);
  const verification = createEmailVerificationToken();

  const player = await Player.create({
    firstName: req.body.firstName,
    lastName: req.body.lastName,
    email: req.body.email,
    password: req.body.password,
    birthDate,
    country: req.body.country,
    club: req.body.club,
    emailVerified: role === "admin",
    emailVerificationToken: role === "admin" ? undefined : verification.hashedToken,
    emailVerificationExpires: role === "admin" ? undefined : verification.expiresAt,
    role
  });

  if (!player.emailVerified) {
    await sendPlayerVerificationEmail(player, verification.rawToken);
  }

  const token = signAuthToken(player);

  res.status(201).json({ token, player, emailVerificationRequired: !player.emailVerified });
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
    throw new AppError(403, "Please verify your email before logging in");
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
  await sendPlayerVerificationEmail(player, verification.rawToken);

  res.json({ message: "Verification email sent" });
});

export const me = asyncHandler(async (req, res) => {
  const player = await Player.findById(req.user!.id);

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});
