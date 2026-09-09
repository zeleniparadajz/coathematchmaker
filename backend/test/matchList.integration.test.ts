import assert from "node:assert/strict";
import { test } from "node:test";
import { once } from "node:events";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";

test("all matches preserves private/friendly visibility and includes the result submitter", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const uri = process.env.MONGO_TEST_URI!;
  assert.match(uri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "match-list-test-only";
  process.env.REQUIRE_EMAIL_VERIFICATION = "true";
  await mongoose.connect(uri, { dbName: `coa_match_list_test_${process.pid}_${Date.now()}` });
  const { app } = await import("../src/app");
  const { Player } = await import("../src/models/Player");
  const { Match } = await import("../src/models/Match");
  const { Tournament } = await import("../src/models/Tournament");
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    const players = [];
    for (let i = 0; i < 5; i++) players.push(await Player.create({
      firstName: "List", lastName: `${i}`, email: `list${i}@example.test`,
      password: "test-password", birthDate: new Date("1990-01-01"), country: "ME",
      sport: "tennis", emailVerified: true, role: i === 0 ? "admin" : "player"
    }));
    const ids = players.map((p) => p.id);
    const base = { player1: ids[2], player2: ids[3], round: "Challenge", status: "accepted" };
    const publicMatch = await Match.create({ ...base, status: "waiting_confirmation", resultSubmittedBy: ids[2] });
    const hiddenFriendly = await Match.create({ ...base, friendly: true });
    const myDoubles = await Match.create({ ...base, discipline: "doubles", player1Partner: ids[4], player2Partner: ids[1], friendly: true });
    const tournamentBase = { name: "Private", owner: ids[2], location: "Test court", category: "Open",
      visibility: "private", startDate: new Date(), endDate: new Date() };
    const hiddenTournament = await Tournament.create(tournamentBase);
    const joinedTournament = await Tournament.create({ ...tournamentBase, participants: [ids[1]] });
    const hiddenMatch = await Match.create({ ...base, tournament: hiddenTournament.id });
    const joinedMatch = await Match.create({ ...base, tournament: joinedTournament.id });
    const port = (server.address() as { port: number }).port;
    async function list(actor: number, query = "") {
      const response = await fetch(`http://127.0.0.1:${port}/api/matches${query}`, {
        headers: { Authorization: `Bearer ${jwt.sign({ sub: ids[actor] }, process.env.JWT_SECRET!)}` }
      });
      assert.equal(response.status, 200);
      return (await response.json()).matches as { _id: string; resultSubmittedBy?: { _id: string; firstName: string; password?: string } }[];
    }
    const visible = await list(1);
    assert.deepEqual(visible.map((m) => m._id).sort(), [publicMatch.id, myDoubles.id, joinedMatch.id].sort());
    const submitter = visible.find((m) => m._id === publicMatch.id)!.resultSubmittedBy!;
    assert.equal(submitter._id, ids[2]);
    assert.equal(submitter.firstName, "List");
    assert.equal(submitter.password, undefined);
    assert.deepEqual(await list(1, `?tournament=${hiddenTournament.id}`), []);
    assert.deepEqual((await list(0)).map((m) => m._id).sort(),
      [publicMatch.id, hiddenFriendly.id, myDoubles.id, hiddenMatch.id, joinedMatch.id].sort());
  } finally {
    await new Promise<void>((resolve) => server.close(() => resolve()));
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
