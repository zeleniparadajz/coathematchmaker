import { Router } from "express";
import { env } from "../config/env";
import { appVersionPolicy } from "../services/appVersionService";

export const appConfigRoutes = Router();

appConfigRoutes.get("/", (req, res) => {
  const currentBuild = Number(req.query.build ?? 0);
  if (!Number.isSafeInteger(currentBuild) || currentBuild < 0 ||
      (req.query.build !== undefined && (typeof req.query.build !== "string" || !/^\d+$/.test(req.query.build)))) {
    res.status(400).json({ message: "build must be a non-negative integer" });
    return;
  }
  res.setHeader("Cache-Control", "no-store");
  res.json(appVersionPolicy(req.query.platform, currentBuild, env));
});
