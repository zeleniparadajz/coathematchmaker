import { Router } from "express";
import express from "express";
import {
  addParticipant,
  addParticipantSchema,
  addTournamentAdmin,
  addTournamentAdminSchema,
  advanceRound,
  createTournamentMatch,
  createTournamentMatchSchema,
  createTournament,
  createTournamentSchema,
  finishTournament,
  finishTournamentSchema,
  generateDraw,
  getTournament,
  getRoundRobin,
  startKnockout,
  startKnockoutSchema,
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
import { deleteCompetitionSchema, deleteEntity, previewDeletion } from "../controllers/deletionController";

export const tournamentRoutes = Router();

tournamentRoutes.use(authenticate);

tournamentRoutes.get("/", listTournaments);
tournamentRoutes.post("/", validate(createTournamentSchema), createTournament);
tournamentRoutes.get("/:id", getTournament);
tournamentRoutes.get("/:id/deletion-preview", authorize("admin"), previewDeletion("tournament"));
tournamentRoutes.delete("/:id", authorize("admin"), validate(deleteCompetitionSchema), deleteEntity("tournament"));
tournamentRoutes.patch("/:id", validate(updateTournamentSchema), updateTournament);
tournamentRoutes.post("/:id/register", registerForTournament);
tournamentRoutes.post("/:id/participants", validate(addParticipantSchema), addParticipant);
tournamentRoutes.delete("/:id/participants/:playerId", removeParticipant);
tournamentRoutes.post("/:id/admins", validate(addTournamentAdminSchema), addTournamentAdmin);
tournamentRoutes.post("/:id/matches", validate(createTournamentMatchSchema), createTournamentMatch);
tournamentRoutes.post("/:id/generate-draw", generateDraw);
tournamentRoutes.post("/:id/advance-round", advanceRound);
tournamentRoutes.get("/:id/round-robin", getRoundRobin);
tournamentRoutes.post("/:id/start-knockout", validate(startKnockoutSchema), startKnockout);
tournamentRoutes.post("/:id/finish", validate(finishTournamentSchema), finishTournament);
tournamentRoutes.post("/:id/images", express.raw({ type: "multipart/form-data", limit: "9mb" }), uploadTournamentImage);
tournamentRoutes.get("/:id/rankings", tournamentRanking);
