import crypto from "crypto";
import { env } from "../config/env";
import type { PlayerDocument } from "../models/Player";
import { sendVerificationEmail } from "./emailService";

export const createEmailVerificationToken = (): { rawToken: string; hashedToken: string; expiresAt: Date } => {
  const rawToken = crypto.randomBytes(32).toString("hex");
  const hashedToken = crypto.createHash("sha256").update(rawToken).digest("hex");
  const expiresAt = new Date(Date.now() + 24 * 60 * 60 * 1000);

  return { rawToken, hashedToken, expiresAt };
};

export const hashEmailVerificationToken = (token: string): string => {
  return crypto.createHash("sha256").update(token).digest("hex");
};

export const sendPlayerVerificationEmail = async (player: PlayerDocument, rawToken: string): Promise<void> => {
  const verificationUrl = `${env.appUrl}/api/auth/verify-email?token=${rawToken}`;

  await sendVerificationEmail({
    to: player.email,
    name: player.firstName,
    verificationUrl
  });
};
