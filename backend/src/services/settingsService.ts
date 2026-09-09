import { LeagueSettings } from "../models/LeagueSettings";

export const getLeagueSettings = async () => {
  let settings = await LeagueSettings.findOne();

  if (!settings) {
    settings = await LeagueSettings.create({});
  }

  return settings;
};

export const updateLeagueSettings = async (payload: Partial<{
  resultEntryDelayMinutes: number;
  matchWinPoints: number;
  tournamentWinPoints: number;
  inactivityDays: number;
}>) => {
  const settings = await getLeagueSettings();
  Object.assign(settings, payload);
  await settings.save();
  return settings;
};
