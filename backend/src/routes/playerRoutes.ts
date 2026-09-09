import express, { Router } from "express";
import {
  getMyProfile,
  getPlayer,
  listPlayers,
  updateMyPlayStatus,
  updateMyPlayStatusSchema,
  updateMyProfile,
  updatePlayer,
  updatePlayerSchema,
  uploadMyProfileImage,
  uploadPlayerProfileImage
} from "../controllers/playerController";
import { authenticate, authorize } from "../middleware/auth";
import { validate } from "../middleware/validate";

export const playerRoutes = Router();

playerRoutes.use(authenticate);

playerRoutes.get("/me", getMyProfile);
// authenticate records server-side activity before returning the current profile.
playerRoutes.post("/me/activity", getMyProfile);
playerRoutes.patch("/me", validate(updatePlayerSchema), updateMyProfile);
playerRoutes.patch("/me/play-status", validate(updateMyPlayStatusSchema), updateMyPlayStatus);
playerRoutes.post(
  "/me/profile-image",
  express.raw({ type: "multipart/form-data", limit: "6mb" }),
  uploadMyProfileImage
);
playerRoutes.get("/", listPlayers);
playerRoutes.get("/:id", getPlayer);
playerRoutes.patch("/:id", authorize("admin"), validate(updatePlayerSchema), updatePlayer);
playerRoutes.post(
  "/:id/profile-image",
  authorize("admin"),
  express.raw({ type: "multipart/form-data", limit: "6mb" }),
  uploadPlayerProfileImage
);
