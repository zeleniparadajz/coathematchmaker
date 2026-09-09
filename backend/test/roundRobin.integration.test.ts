import assert from "node:assert/strict";
import { test } from "node:test";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";
import { once } from "node:events";

test("round-robin optional knockout: authorization, legacy league, seeding, retries, progression and winner", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const uri = process.env.MONGO_TEST_URI!;
  assert.match(uri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "knockout-test-secret";
  process.env.REQUIRE_EMAIL_VERIFICATION = "false";
  const database = `coa_knockout_test_${process.pid}_${Date.now()}`;
  await mongoose.connect(uri, { dbName: database });
  const { app } = await import("../src/app");
  const { Player } = await import("../src/models/Player");
  const { Match } = await import("../src/models/Match");
  const { Tournament } = await import("../src/models/Tournament");
  const { roundRobinState, startRoundRobinKnockout, advanceRoundRobinKnockout } = await import("../src/services/roundRobinService");
  const { generateTournamentDraw } = await import("../src/services/bracketService");
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const players = await Player.insertMany(Array.from({ length: 16 }, (_, i) => ({
      firstName: `Player${i}`, lastName: "Test", role: i === 0 ? "admin" : "player", email: `p${i}@example.test`,
      password: "test-only", birthDate: new Date("1990-01-01"), country: "ME", sport: "tennis"
    })));
    const ids = players.map((p) => String(p._id));
    const token = (i: number) => jwt.sign({ sub: ids[i] }, process.env.JWT_SECRET!);
    const port = (server.address() as { port: number }).port;
    async function request(path: string, method = "GET", body?: unknown, auth = token(0)) {
      const r = await fetch(`http://127.0.0.1:${port}/api${path}`, { method,
        headers: { "Content-Type": "application/json", ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: r.status, data: await r.json() };
    }
    const base = { name: "Existing league", location: "Test court", category: "Open", format: "round_robin",
      discipline: "singles", startDate: "2026-09-01", endDate: "2026-12-01", owner: players[1]._id, admins: [players[1]._id] };
    const league = await Tournament.create({ ...base, participants: ids.slice(0, 4) });
    const id = String(league._id), path = `/tournaments/${id}`;
    assert.equal((await request(`${path}/round-robin`, "GET", undefined, "")).status, 401);
    assert.equal((await request(path, "PATCH", { knockoutSize: 4 }, token(6))).status, 403);
    assert.equal((await request(path, "PATCH", { knockoutSize: 3 })).status, 400);
    assert.equal((await request(path, "PATCH", { knockoutSize: 4, discipline: "doubles" })).status, 400);
    assert.equal((await request(path, "PATCH", { knockoutSize: 4, format: "elimination" })).status, 400);
    await generateTournamentDraw(id);
    const oldMatches = await Match.find({ tournament: id });
    assert.equal(oldMatches.length, 6);
    assert.equal((await request(path, "PATCH", { format: "elimination" })).status, 400);
    assert.equal((await request(`${path}/participants`, "POST", { playerId: ids[6] })).status, 400);
    assert.equal((await request(`${path}/admins`, "POST", { playerId: ids[6] })).status, 400);
    // Enable the option on an already generated legacy league, through its owner.
    assert.equal((await request(path, "PATCH", { knockoutSize: 4 }, token(1))).status, 200);
    const blocked = (await request(`${path}/round-robin`)).data.roundRobin;
    assert.equal(blocked.canStart, false);
    assert.equal((await request(`${path}/start-knockout`, "POST", { seeds: blocked.seeds })).status, 400);
    for (const m of oldMatches) await Match.updateOne({ _id: m._id }, { $set: {
      status: "confirmed", winner: m.player1, sets: [{ player1Games: 6, player2Games: 2 }], statsApplied: true
    } });
    const ready = (await request(`${path}/round-robin`)).data.roundRobin;
    assert.equal(ready.canStart, true);
    assert.deepEqual(ready.seeds, ids.slice(0, 4));
    assert.equal((await request(`${path}/start-knockout`, "POST", { seeds: [...ready.seeds].reverse() })).status, 409);
    assert.equal((await request(`${path}/start-knockout`, "POST", { seeds: ready.seeds }, token(6))).status, 403);
    // Concurrent retries reserve a single bracket and leave all RR IDs/results untouched.
    const starts = await Promise.all([request(`${path}/start-knockout`, "POST", { seeds: ready.seeds }, token(1)),
      request(`${path}/start-knockout`, "POST", { seeds: ready.seeds })]);
    starts.forEach((r) => assert.equal(r.status, 200, JSON.stringify(r.data)));
    assert.equal(await Match.countDocuments({ tournament: id }), 8);
    assert.deepEqual((await request(`${path}/round-robin`)).data.roundRobin.standings, ready.standings);
    const started = (await Tournament.findById(id))!;
    const semiIds = started.knockoutRounds[0].matchIds;
    const semi = await Match.findById(semiIds[0]);
    assert.deepEqual([String(semi!.player1), String(semi!.player2)], [ids[0], ids[3]]);
    assert.equal((await request(path, "PATCH", { knockoutSize: 0 })).status, 400);
    assert.equal((await request(path, "PATCH", { status: "finished" })).status, 400);
    assert.equal((await request(`${path}/finish`, "POST", { winnerId: ids[0] })).status, 400);
    assert.equal((await request(`${path}/advance-round`, "POST", { round: "SF" })).status, 400);
    assert.equal((await request(`${path}/advance-round`, "POST", { round: "SF" }, token(6))).status, 403);
    assert.equal((await request(`/matches/${semiIds[0]}`, "PATCH", { round: "RR" })).status, 400);
    assert.equal((await request(`/matches/${oldMatches[0]._id}`, "PATCH", { sets: [{ player1Games: 6, player2Games: 0 }] })).status, 400);
    assert.equal((await request(`${path}/matches`, "POST", { player1: ids[0], player2: ids[1], round: "QF" })).status, 400);
    assert.equal((await request("/matches", "POST", { tournament: id, player1: ids[0], player2: ids[1], round: "RR" })).status, 400);
    // Recover an interrupted materialization using its reserved ID.
    await Match.deleteOne({ _id: semiIds[1] });
    await startRoundRobinKnockout(id, ready.seeds);
    assert.ok(await Match.exists({ _id: semiIds[1] }));
    for (const matchId of semiIds) {
      const m = (await Match.findById(matchId))!;
      const response = await request(`/matches/${matchId}`, "PATCH", { status: "confirmed", winner: String(m.player1), sets: [{ player1Games: 6, player2Games: 2 }] });
      assert.equal(response.status, 200, JSON.stringify(response.data));
    }
    await Promise.all([advanceRoundRobinKnockout(id, "SF"), advanceRoundRobinKnockout(id, "SF")]);
    assert.equal(await Match.countDocuments({ tournament: id, round: "F" }), 1);
    const final = (await Match.findOne({ tournament: id, round: "F" }))!;
    assert.deepEqual([String(final.player1), String(final.player2)], [ids[0], ids[1]]);
    await request(`/matches/${final._id}`, "PATCH", { status: "confirmed", winner: ids[0], sets: [{ player1Games: 6, player2Games: 1 }] });
    const before = (await Player.findById(ids[0]))!;
    const completed = await Promise.all([advanceRoundRobinKnockout(id, "F"), advanceRoundRobinKnockout(id, "F")]);
    completed.forEach((state) => assert.equal(state.winnerId, ids[0]));
    assert.equal((await Player.findById(ids[0]))!.tournamentsWon, before.tournamentsWon + 1);
    const after = (await Player.findById(ids[0]))!;
    await advanceRoundRobinKnockout(id, "F");
    assert.equal((await Player.findById(ids[0]))!.totalPoints, after.totalPoints);
    assert.equal((await Tournament.findById(id))!.status, "finished");
    assert.equal(await Match.countDocuments({ tournament: id, round: "RR", status: "confirmed" }), 6);
    assert.deepEqual((await roundRobinState((await Tournament.findById(id))!)).standings, ready.standings);
    assert.equal((await request(path, "PATCH", { name: "Renamed tournament" })).status, 200);
    const privateLeague = await Tournament.create({ ...base, participants: ids.slice(0, 2), visibility: "private" });
    assert.equal((await request(`/tournaments/${privateLeague._id}/round-robin`, "GET", undefined, token(8))).status, 404);
    // Larger brackets progress from their reserved order, including 16 -> 8 -> 4 -> 2.
    for (const size of [2, 8, 16]) {
      const t = await Tournament.create({ ...base, knockoutSize: size, friendly: true, participants: ids.slice(0, size) });
      await generateTournamentDraw(String(t._id));
      const rr = await Match.find({ tournament: t._id });
      await Match.bulkWrite(rr.map((m) => ({ updateOne: { filter: { _id: m._id }, update: { $set: {
        status: "confirmed", winner: m.player1, sets: [{ player1Games: 6, player2Games: 0 }]
      } } } })));
      let state = await startRoundRobinKnockout(String(t._id), ids.slice(0, size));
      while (!state.finished) {
        const roundMatches = await Match.find({ tournament: t._id, round: state.currentRound });
        await Match.bulkWrite(roundMatches.map((m) => ({ updateOne: { filter: { _id: m._id }, update: { $set: { status: "confirmed", winner: m.player1 } } } })));
        state = await advanceRoundRobinKnockout(String(t._id), state.currentRound!);
      }
      assert.equal(await Match.countDocuments({ tournament: t._id, round: { $ne: "RR" } }), size - 1);
      assert.equal((await Player.findById(ids[0]))!.tournamentsWon, after.tournamentsWon);
    }
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    assert.equal(mongoose.connection.name, database);
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
