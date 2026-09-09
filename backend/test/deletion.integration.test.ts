import assert from "node:assert/strict";
import { test } from "node:test";
import { once } from "node:events";
import fs from "node:fs/promises";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";

test("admin deletion: cascade, historic points, privacy, files, retry and draw guards", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const uri = process.env.MONGO_TEST_URI!;
  assert.match(uri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "deletion-test-only";
  process.env.REQUIRE_EMAIL_VERIFICATION = "true";
  await mongoose.connect(uri, { dbName: `coa_deletion_test_${process.pid}_${Date.now()}` });
  const { app } = await import("../src/app");
  const { Match } = await import("../src/models/Match");
  const { Tournament } = await import("../src/models/Tournament");
  const { Player } = await import("../src/models/Player");
  const { Location } = await import("../src/models/Location");
  const { LeagueSettings } = await import("../src/models/LeagueSettings");
  const { DeletionJob } = await import("../src/models/DeletionJob");
  const { applyConfirmedMatchStats, awardTournamentWin } = await import("../src/services/rankingService");
  const { ownedGalleryPath } = await import("../src/services/deletionService");
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  const prefix = `delete-test-${process.pid}-${Date.now()}`;
  const image = `/uploads/match-images/${prefix}.png`;
  const shared = `/uploads/tournament-images/${prefix}.png`;
  await fs.mkdir("uploads/match-images", { recursive: true });
  await fs.mkdir("uploads/tournament-images", { recursive: true });
  await fs.writeFile(ownedGalleryPath(image)!, "test-only");
  await fs.writeFile(ownedGalleryPath(shared)!, "test-only-shared");
  try {
    const ids: string[] = [];
    for (let i = 0; i < 5; i++) ids.push((await Player.create({ firstName: "Delete", lastName: `${i}`,
      email: `delete${i}@example.test`, password: "test-password", birthDate: new Date("1990-01-01"),
      country: "ME", sport: "tennis", emailVerified: true, role: i === 0 ? "admin" : "player" })).id);
    const port = (server.address() as { port: number }).port;
    async function request(path: string, method = "GET", body?: unknown, actor = 0) {
      const res = await fetch(`http://127.0.0.1:${port}/api${path}`, { method,
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${jwt.sign({ sub: ids[actor] }, process.env.JWT_SECRET!)}` },
        ...(body === undefined ? {} : { body: JSON.stringify(body) }) });
      return { status: res.status, body: await res.json() };
    }
    async function preview(path: string) {
      const res = await request(`${path}/deletion-preview`);
      assert.equal(res.status, 200, JSON.stringify(res.body));
      return res.body.preview;
    }
    const base = { player1: ids[1], player2: ids[2], round: "Challenge", status: "accepted" };
    const sets = [{ player1Games: 6, player2Games: 2 }, { player1Games: 6, player2Games: 3 }];
    const tbase = { name: "Deletion tournament", owner: ids[1], participants: ids.slice(1),
      startDate: new Date(), endDate: new Date(), location: "Test", category: "Open", format: "round_robin" };
    const stats = async () => (await Player.find().sort({ _id: 1 })).map((p) => ({ id: p.id, wins: p.wins,
      losses: p.losses, points: p.totalPoints, played: p.matchesPlayed, titles: p.tournamentsWon }));
    await LeagueSettings.create({ matchWinPoints: 10, tournamentWinPoints: 50 });
    const location = await Location.create({ name: "Shared location", city: "Test" });
    const unrelated = await Match.create({ ...base, sets, winner: ids[1], status: "confirmed", images: [`https://coabackapi.zeleniparadajz.me${shared}`] });
    await applyConfirmedMatchStats(unrelated);
    const baseline = await stats();
    const tournament = await Tournament.create({ ...tbase, images: [shared], locations: [location._id] });
    const single = await Match.create({ ...base, tournament: tournament._id, sets, winner: ids[1], status: "confirmed", images: [image] });
    const doubles = await Match.create({ ...base, tournament: tournament._id, sets, winner: ids[1], status: "confirmed",
      discipline: "doubles", player1Partner: ids[3], player2Partner: ids[4] });
    await applyConfirmedMatchStats(single); await applyConfirmedMatchStats(doubles);
    for (const status of ["pending", "accepted", "waiting_confirmation", "disputed", "cancelled", "rejected"]) {
      await Match.create({ ...base, tournament: tournament._id, status });
    }
    await awardTournamentWin(tournament.id, ids[1]);
    await awardTournamentWin(tournament.id, ids[1]);
    await LeagueSettings.updateOne({}, { $set: { matchWinPoints: 99, tournamentWinPoints: 999 } });
    const path = `/tournaments/${tournament.id}`;
    const plan = await preview(path);
    assert.equal(plan.matchCount, 8); assert.equal(plan.needsLegacyTournamentAward, false);
    assert.deepEqual(plan.legacyMatches, []);
    for (const target of [path, `/matches/${single.id}`]) {
      assert.equal((await request(`${target}/deletion-preview`, "GET", undefined, 1)).status, 403);
      assert.equal((await request(target, "DELETE", { revision: plan.revision }, 1)).status, 403);
    }
    const beforeBadRequest = await stats();
    assert.equal((await request(path, "DELETE", {})).status, 400);
    assert.deepEqual(await stats(), beforeBadRequest);
    assert.equal((await request(path, "DELETE", { revision: plan.revision })).status, 200);
    assert.deepEqual(await stats(), baseline);
    assert.equal(await Match.countDocuments({ tournament: tournament._id }), 0);
    assert.equal(await Tournament.countDocuments({ _id: tournament._id }), 0);
    assert.ok(await Location.exists({ _id: location._id }));
    assert.ok(await Match.exists({ _id: unrelated._id }));
    await assert.rejects(fs.access(ownedGalleryPath(image)!));
    await fs.access(ownedGalleryPath(shared)!);
    assert.equal((await request(path, "DELETE", { revision: plan.revision })).status, 200);
    assert.deepEqual(await stats(), baseline);

    // Legacy match points are explicit, never today's configured rate.
    const legacy = await Match.create({ ...base, sets, winner: ids[1], status: "confirmed", statsApplied: true });
    await Player.updateOne({ _id: ids[1] }, { $inc: { wins: 1, matchesPlayed: 1, totalPoints: 17 } });
    await Player.updateOne({ _id: ids[2] }, { $inc: { losses: 1, matchesPlayed: 1 } });
    const lp = await preview(`/matches/${legacy.id}`);
    assert.equal(lp.legacyMatches[0].id, legacy.id);
    assert.equal((await request(`/matches/${legacy.id}`, "DELETE", { revision: lp.revision })).status, 400);
    assert.equal((await request(`/matches/${legacy.id}`, "DELETE", { revision: lp.revision, legacyMatchPoints: { [legacy.id]: 1000000 } })).status, 400);
    assert.equal(await DeletionJob.countDocuments({ _id: `match:${legacy.id}` }), 0);
    assert.equal((await request(`/matches/${legacy.id}`, "DELETE", { revision: lp.revision, legacyMatchPoints: { [legacy.id]: 17 } })).status, 200);
    assert.deepEqual(await stats(), baseline);

    // An interrupted rollback resumes without decrementing the first player twice.
    const interrupted = await Match.create({ ...base, sets, winner: ids[1], status: "confirmed" });
    await applyConfirmedMatchStats(interrupted);
    const ip = await preview(`/matches/${interrupted.id}`);
    const update = Player.updateOne;
    let calls = 0;
    Player.updateOne = function (...args: Parameters<typeof update>) {
      if (++calls === 2) throw new Error("Simulated deletion failure");
      return update.apply(this, args);
    } as typeof update;
    try { assert.equal((await request(`/matches/${interrupted.id}`, "DELETE", { revision: ip.revision })).status, 500); }
    finally { Player.updateOne = update; }
    assert.equal((await DeletionJob.findById(`match:${interrupted.id}`))!.completed, false);
    assert.equal((await request(`/matches/${interrupted.id}`, "DELETE", { revision: ip.revision })).status, 200);
    assert.deepEqual(await stats(), baseline);

    // A stale preview cannot erase a subsequently edited match.
    const changed = await Match.create(base);
    const old = await preview(`/matches/${changed.id}`);
    await Match.updateOne({ _id: changed._id }, { $set: { location: "Changed" } });
    assert.equal((await request(`/matches/${changed.id}`, "DELETE", { revision: old.revision })).status, 409);
    assert.ok(await Match.exists({ _id: changed._id }));

    // Legacy tournament winners may have no award at all (old bracket completion).
    const oldTournament = await Tournament.create({ ...tbase, winner: ids[1], status: "finished" });
    const tp = await preview(`/tournaments/${oldTournament.id}`);
    assert.equal(tp.needsLegacyTournamentAward, true);
    assert.equal((await request(`/tournaments/${oldTournament.id}`, "DELETE", { revision: tp.revision })).status, 400);
    assert.equal((await request(`/tournaments/${oldTournament.id}`, "DELETE", { revision: tp.revision, legacyTournamentAwardApplied: false })).status, 200);
    assert.deepEqual(await stats(), baseline);

    const oldAward = await Tournament.create({ ...tbase, winner: ids[1], status: "finished" });
    await Player.updateOne({ _id: ids[1] }, { $inc: { tournamentsWon: 1, totalPoints: 123 } });
    const ap = await preview(`/tournaments/${oldAward.id}`);
    assert.equal((await request(`/tournaments/${oldAward.id}`, "DELETE", { revision: ap.revision,
      legacyTournamentAwardApplied: true })).status, 400);
    assert.equal((await request(`/tournaments/${oldAward.id}`, "DELETE", { revision: ap.revision,
      legacyTournamentAwardApplied: true, legacyTournamentPoints: 123 })).status, 200);
    assert.deepEqual(await stats(), baseline);

    const friendly = await Match.create({ ...base, friendly: true, sets, winner: ids[1], status: "confirmed" });
    await applyConfirmedMatchStats(friendly);
    const friendlyPlan = await preview(`/matches/${friendly.id}`);
    const duplicates = await Promise.all([request(`/matches/${friendly.id}`, "DELETE", { revision: friendlyPlan.revision }),
      request(`/matches/${friendly.id}`, "DELETE", { revision: friendlyPlan.revision })]);
    assert.deepEqual(duplicates.map((r) => r.status), [200, 200]);
    assert.deepEqual(await stats(), baseline);

    // Only the player whose increment actually succeeded is rolled back.
    const partial = await Match.create({ ...base, sets, winner: ids[1], status: "confirmed" });
    let increments = 0;
    Player.updateOne = function (...args: Parameters<typeof update>) {
      if (++increments === 2) throw new Error("Simulated partial award");
      return update.apply(this, args);
    } as typeof update;
    try { await assert.rejects(applyConfirmedMatchStats(partial)); }
    finally { Player.updateOne = update; }
    const pp = await preview(`/matches/${partial.id}`);
    assert.equal((await request(`/matches/${partial.id}`, "DELETE", { revision: pp.revision })).status, 200);
    assert.deepEqual(await stats(), baseline);

    // A final can be deleted and regenerated, but feeder matches cannot leave a broken draw.
    const knockout = await Tournament.create({ ...tbase, knockoutSize: 2, knockoutStartedAt: new Date(), knockoutSeeds: ids.slice(1, 3) });
    const final = await Match.create({ ...base, tournament: knockout._id, round: "F", sets, winner: ids[1], status: "confirmed" });
    await Tournament.updateOne({ _id: knockout._id }, { $set: { knockoutRounds: [{ round: "F", matchIds: [final._id] }], matches: [final._id] } });
    await applyConfirmedMatchStats(final); await awardTournamentWin(knockout.id, ids[1]);
    const fp = await preview(`/matches/${final.id}`);
    assert.equal(fp.blockedReason, null); assert.equal(fp.clearsTournamentWinner, true);
    assert.equal((await request(`/matches/${final.id}`, "DELETE", { revision: fp.revision })).status, 200);
    const remaining = (await Tournament.findById(knockout._id))!;
    assert.equal(remaining.winner, undefined); assert.equal(remaining.knockoutStartedAt, undefined);
    assert.equal(remaining.matches.length, 0); assert.equal(remaining.status, "active");
    assert.deepEqual(await stats(), baseline);
    const draw = await Tournament.create({ ...tbase, format: "elimination", drawGeneratedAt: new Date() });
    const semi = await Match.create({ ...base, tournament: draw._id, round: "SF" });
    const sp = await preview(`/matches/${semi.id}`);
    assert.ok(sp.blockedReason);
    assert.equal((await request(`/matches/${semi.id}`, "DELETE", { revision: sp.revision })).status, 409);
    const dp = await preview(`/tournaments/${draw.id}`);
    assert.equal((await request(`/tournaments/${draw.id}`, "DELETE", { revision: dp.revision })).status, 200);
    for (const unsafe of ["/etc/passwd", "/uploads/profile-images/photo.png", "/uploads/match-images/../secret", "https://other.test/image.png"]) assert.equal(ownedGalleryPath(unsafe), null);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await fs.rm(ownedGalleryPath(image)!, { force: true });
    await fs.rm(ownedGalleryPath(shared)!, { force: true });
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
