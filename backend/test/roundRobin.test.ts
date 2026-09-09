import assert from "node:assert/strict";
import { test } from "node:test";
import { leagueCompletionProblem, leagueRankingRules, roundRobinTable, seededPairs, type LeagueMatch } from "../src/services/roundRobinRules";

test("league copy preserves Serbian text and the requested redoslijed spelling", () => {
  assert.match(leagueRankingRules, /međusobnim mečevima igrača/);
  assert.match(leagueRankingRules, /redoslijed prijave/);
  assert.equal(leagueCompletionProblem([], []), "Potrebna su najmanje dva učesnika.");
});

const match = (a: string, b: string, winner = a, round = "RR"): LeagueMatch => ({
  player1: a, player2: b, winner, round, status: "confirmed",
  sets: [{ player1Games: winner === a ? 6 : 2, player2Games: winner === b ? 6 : 2 }]
});

test("league standings count only confirmed RR results, including friendly matches", () => {
  const matches = [match("a", "b"), match("a", "c"), match("b", "c"), match("a", "b", "b", "F")];
  const rows = roundRobinTable(["c", "b", "a", "d"], matches);
  assert.deepEqual(rows.map((r) => r.playerId), ["a", "b", "d", "c"]);
  assert.deepEqual(rows.map((r) => r.wins), [2, 1, 0, 0]);
  assert.equal(rows[0].setsWon, 2);
  assert.equal(rows[0].gamesWon, 12);
  assert.equal(rows[0].played, 2);
  assert.equal(roundRobinTable(["a", "b"], [{ ...match("a", "b"), status: "waiting_confirmation" }])[0].played, 0);
});

test("tied wins use mini-table, then set/game difference and registration order", () => {
  const tied = [match("a", "b"), match("b", "c"), match("c", "a")];
  assert.deepEqual(roundRobinTable(["c", "b", "a"], tied).map((r) => r.playerId), ["c", "b", "a"]);
  tied[0].sets[0].player2Games = 0;
  assert.deepEqual(roundRobinTable(["c", "b", "a"], tied).map((r) => r.playerId), ["a", "c", "b"]);
  const headToHead = [match("a", "b"), match("c", "a"), match("b", "d")];
  assert.ok(roundRobinTable(["b", "a", "c", "d"], headToHead).findIndex((r) => r.playerId === "a") <
    roundRobinTable(["b", "a", "c", "d"], headToHead).findIndex((r) => r.playerId === "b"));
});

test("completion requires every unique pair, confirmed winners and scores", () => {
  const players = ["a", "b", "c"];
  const complete = [match("a", "b"), match("a", "c"), match("b", "c")];
  assert.equal(leagueCompletionProblem(players, complete), null);
  assert.ok(leagueCompletionProblem(players, complete.slice(1)));
  assert.ok(leagueCompletionProblem(players, [complete[0], complete[0], complete[2]]));
  for (const status of ["accepted", "disputed", "cancelled", "waiting_confirmation"]) {
    assert.ok(leagueCompletionProblem(players, [{ ...complete[0], status }, ...complete.slice(1)]));
  }
  assert.ok(leagueCompletionProblem(players, [{ ...complete[0], sets: [] }, ...complete.slice(1)]));
  assert.ok(leagueCompletionProblem(players, [{ ...complete[0], winner: "outsider" }, ...complete.slice(1)]));
});

test("seeded knockout keeps top two on opposite sides and all seeds exactly once", () => {
  assert.deepEqual(seededPairs(["1", "2", "3", "4"]), [["1", "4"], ["2", "3"]]);
  assert.deepEqual(seededPairs(["1", "2", "3", "4", "5", "6", "7", "8"]), [["1", "8"], ["4", "5"], ["2", "7"], ["3", "6"]]);
  for (const size of [2, 4, 8, 16]) {
    const seeds = Array.from({ length: size }, (_, i) => String(i + 1));
    const flat = seededPairs(seeds).flat();
    assert.equal(new Set(flat).size, size);
    assert.equal(flat[0], "1");
    assert.equal(flat[size / 2], "2");
  }
  assert.throws(() => seededPairs(["1", "2", "3"]));
});
