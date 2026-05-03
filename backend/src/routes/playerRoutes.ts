import express, { Router } from "express";
import {
  getMyProfile,
  getPlayer,
  listPlayers,
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
playerRoutes.patch("/me", validate(updatePlayerSchema), updateMyProfile);
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
