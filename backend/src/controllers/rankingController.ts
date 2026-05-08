import { asyncHandler } from "../middleware/asyncHandler";
import { getGeneralRanking, getTournamentRanking } from "../services/rankingService";
import { AppError } from "../middleware/errorHandler";
import { Tournament } from "../models/Tournament";

export const generalRanking = asyncHandler(async (_req, res) => {
  const rankings = await getGeneralRanking();
  res.json({ rankings });
});

export const tournamentRanking = asyncHandler(async (req, res) => {
  const tournament = await Tournament.findById(req.params.id);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  const isMember =
    tournament.owner?.toString() === req.user!.id ||
    tournament.admins.some((adminId) => adminId.toString() === req.user!.id) ||
    tournament.participants.some((participantId) => participantId.toString() === req.user!.id);

  if (req.user!.role !== "admin" && tournament.visibility === "private" && !isMember) {
    throw new AppError(404, "Tournament not found");
  }

  const rankings = await getTournamentRanking(String(req.params.id));
  res.json({ rankings });
});
