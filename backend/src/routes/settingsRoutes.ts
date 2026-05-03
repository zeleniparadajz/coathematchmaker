import { Router } from "express";
import { getSettings, updateSettings, updateSettingsSchema } from "../controllers/settingsController";
import { authenticate, authorize } from "../middleware/auth";
import { validate } from "../middleware/validate";

export const settingsRoutes = Router();

settingsRoutes.use(authenticate);
settingsRoutes.get("/", getSettings);
settingsRoutes.patch("/", authorize("admin"), validate(updateSettingsSchema), updateSettings);
