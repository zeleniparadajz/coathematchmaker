export type AppPlatform = "android" | "ios" | "default";

export interface AppVersionSettings {
  minSupportedBuild: number;
  latestBuild: number;
  iosMinSupportedBuild: number;
  iosLatestBuild: number;
  androidMinSupportedBuild: number;
  androidLatestBuild: number;
  appStoreUrl: string;
  playStoreUrl: string;
  appUpdateMessage: string;
  appUpdateMessageEn?: string;
}

export const appVersionPolicy = (platformValue: unknown, currentBuild: number, settings: AppVersionSettings) => {
  const name = typeof platformValue === "string" ? platformValue.toLowerCase() : "";
  const platform: AppPlatform = name === "ios" || name === "android" ? name : "default";
  const minSupportedBuild = platform === "ios" ? settings.iosMinSupportedBuild
    : platform === "android" ? settings.androidMinSupportedBuild : settings.minSupportedBuild;
  const latest = platform === "ios" ? settings.iosLatestBuild
    : platform === "android" ? settings.androidLatestBuild : settings.latestBuild;
  const latestBuild = Math.max(minSupportedBuild, latest);
  const storeUrl = platform === "ios" ? settings.appStoreUrl
    : platform === "android" ? settings.playStoreUrl : settings.playStoreUrl || settings.appStoreUrl;
  return {
    platform, minSupportedBuild, latestBuild,
    updateRequired: currentBuild > 0 && currentBuild < minSupportedBuild,
    updateAvailable: currentBuild > 0 && currentBuild < latestBuild,
    storeUrl,
    // Legacy clients read playStoreUrl on both platforms.
    playStoreUrl: storeUrl,
    appStoreUrl: platform === "ios" ? storeUrl : "",
    message: settings.appUpdateMessage,
    messageEn: settings.appUpdateMessageEn ?? "A new version is required. Please update COA The Matchmaker."
  };
};
