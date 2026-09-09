import assert from "node:assert/strict";
import { test } from "node:test";
import { once } from "node:events";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";

test("result validation, admin restoration and reversible match statistics", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const uri = process.env.MONGO_TEST_URI!;
  assert.match(uri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "result-test-only";
  process.env.REQUIRE_EMAIL_VERIFICATION = "true";
  const database = `coa_result_test_${process.pid}_${Date.now()}`;
  await mongoose.connect(uri, { dbName: database });
  const { app } = await import("../src/app");
  const { Player } = await import("../src/models/Player");
  const { Match } = await import("../src/models/Match");
  const { Tournament } = await import("../src/models/Tournament");
  const { LeagueSettings } = await import("../src/models/LeagueSettings");
  const { applyConfirmedMatchStats } = await import("../src/services/rankingService");
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const players = [];
    for (let i = 0; i < 4; i++) players.push(await Player.create({ firstName: "Result", lastName: `${i}`, email: `p${i}@example.test`,
      password: "test-password", birthDate: new Date("1990-01-01"), country: "ME", sport: "tennis", emailVerified: true,
      role: i === 0 ? "admin" : "player" }));
    const ids = players.map((p) => p.id);
    const tokens = ids.map((id) => jwt.sign({ sub: id }, process.env.JWT_SECRET!));
    const port = (server.address() as { port: number }).port;
    async function request(path: string, body?: unknown, actor = 0, method = "POST") {
      const response = await fetch(`http://127.0.0.1:${port}/api${path}`, {
        method, headers: { "Content-Type": "application/json", Authorization: `Bearer ${tokens[actor]}` },
        ...(body === undefined ? {} : { body: JSON.stringify(body) })
      });
      return { status: response.status, data: await response.json() };
    }
    await LeagueSettings.create({ resultEntryDelayMinutes: 0, matchWinPoints: 10 });
    const sets = [{ player1Games: 1, player2Games: 6 }, { player1Games: 2, player2Games: 6 }];
    const result = { sets, winner: ids[2] };
    async function make(extra = {}) {
      const response = await request("/matches", { player1: ids[1], player2: ids[2], status: "accepted", ...extra });
      assert.equal(response.status, 201, JSON.stringify(response.data));
      return response.data.match;
    }
    const stats = async () => (await Player.find({ _id: { $in: ids } }).sort({ _id: 1 })).map((p) =>
      ({ id: p.id, wins: p.wins, losses: p.losses, played: p.matchesPlayed, points: p.totalPoints }));
    const initialStats = await stats();
    const match = await make();
    const path = `/matches/${match._id}`;
    assert.equal((await request(`${path}/submit-result`, { ...result, winner: ids[1] }, 1)).status, 400);
    assert.equal((await request(`${path}/submit-result`, result, 1)).status, 200);
    assert.equal((await request(`${path}/dispute`, {}, 2)).status, 200);
    assert.equal((await request(`${path}/admin-resolve`, { action: "restore_result" }, 2)).status, 403);
    let restored = await request(`${path}/admin-resolve`, { action: "restore_result" });
    assert.equal(restored.status, 200);
    assert.equal(restored.data.match.status, "waiting_confirmation");
    assert.deepEqual(restored.data.match.sets, sets);
    assert.equal(restored.data.match.winner._id, ids[2]);
    assert.equal(restored.data.match.resultSubmittedBy._id, ids[1]);
    assert.equal(restored.data.match.disputedAt, undefined);
    assert.deepEqual(await stats(), initialStats);
    // Never reopen a feeder match underneath already generated rounds or an awarded title.
    const tournament = await Tournament.create({ name: "Correction test", location: "Test court", category: "Open",
      format: "elimination", owner: ids[0], participants: ids, startDate: new Date(), endDate: new Date() });
    const semi = await make({ tournament: tournament.id, round: "SF", ...result, status: "confirmed" });
    const final = await make({ tournament: tournament.id, round: "F" });
    const beforeGuard = await stats();
    assert.equal((await request(`/matches/${semi._id}/admin-resolve`, { action: "reopen_result" })).status, 400);
    assert.deepEqual(await stats(), beforeGuard);
    assert.equal((await Match.findById(semi._id).select("+resultReset"))!.resultReset, undefined);
    await Match.deleteOne({ _id: final._id });
    await Tournament.updateOne({ _id: tournament._id }, { $set: { winner: ids[2], status: "finished" } });
    assert.equal((await request(`/matches/${semi._id}/admin-resolve`, { action: "reopen_result" })).status, 400);
    assert.deepEqual(await stats(), beforeGuard);
    await Tournament.updateOne({ _id: tournament._id }, { $unset: { winner: "" }, $set: { status: "active" } });
    assert.equal((await request(`/matches/${semi._id}/admin-resolve`, { action: "reopen_result" })).status, 200);
    assert.deepEqual(await stats(), initialStats);
    for (const action of ["reject", "cancel"]) {
      assert.equal((await request(`${path}/admin-resolve`, { action })).status, 200);
      restored = await request(`${path}/admin-resolve`, { action: "restore_result" });
      assert.equal(restored.status, 200);
      assert.equal(restored.data.match.status, "waiting_confirmation");
    }
    // Players cannot confirm inconsistent legacy data. Admin confirmation derives the winner from scores.
    await Match.updateOne({ _id: match._id }, { $set: { winner: ids[1] } });
    assert.equal((await request(`${path}/confirm-result`, {}, 2)).status, 400);
    const corrected = await request(`${path}/admin-resolve`, { action: "confirm" });
    assert.equal(corrected.status, 200);
    assert.equal(corrected.data.match.winner._id, ids[2]);
    assert.equal(corrected.data.match.resultConfirmedBy._id, ids[0]);
    assert.equal((await Player.findById(ids[2]))!.totalPoints, 10);
    restored = await request(`${path}/admin-resolve`, { action: "reopen_result", note: "Wrong winner" });
    assert.equal(restored.data.match.status, "accepted");
    assert.deepEqual(restored.data.match.sets, []);
    assert.equal(restored.data.match.winner, undefined);
    assert.equal(restored.data.match.resultSubmittedBy, undefined);
    assert.equal(restored.data.match.acceptedAt, match.acceptedAt);
    assert.ok((await Match.findById(match._id).select("+resultHistory"))!.resultHistory.some((r) => r.note === "Wrong winner"));
    await request(`${path}/submit-result`, result, 1);
    assert.equal((await request(`${path}/confirm-result`, {}, 2)).status, 200);
    const confirmedStats = await stats();
    assert.equal((await Player.findById(ids[2]))!.totalPoints, 10);
    const saved = (await Match.findById(match._id).select("+statsApplied"))!;
    await Promise.all([applyConfirmedMatchStats(saved), applyConfirmedMatchStats(saved)]);
    assert.deepEqual(await stats(), confirmedStats);
    // Later settings changes must not change the amount reversed.
    await LeagueSettings.updateOne({}, { $set: { matchWinPoints: 25 } });
    const resets = await Promise.all([request(`${path}/admin-resolve`, { action: "reopen_result" }),
      request(`${path}/admin-resolve`, { action: "reopen_result" })]);
    assert.ok(resets.some((r) => r.status === 200));
    assert.deepEqual(await stats(), initialStats);
    // Reproduce the cancelled result in the screenshot, including a stale explicit winner from a client.
    for (const status of ["cancelled", "rejected", "disputed"]) {
      const next = await make();
      await Match.updateOne({ _id: next._id }, { $set: { status, winner: ids[1], sets,
        disputedAt: new Date(), cancelledAt: new Date(), rejectedAt: new Date() } });
      assert.equal((await request(`/matches/${next._id}/admin-resolve`, { action: "confirm", sets }, 1)).status, 403);
      const confirmed = await request(`/matches/${next._id}/admin-resolve`, { action: "confirm", sets, winner: ids[1] });
      assert.equal(confirmed.status, 200, JSON.stringify(confirmed.data));
      assert.equal(confirmed.data.match.status, "confirmed");
      assert.equal(confirmed.data.match.winner._id, ids[2]);
      assert.deepEqual(confirmed.data.match.sets, sets);
      for (const field of ["disputedAt", "cancelledAt", "rejectedAt"]) assert.equal(confirmed.data.match[field], undefined);
      const history = (await Match.findById(next._id).select("+resultHistory"))!.resultHistory;
      assert.equal(history.at(-1)!.status, status);
      assert.equal(String(history.at(-1)!.winner), ids[1]);
      await request(`/matches/${next._id}/admin-resolve`, { action: "reopen_result" });
      assert.deepEqual(await stats(), initialStats);
    }
    const editable = await make({ status: "cancelled" });
    const editedSets = [{ player1Games: 6, player2Games: 1 }, { player1Games: 6, player2Games: 2 }];
    const edited = await request(`/matches/${editable._id}/admin-resolve`, { action: "confirm", sets: editedSets });
    assert.equal(edited.status, 200);
    assert.equal(edited.data.match.winner._id, ids[1]);
    assert.deepEqual(edited.data.match.sets, editedSets);
    await request(`/matches/${editable._id}/admin-resolve`, { action: "reopen_result" });
    assert.deepEqual(await stats(), initialStats);
    for (const invalidSets of [[], [{ player1Games: 6, player2Games: 6 }],
      [{ player1Games: 6, player2Games: 1 }, { player1Games: 1, player2Games: 6 }]]) {
      assert.equal((await request(`/matches/${editable._id}/admin-resolve`, { action: "confirm", sets: invalidSets })).status, 400);
    }
    assert.equal((await Match.findById(match._id))!.status, "accepted");
    assert.equal((await request(`${path}/admin-resolve`, { action: "reopen_result" })).status, 400);
    assert.deepEqual(await stats(), initialStats);
    const reversed = sets.map((s) => ({ player1Games: s.player2Games, player2Games: s.player1Games }));
    await request(`${path}/submit-result`, { sets: reversed, winner: ids[1] }, 1);
    await request(`${path}/confirm-result`, {}, 2);
    assert.equal((await Player.findById(ids[1]))!.totalPoints, 25);
    assert.equal((await Player.findById(ids[2]))!.totalPoints, 0);
    // Legacy points are supplied explicitly, never inferred from today's settings.
    await Match.updateOne({ _id: match._id }, { $unset: { statsWinPoints: "" } });
    assert.equal((await request(`${path}/admin-resolve`, { action: "reopen_result" })).status, 400);
    assert.equal((await request(`${path}/admin-resolve`, { action: "reopen_result", legacyWinPoints: 25 })).status, 200);
    assert.deepEqual(await stats(), initialStats);
    for (const extra of [{ friendly: true }, { discipline: "doubles", player1Partner: ids[0], player2Partner: ids[3] }]) {
      const next = await make({ ...extra, ...result, status: "confirmed" });
      assert.equal((await request(`/matches/${next._id}/admin-resolve`, { action: "reopen_result" })).status, 200);
      assert.deepEqual(await stats(), initialStats);
    }
    // A partial reversal can resume; an already reversed player's counters do not change twice.
    const interrupted = await make({ ...result, status: "confirmed" });
    const originalUpdate = Player.updateOne;
    let failOnce = true;
    Player.updateOne = function (...args: any[]) {
      if (failOnce && args[1]?.$inc?.losses === -1) {
        failOnce = false;
        throw new Error("Simulated statistics update failure");
      }
      return originalUpdate.apply(this, args as any);
    } as typeof Player.updateOne;
    try {
      assert.equal((await request(`/matches/${interrupted._id}/admin-resolve`, { action: "reopen_result" })).status, 500);
    } finally {
      Player.updateOne = originalUpdate;
    }
    assert.ok((await Match.findById(interrupted._id).select("+resultReset"))!.resultReset);
    assert.equal((await request(`/matches/${interrupted._id}/admin-resolve`, { action: "reopen_result" })).status, 200);
    assert.deepEqual(await stats(), initialStats);
    assert.equal((await Match.findById(interrupted._id).select("+resultReset"))!.resultReset, undefined);

    // A dispute racing with confirmation cannot overwrite an already counted result.
    const racing = await make();
    await request(`/matches/${racing._id}/submit-result`, result, 1);
    const competing = await Promise.all([
      request(`/matches/${racing._id}/confirm-result`, {}, 2),
      request(`/matches/${racing._id}/dispute`, {}, 2)
    ]);
    assert.equal(competing.filter((r) => r.status === 200).length, 1);
    assert.equal((await request(`/matches/${racing._id}/admin-resolve`, { action: "reopen_result" })).status, 200);
    assert.deepEqual(await stats(), initialStats);
    for (const invalid of [{ winner: ids[1], sets }, { winner: ids[2], sets: [] },
      { winner: ids[2], sets: [{ player1Games: 0, player2Games: 0 }] }]) {
      assert.equal((await request("/matches", { player1: ids[1], player2: ids[2], status: "confirmed", ...invalid })).status, 400);
      assert.equal((await request(path, { ...invalid, status: "confirmed" }, 0, "PATCH")).status, 400);
    }
    // A rejected challenge without a result can return to result entry, not confirmation.
    const rejected = await make({ status: "rejected" });
    assert.equal((await request(`/matches/${rejected._id}/admin-resolve`, { action: "restore_result" })).status, 400);
    assert.equal((await request(`/matches/${rejected._id}/admin-resolve`, { action: "reopen_result" })).status, 200);
    assert.deepEqual(await stats(), initialStats);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    assert.equal(mongoose.connection.name, database);
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
