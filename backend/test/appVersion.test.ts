import assert from "node:assert/strict";
import { test } from "node:test";
import { appVersionPolicy, AppVersionSettings } from "../src/services/appVersionService";

const settings: AppVersionSettings = {
  minSupportedBuild: 2, latestBuild: 5,
  iosMinSupportedBuild: 6, iosLatestBuild: 7,
  androidMinSupportedBuild: 8, androidLatestBuild: 9,
  appStoreUrl: "https://apps.apple.com/app/id123",
  playStoreUrl: "https://play.google.com/store/apps/details?id=me.coathematchmaker.app",
  appUpdateMessage: "Ažuriraj aplikaciju."
};

test("iOS and Android have independent thresholds and store links", () => {
  const ios = appVersionPolicy("ios", 6, settings);
  const android = appVersionPolicy("android", 6, settings);
  assert.equal(ios.updateRequired, false);
  assert.equal(ios.updateAvailable, true);
  assert.equal(android.updateRequired, true);
  assert.equal(ios.storeUrl, settings.appStoreUrl);
  assert.equal(android.storeUrl, settings.playStoreUrl);
});

test("the minimum boundary is inclusive and latest cannot fall below it", () => {
  assert.equal(appVersionPolicy("android", 8, settings).updateRequired, false);
  assert.equal(appVersionPolicy("android", 9, settings).updateAvailable, false);
  assert.equal(appVersionPolicy("android", 10, settings).updateAvailable, false);
  assert.equal(appVersionPolicy("ios", 6, {...settings, iosLatestBuild: 3}).latestBuild, 6);
});

test("old clients retain the legacy fallback and response field", () => {
  assert.equal(appVersionPolicy(undefined, 1, settings).minSupportedBuild, 2);
  assert.equal(appVersionPolicy("IOS", 6, settings).playStoreUrl, settings.appStoreUrl);
  assert.equal(appVersionPolicy(undefined, 0, settings).updateRequired, false);
});
