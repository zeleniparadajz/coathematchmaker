import { z } from "zod";
import { asyncHandler } from "../middleware/asyncHandler";
import { getLeagueSettings, updateLeagueSettings } from "../services/settingsService";

export const updateSettingsSchema = z.object({
  resultEntryDelayMinutes: z.number().int().min(0).optional(),
  matchWinPoints: z.number().int().min(0).optional(),
  tournamentWinPoints: z.number().int().min(0).optional()
});

export const getSettings = asyncHandler(async (_req, res) => {
  const settings = await getLeagueSettings();
  res.json({ settings });
});

export const updateSettings = asyncHandler(async (req, res) => {
  const settings = await updateLeagueSettings(req.body);
  res.json({ settings });
});
