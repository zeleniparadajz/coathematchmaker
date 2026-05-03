import { asyncHandler } from "../middleware/asyncHandler";
import { getGeneralRanking, getTournamentRanking } from "../services/rankingService";

export const generalRanking = asyncHandler(async (_req, res) => {
  const rankings = await getGeneralRanking();
  res.json({ rankings });
});

export const tournamentRanking = asyncHandler(async (req, res) => {
  const rankings = await getTournamentRanking(String(req.params.id));
  res.json({ rankings });
});
