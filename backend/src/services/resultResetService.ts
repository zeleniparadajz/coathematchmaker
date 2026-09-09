import { Types } from "mongoose";
import { Match, type MatchAttrs } from "../models/Match";
import { Tournament } from "../models/Tournament";
import { AppError } from "../middleware/errorHandler";
import { applyMatchStatDelta } from "./rankingService";
import { roundOrder } from "./bracketService";

export async function reopenConfirmedResult(match: MatchAttrs & { _id: Types.ObjectId }, actor: Types.ObjectId, note?: string, legacyWinPoints?: number) {
  if (!match.resultReset && (match.status !== "confirmed" || !match.statsApplied)) {
    throw new AppError(409, "Meč je u međuvremenu promijenjen. Osvježite prikaz.");
  }
  const tournament = match.tournament ? await Tournament.findById(match.tournament) : null;
  let laterRoundExists = false;
  if (tournament && !tournament.knockoutSize && tournament.format !== "round_robin") {
    const rounds = await Match.distinct("round", { tournament: tournament._id });
    const current = roundOrder.indexOf(match.round);
    // Generated elimination rounds use the same ordering as bracket advancement.
    // Other formats do not persist a dependency graph, so keep cross-round edits locked.
    laterRoundExists = current >= 0
      ? rounds.some((round) => roundOrder.indexOf(round) > current)
      : rounds.some((round) => round !== match.round);
  }
  if (!match.resultReset && (tournament?.winner || laterRoundExists || (tournament?.knockoutStartedAt &&
    (match.round === "RR" || !tournament.knockoutRounds.at(-1)?.matchIds.some((id) => id.equals(match._id)))))) {
    throw new AppError(400, "Ovaj rezultat utiče na već formiranu završnicu ili pobjednika turnira. Prvo je potrebno vratiti zavisne faze turnira.");
  }
  const points = match.friendly ? 0 : match.statsWinPoints ?? legacyWinPoints;
  if (points === undefined && !match.resultReset) {
    throw new AppError(400, "Za ovaj stariji meč unesite broj poena koji je tada dodijeljen za pobjedu.");
  }
  const pending = await Match.findOneAndUpdate(
    { _id: match._id, status: "confirmed", statsApplied: true, resultReset: { $exists: false } },
    { $set: { status: "disputed", resultReset: { id: new Types.ObjectId(), points: points ?? 0, actor, note } } },
    { new: true }
  ).select("+resultReset +statsApplied");
  const current = pending ?? await Match.findById(match._id).select("+resultReset +statsApplied");
  if (!current?.resultReset) throw new AppError(409, "Meč je u međuvremenu promijenjen. Osvježite prikaz.");
  const operation = current.resultReset;
  await applyMatchStatDelta(current, operation.id, operation.points, -1);
  await Match.updateOne({ _id: current._id, "resultReset.id": operation.id }, {
    $push: { resultHistory: { sets: current.sets, winner: current.winner, status: "confirmed",
      actor: operation.actor, note: operation.note, changedAt: new Date(), winPoints: operation.points } },
    $set: { status: "accepted", sets: [], statsApplied: false, acceptedAt: current.acceptedAt ?? new Date(),
      adminResolvedBy: operation.actor, adminResolutionNote: operation.note },
    $unset: { winner: "", resultSubmittedBy: "", resultSubmittedAt: "", resultConfirmedBy: "", confirmedAt: "",
      disputedAt: "", rejectedAt: "", cancelledAt: "", resultReset: "", statsOperationId: "", statsWinPoints: "" }
  });
}
