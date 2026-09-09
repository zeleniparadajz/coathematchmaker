import assert from "node:assert/strict";
import { test } from "node:test";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";
import { once } from "node:events";
import { setTimeout as delay } from "node:timers/promises";

test("activity, admin inactivity policy, grace period and automatic availability", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const uri = process.env.MONGO_TEST_URI!;
  assert.match(uri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "activity-test-only-secret";
  process.env.REQUIRE_EMAIL_VERIFICATION = "true";
  const database = `coa_activity_test_${process.pid}_${Date.now()}`;
  await mongoose.connect(uri, { dbName: database });
  const { app } = await import("../src/app");
  const { Player } = await import("../src/models/Player");
  const { LeagueSettings } = await import("../src/models/LeagueSettings");
  const { recordPlayerActivity, initializeActivityTracking, expireInactivePlayers, startActivityMaintenance } = await import("../src/services/activityService");
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  let stopMaintenance: (() => void) | undefined;
  try {
    let index = 0;
    const makePlayer = (extra = {}) => Player.create({ firstName: "Activity", lastName: "Test", email: `p${index++}@example.test`,
      password: "test-password", birthDate: new Date("1990-01-01"), country: "ME", sport: "tennis", emailVerified: true, ...extra });
    const admin = await makePlayer({ role: "admin" });
    const member = await makePlayer();
    const old = await makePlayer();
    const legacy = await makePlayer();
    const manual = await makePlayer({ playStatus: "unavailable" });
    const disabled = await makePlayer({ active: false });
    const unverified = await makePlayer({ emailVerified: false });
    const token = (id: unknown) => jwt.sign({ sub: String(id) }, process.env.JWT_SECRET!);
    const adminToken = token(admin._id);
    const memberToken = token(member._id);
    const port = (server.address() as { port: number }).port;
    async function request(path: string, auth = memberToken, method = "GET", body?: unknown) {
      const response = await fetch(`http://127.0.0.1:${port}/api${path}`, {
        method, headers: { "Content-Type": "application/json", ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
        ...(body === undefined ? {} : { body: JSON.stringify(body) })
      });
      return { status: response.status, data: await response.json() };
    }
    assert.equal((await request("/players/me/activity", "", "POST")).status, 401);
    assert.equal((await request("/players/me/activity", token(disabled._id), "POST")).status, 403);
    assert.equal((await request("/players/me/activity", token(unverified._id), "POST")).status, 403);
    assert.equal((await Player.findById(disabled._id))!.lastActiveAt, undefined);
    assert.equal((await Player.findById(unverified._id))!.lastActiveAt, undefined);
    const before = Date.now();
    const activity = await request("/players/me/activity", memberToken, "POST", { lastActiveAt: "2099-01-01", playerId: old.id });
    assert.equal(activity.status, 200);
    assert.ok(new Date(activity.data.player.lastActiveAt).getTime() >= before);
    assert.ok(new Date(activity.data.player.lastActiveAt).getTime() <= Date.now());
    assert.equal((await Player.findById(old._id))!.lastActiveAt, undefined);
    const firstVisit = (await Player.findById(member._id))!.lastActiveAt!;
    await recordPlayerActivity(member._id, new Date(firstVisit.getTime() + 10_000));
    assert.equal((await Player.findById(member._id))!.lastActiveAt!.getTime(), firstVisit.getTime());
    const newer = new Date(firstVisit.getTime() + 120_000);
    await recordPlayerActivity(member._id, newer);
    await recordPlayerActivity(member._id, firstVisit);
    assert.equal((await Player.findById(member._id))!.lastActiveAt!.getTime(), newer.getTime());

    const now = new Date();
    const day = 86_400_000;
    const stale = new Date(now.getTime() - 10 * day);
    await Player.updateMany({ _id: { $in: [old._id, manual._id, disabled._id] } }, { $set: { lastActiveAt: stale } });
    await Player.collection.updateOne({ _id: legacy._id }, { $unset: { lastActiveAt: "", activityTrackingStartedAt: "" },
      $set: { createdAt: new Date("2001-01-01") } });
    await initializeActivityTracking(now);
    await initializeActivityTracking(new Date(now.getTime() + day));
    assert.equal((await Player.findById(legacy._id).select("+activityTrackingStartedAt"))!.activityTrackingStartedAt!.getTime(), now.getTime());
    assert.equal((await Player.findById(legacy._id))!.lastActiveAt, undefined);
    assert.equal((await request("/settings")).data.settings.inactivityDays, 0);
    assert.equal(await expireInactivePlayers(now), 0);
    assert.equal((await request("/settings", memberToken, "PATCH", { inactivityDays: 7 })).status, 403);
    for (const invalid of [-1, 366, 1.5, "7", null]) {
      assert.equal((await request("/settings", adminToken, "PATCH", { inactivityDays: invalid })).status, 400);
    }
    await request(`/players/${old.id}`, adminToken, "PATCH", { city: "Budva", lastActiveAt: "2099-01-01" });
    assert.equal((await Player.findById(old._id))!.lastActiveAt!.getTime(), stale.getTime());
    assert.equal((await request("/settings", adminToken, "PATCH", { inactivityDays: 7 })).status, 200);
    const expired = (await Player.findById(old._id))!;
    assert.equal(expired.playStatus, "unavailable");
    assert.equal(expired.playStatusSource, "inactivity");
    assert.equal(expired.active, true);
    assert.equal(expired.lastActiveAt!.getTime(), stale.getTime());
    assert.equal((await Player.findById(legacy._id))!.playStatus, "available");
    assert.equal((await Player.findById(manual._id))!.playStatusSource, "manual");
    assert.equal((await Player.findById(disabled._id))!.playStatus, "available");
    await request("/settings", adminToken, "PATCH", { matchWinPoints: 15 });
    assert.equal((await LeagueSettings.findOne())!.inactivityDays, 7);

    // Boundary is inclusive, and recent activity wins over the old baseline.
    await Player.updateOne({ _id: old._id }, { $set: { playStatus: "available", lastActiveAt: new Date(now.getTime() - 7 * day + 1) } });
    assert.equal(await expireInactivePlayers(now, [old.id]), 0);
    await Player.updateOne({ _id: old._id }, { $set: { lastActiveAt: new Date(now.getTime() - 7 * day) } });
    assert.equal(await expireInactivePlayers(now, [old.id]), 1);
    assert.equal(await expireInactivePlayers(now, [old.id]), 0);
    assert.equal(await expireInactivePlayers(new Date(now.getTime() + 7 * day), [legacy.id]), 1);
    assert.equal((await Player.findById(legacy._id))!.lastActiveAt, undefined);
    const visit = await request("/players/me/activity", token(old._id), "POST");
    assert.equal(visit.data.player.playStatus, "unavailable");
    assert.equal((await request("/players/me/play-status", token(old._id), "PATCH", { playStatus: "available" })).data.player.playStatusSource, "manual");
    await expireInactivePlayers();
    assert.equal((await Player.findById(old._id))!.playStatus, "available");

    // Challenge protection does not wait for the next scheduled sweep.
    await Player.updateOne({ _id: old._id }, { $set: { lastActiveAt: stale, playStatus: "available" } });
    assert.equal((await request("/matches/challenge", memberToken, "POST", { opponentId: old.id, location: "Test court" })).status, 400);
    assert.equal((await Player.findById(old._id))!.playStatusSource, "inactivity");
    await request("/settings", adminToken, "PATCH", { inactivityDays: 0 });
    assert.equal(await expireInactivePlayers(new Date(now.getTime() + 100 * day)), 0);
    assert.equal((await Player.findById(old._id))!.playStatus, "unavailable");

    // Background maintenance runs without any app/API requests.
    await LeagueSettings.updateOne({}, { $set: { inactivityDays: 7 } });
    stopMaintenance = await startActivityMaintenance(20);
    await Player.updateOne({ _id: old._id }, { $set: { playStatus: "available", lastActiveAt: stale } });
    for (let i = 0; i < 50 && (await Player.findById(old._id))!.playStatus === "available"; i++) await delay(20);
    assert.equal((await Player.findById(old._id))!.playStatus, "unavailable");
    stopMaintenance();
    stopMaintenance = undefined;

    const login = await request("/auth/login", "", "POST", { email: old.email, password: "test-password" });
    assert.equal(login.status, 200);
    assert.ok(new Date(login.data.player.lastActiveAt).getTime() >= before);
    assert.equal(login.data.player.playStatus, "unavailable");
    assert.equal((await request("/auth/me", token(old._id), "DELETE")).status, 200);
    const removed = await Player.collection.findOne({ _id: old._id });
    assert.equal(removed!.lastActiveAt, undefined);
    assert.equal(removed!.activityTrackingStartedAt, undefined);
  } finally {
    stopMaintenance?.();
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    assert.equal(mongoose.connection.name, database);
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
