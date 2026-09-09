import { z } from "zod";
import { asyncHandler } from "../middleware/asyncHandler";
import { getLeagueSettings, updateLeagueSettings } from "../services/settingsService";
import { expireInactivePlayers } from "../services/activityService";

export const updateSettingsSchema = z.object({
  resultEntryDelayMinutes: z.number().int().min(0).optional(),
  matchWinPoints: z.number().int().min(0).optional(),
  tournamentWinPoints: z.number().int().min(0).optional(),
  inactivityDays: z.number().int().min(0).max(365).optional()
});

export const getSettings = asyncHandler(async (_req, res) => {
  const settings = await getLeagueSettings();
  res.json({ settings });
});

export const updateSettings = asyncHandler(async (req, res) => {
  const settings = await updateLeagueSettings(req.body);
  if (req.body.inactivityDays !== undefined) await expireInactivePlayers();
  res.json({ settings });
});
