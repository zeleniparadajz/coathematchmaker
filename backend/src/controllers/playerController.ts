import { z } from "zod";
import { Player } from "../models/Player";
import { AppError } from "../middleware/errorHandler";
import { asyncHandler } from "../middleware/asyncHandler";
import { saveProfileImage } from "../services/uploadService";

export const updatePlayerSchema = z.object({
  firstName: z.string().min(1).optional(),
  lastName: z.string().min(1).optional(),
  birthDate: z.coerce.date().optional(),
  birthYear: z.number().int().min(1900).max(new Date().getFullYear()).optional(),
  country: z.string().min(1).optional(),
  club: z.string().optional(),
  city: z.string().trim().max(100).optional(),
  sport: z.string().min(1).optional(),
  profileImage: z.string().url().optional(),
  active: z.boolean().optional(),
  playStatus: z.enum(["available", "unavailable"]).optional(),
  role: z.enum(["player", "admin"]).optional()
});

export const updateMyPlayStatusSchema = z.object({
  playStatus: z.enum(["available", "unavailable"])
});

export const listPlayers = asyncHandler(async (req, res) => {
  const active = req.query.active;
  const filter = typeof active === "string" ? { active: active === "true" } : {};
  const players = await Player.find(filter).select("-password").sort({ totalPoints: -1, wins: -1 });

  res.json({ players });
});

export const getPlayer = asyncHandler(async (req, res) => {
  const player = await Player.findById(req.params.id).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});

export const updatePlayer = asyncHandler(async (req, res) => {
  const player = await Player.findByIdAndUpdate(req.params.id, req.body, {
    new: true,
    runValidators: true
  }).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});

export const getMyProfile = asyncHandler(async (req, res) => {
  const player = await Player.findById(req.user!.id).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});

export const updateMyProfile = asyncHandler(async (req, res) => {
  const allowedFields = {
    firstName: req.body.firstName,
    lastName: req.body.lastName,
    birthDate: req.body.birthDate ?? (req.body.birthYear ? new Date(`${req.body.birthYear}-01-01`) : undefined),
    country: req.body.country,
    club: req.body.club,
    city: req.body.city,
    sport: req.body.sport
  };

  const player = await Player.findByIdAndUpdate(req.user!.id, allowedFields, {
    new: true,
    runValidators: true
  }).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});

export const updateMyPlayStatus = asyncHandler(async (req, res) => {
  const player = await Player.findByIdAndUpdate(
    req.user!.id,
    {
      playStatus: req.body.playStatus,
      playStatusUpdatedAt: new Date()
    },
    { new: true, runValidators: true }
  ).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ player });
});

export const uploadMyProfileImage = asyncHandler(async (req, res) => {
  const profileImage = await saveProfileImage(req.body as Buffer, req.headers["content-type"]);
  const player = await Player.findByIdAndUpdate(
    req.user!.id,
    { profileImage },
    { new: true, runValidators: true }
  ).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ profileImage, player });
});

export const uploadPlayerProfileImage = asyncHandler(async (req, res) => {
  const profileImage = await saveProfileImage(req.body as Buffer, req.headers["content-type"]);
  const player = await Player.findByIdAndUpdate(
    req.params.id,
    { profileImage },
    { new: true, runValidators: true }
  ).select("-password");

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  res.json({ profileImage, player });
});
