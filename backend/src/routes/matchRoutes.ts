import { Router } from "express";
import express from "express";
import {
  acceptMatch,
  adminResolve,
  adminResolveSchema,
  challengeMatchSchema,
  confirmResult,
  createMatch,
  createMatchSchema,
  createChallenge,
  disputeResult,
  getDisputedMatches,
  getMatch,
  getMyMatches,
  getPendingMatches,
  listMatches,
  rejectMatch,
  submitResult,
  submitResultSchema,
  updateMatch,
  updateMatchSchema,
  uploadMatchImage
} from "../controllers/matchController";
import { authenticate, authorize } from "../middleware/auth";
import { validate } from "../middleware/validate";

export const matchRoutes = Router();

matchRoutes.use(authenticate);

matchRoutes.get("/", listMatches);
matchRoutes.get("/my", getMyMatches);
matchRoutes.get("/pending", getPendingMatches);
matchRoutes.get("/disputed", authorize("admin"), getDisputedMatches);
matchRoutes.post("/challenge", validate(challengeMatchSchema), createChallenge);
matchRoutes.get("/:id", getMatch);
matchRoutes.post("/", authorize("admin"), validate(createMatchSchema), createMatch);
matchRoutes.patch("/:id", authorize("admin"), validate(updateMatchSchema), updateMatch);
matchRoutes.post("/:id/accept", acceptMatch);
matchRoutes.post("/:id/reject", rejectMatch);
matchRoutes.post("/:id/submit-result", validate(submitResultSchema), submitResult);
matchRoutes.post("/:id/confirm-result", confirmResult);
matchRoutes.post("/:id/dispute", disputeResult);
matchRoutes.post("/:id/admin-resolve", authorize("admin"), validate(adminResolveSchema), adminResolve);
matchRoutes.post("/:id/images", express.raw({ type: "multipart/form-data", limit: "9mb" }), uploadMatchImage);
