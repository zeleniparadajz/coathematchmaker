import type { Types } from "mongoose";
import { Player } from "../models/Player";
import { getLeagueSettings } from "./settingsService";

export const activityWriteIntervalMs = 60_000;
export const inactivitySweepIntervalMs = 5 * 60_000;
const dayMs = 24 * 60 * 60_000;

export async function recordPlayerActivity(playerId: string | Types.ObjectId, now = new Date()) {
  // Conditional writes cap database traffic and never move a newer timestamp back.
  await Player.updateOne({
    _id: playerId,
    active: true,
    $or: [{ lastActiveAt: null }, { lastActiveAt: { $lte: new Date(now.getTime() - activityWriteIntervalMs) } }]
  }, { $max: { lastActiveAt: now } }, { timestamps: false });
}

export async function initializeActivityTracking(now = new Date()) {
  // A grace-period baseline is not presented as a fabricated last visit.
  await Player.updateMany({ active: true, activityTrackingStartedAt: null },
    { $set: { activityTrackingStartedAt: now } }, { timestamps: false });
}

export async function expireInactivePlayers(now = new Date(), playerIds?: string[]) {
  const settings = await getLeagueSettings();
  const days = settings.inactivityDays ?? 0;
  if (!Number.isInteger(days) || days < 1 || days > 365) return 0;
  const cutoff = new Date(now.getTime() - days * dayMs);
  const result = await Player.updateMany({
    active: true,
    playStatus: "available",
    ...(playerIds ? { _id: { $in: playerIds } } : {}),
    $or: [
      { lastActiveAt: { $lte: cutoff } },
      { lastActiveAt: null, activityTrackingStartedAt: { $lte: cutoff } }
    ]
  }, { $set: { playStatus: "unavailable", playStatusSource: "inactivity", playStatusUpdatedAt: now } });
  return result.modifiedCount;
}

export async function startActivityMaintenance(intervalMs = inactivitySweepIntervalMs) {
  await initializeActivityTracking();
  await expireInactivePlayers();
  let running = false;
  const timer = setInterval(async () => {
    if (running) return;
    running = true;
    try {
      await expireInactivePlayers();
    } catch (error) {
      console.error("Inactive player maintenance failed", error);
    } finally {
      running = false;
    }
  }, intervalMs);
  timer.unref();
  return () => clearInterval(timer);
}
