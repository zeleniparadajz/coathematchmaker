import { z } from "zod";
import { competitionHandler } from "../middleware/competitionHandler";
import { deletionPreview, deleteCompetition } from "../services/deletionService";

export const deleteCompetitionSchema = z.object({
  revision: z.string().regex(/^[a-f0-9]{64}$/),
  legacyMatchPoints: z.record(z.string().regex(/^[a-f0-9]{24}$/), z.number().int().min(0).max(1000000)).optional(),
  legacyTournamentAwardApplied: z.boolean().optional(),
  legacyTournamentPoints: z.number().int().min(0).max(1000000).optional()
});

export const previewDeletion = (kind: "match" | "tournament") => competitionHandler(async (req, res) => {
  res.json({ preview: await deletionPreview(kind, String(req.params.id)) });
});

export const deleteEntity = (kind: "match" | "tournament") => competitionHandler(async (req, res) => {
  res.json(await deleteCompetition(kind, String(req.params.id), req.user!.playerId, req.body));
});
