import assert from "node:assert/strict";
import { test } from "node:test";
import { scoreWinnerSide, validateMatchResult } from "../src/services/matchResultService";

const scores = (...sets: number[][]) => sets.map(([player1Games, player2Games]) => ({ player1Games, player2Games }));

test("winner follows sets rather than the selected player or total games", () => {
  const screenshot = scores([1, 6], [2, 6]);
  assert.equal(scoreWinnerSide(screenshot), "player2");
  assert.throws(() => validateMatchResult("luka", "pavle", screenshot, "luka"));
  validateMatchResult("luka", "pavle", screenshot, "pavle");
  assert.equal(scoreWinnerSide(scores([0, 6], [7, 6], [7, 6])), "player1");
  assert.equal(scoreWinnerSide(scores([6, 3], [4, 6], [10, 8])), "player1");
  assert.equal(scoreWinnerSide(scores([4, 1])), "player1");
  for (const invalid of [[], scores([0, 0]), scores([6, 6]), scores([6, 1], [1, 6]), scores([-1, 6]), scores([1.5, 6])]) {
    assert.equal(scoreWinnerSide(invalid), null);
    assert.throws(() => validateMatchResult("a", "b", invalid, "a"));
  }
});
