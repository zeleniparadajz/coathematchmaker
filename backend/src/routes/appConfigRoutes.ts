import { Router } from "express";
import { env } from "../config/env";

export const appConfigRoutes = Router();

appConfigRoutes.get("/", (req, res) => {
  const currentBuild = Number(req.query.build ?? 0);

  res.json({
    minSupportedBuild: env.minSupportedBuild,
    latestBuild: env.latestBuild,
    updateRequired: currentBuild > 0 && currentBuild < env.minSupportedBuild,
    playStoreUrl: env.playStoreUrl,
    message: env.appUpdateMessage
  });
});
