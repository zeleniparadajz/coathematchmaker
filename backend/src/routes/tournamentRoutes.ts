import { Router } from "express";
import express from "express";
import {
  addParticipant,
  addParticipantSchema,
  advanceRound,
  createTournamentMatch,
  createTournamentMatchSchema,
  createTournament,
  createTournamentSchema,
  finishTournament,
  finishTournamentSchema,
  generateDraw,
  getTournament,
  listTournaments,
  removeParticipant,
  registerForTournament,
  updateTournament,
  updateTournamentSchema,
  uploadTournamentImage
} from "../controllers/tournamentController";
import { tournamentRanking } from "../controllers/rankingController";
import { authenticate, authorize } from "../middleware/auth";
import { validate } from "../middleware/validate";

export const tournamentRoutes = Router();

tournamentRoutes.use(authenticate);

tournamentRoutes.get("/", listTournaments);
tournamentRoutes.post("/", authorize("admin"), validate(createTournamentSchema), createTournament);
tournamentRoutes.get("/:id", getTournament);
tournamentRoutes.patch("/:id", authorize("admin"), validate(updateTournamentSchema), updateTournament);
tournamentRoutes.post("/:id/register", registerForTournament);
tournamentRoutes.post("/:id/participants", authorize("admin"), validate(addParticipantSchema), addParticipant);
tournamentRoutes.delete("/:id/participants/:playerId", authorize("admin"), removeParticipant);
tournamentRoutes.post("/:id/matches", authorize("admin"), validate(createTournamentMatchSchema), createTournamentMatch);
tournamentRoutes.post("/:id/generate-draw", authorize("admin"), generateDraw);
tournamentRoutes.post("/:id/advance-round", authorize("admin"), advanceRound);
tournamentRoutes.post("/:id/finish", authorize("admin"), validate(finishTournamentSchema), finishTournament);
tournamentRoutes.post("/:id/images", express.raw({ type: "multipart/form-data", limit: "9mb" }), uploadTournamentImage);
tournamentRoutes.get("/:id/rankings", tournamentRanking);
