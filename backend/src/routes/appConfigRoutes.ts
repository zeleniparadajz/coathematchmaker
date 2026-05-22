import { Router } from "express";
import { env } from "../config/env";

export const appConfigRoutes = Router();

type AppPlatform = "android" | "ios" | "default";

const normalizePlatform = (value: unknown): AppPlatform => {
  const platform = typeof value === "string" ? value.toLowerCase() : "";

  if (platform === "android") return "android";
  if (platform === "ios") return "ios";

  return "default";
};

const platformConfig = (platform: AppPlatform) => {
  if (platform === "android") {
    return {
      minSupportedBuild: env.androidMinSupportedBuild,
      latestBuild: env.androidLatestBuild,
      storeUrl: env.playStoreUrl
    };
  }

  if (platform === "ios") {
    return {
      minSupportedBuild: env.iosMinSupportedBuild,
      latestBuild: env.iosLatestBuild,
      storeUrl: env.appStoreUrl
    };
  }

  return {
    minSupportedBuild: env.minSupportedBuild,
    latestBuild: env.latestBuild,
    storeUrl: env.playStoreUrl || env.appStoreUrl
  };
};

appConfigRoutes.get("/", (req, res) => {
  const currentBuild = Number(req.query.build ?? 0);
  const platform = normalizePlatform(req.query.platform);
  const config = platformConfig(platform);

  res.json({
    platform,
    minSupportedBuild: config.minSupportedBuild,
    latestBuild: config.latestBuild,
    updateRequired: currentBuild > 0 && currentBuild < config.minSupportedBuild,
    storeUrl: config.storeUrl,
    playStoreUrl: config.storeUrl,
    message: env.appUpdateMessage
  });
});
