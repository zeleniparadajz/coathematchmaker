import type { SetScore } from "../models/Match";
import { AppError } from "../middleware/errorHandler";

export function scoreWinnerSide(sets: SetScore[]): "player1" | "player2" | null {
  if (!sets.length) return null;
  let difference = 0;
  for (const set of sets) {
    if (!Number.isSafeInteger(set.player1Games) || !Number.isSafeInteger(set.player2Games) ||
      set.player1Games < 0 || set.player2Games < 0 || set.player1Games === set.player2Games) return null;
    difference += set.player1Games > set.player2Games ? 1 : -1;
  }
  return difference === 0 ? null : difference > 0 ? "player1" : "player2";
}

export function validateMatchResult(player1: string, player2: string, sets: SetScore[], winner?: string): void {
  // League formats may use short sets or a match tie-break; compare sets, not total games.
  const side = scoreWinnerSide(sets);
  if (!side) {
    throw new AppError(400, "Rezultat mora imati završene setove i više osvojenih setova za jednog igrača ili tim.");
  }
  if (winner !== (side === "player1" ? player1 : player2)) {
    throw new AppError(400, "Pobjednik se ne slaže sa rezultatom setova. Provjerite rezultat.");
  }
}
