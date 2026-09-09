import { Types } from "mongoose";
import { Match, type MatchAttrs } from "../models/Match";
import { Player } from "../models/Player";
import { Tournament } from "../models/Tournament";
import { AppError } from "../middleware/errorHandler";
import { getLeagueSettings } from "./settingsService";
import { validateMatchResult } from "./matchResultService";

export const applyConfirmedMatchStats = async (input: MatchAttrs & { _id: Types.ObjectId }): Promise<void> => {
  let match = await Match.findById(input._id).select("+statsApplied +statsOperationId +resultReset");
  if (!match || match.status !== "confirmed" || !match.winner || match.statsApplied || match.resultReset) return;
  const winnerId = match.winner.toString();
  const player1Id = match.player1.toString();
  const player2Id = match.player2.toString();
  validateMatchResult(player1Id, player2Id, match.sets, winnerId);
  if (winnerId !== player1Id && winnerId !== player2Id) {
    throw new AppError(400, "Pobjednik mora biti jedan od igrača ili timova u meču.");
  }

  if (!match.statsOperationId) {
    const settings = await getLeagueSettings();
    await Match.updateOne({ _id: match._id, status: "confirmed", statsApplied: { $ne: true }, statsOperationId: { $exists: false } },
      { $set: { statsOperationId: new Types.ObjectId(), statsWinPoints: match.friendly ? 0 : settings.matchWinPoints } });
    match = (await Match.findById(match._id).select("+statsApplied +statsOperationId"))!;
  }
  if (!match.statsOperationId || match.statsApplied || match.status !== "confirmed") return;
  await applyMatchStatDelta(match, match.statsOperationId, match.statsWinPoints!, 1);
  await Match.updateOne({ _id: match._id, statsOperationId: match.statsOperationId }, { $set: { statsApplied: true } });
};

// The operation marker and counter changes are atomic per player, including retries
// after a failed request. This also works with the existing standalone Mongo server.
export async function applyMatchStatDelta(match: MatchAttrs, operation: Types.ObjectId, points: number, direction: 1 | -1) {
  if (match.friendly) return;
  const firstWins = String(match.winner) === String(match.player1);
  const winners = firstWins ? [match.player1, match.player1Partner] : [match.player2, match.player2Partner];
  const losers = firstWins ? [match.player2, match.player2Partner] : [match.player1, match.player1Partner];
  for (const [ids, increment] of [
    [winners, { wins: direction, matchesPlayed: direction, totalPoints: direction * points }],
    [losers, { losses: direction, matchesPlayed: direction }]
  ] as const) {
    for (const id of ids.filter(Boolean)) {
      await Player.updateOne({ _id: id, matchStatOperations: { $ne: operation } },
        { $inc: increment, $addToSet: { matchStatOperations: operation } });
    }
  }
}

export const awardTournamentWin = async (tournamentId: string, winnerId: string): Promise<void> => {
  let tournament = await Tournament.findById(tournamentId).select("+awardApplied +awardOperationId +awardWinPoints");

  if (!tournament) {
    throw new AppError(404, "Turnir nije pronađen.");
  }

  if (!tournament.participants.some((participantId) => participantId.toString() === winnerId)) {
    throw new AppError(400, "Pobjednik mora biti učesnik turnira.");
  }

  if (tournament.winner && tournament.winner.toString() !== winnerId) {
    throw new AppError(409, "Turnir već ima drugog pobjednika. Prvo ispravite završni rezultat.");
  }
  if (!tournament.winner) {
    const settings = await getLeagueSettings();
    await Tournament.updateOne({ _id: tournament._id, winner: { $exists: false } }, {
      $set: { status: "finished", winner: new Types.ObjectId(winnerId), awardApplied: false,
        awardOperationId: new Types.ObjectId(), awardWinPoints: tournament.friendly ? 0 : settings.tournamentWinPoints }
    });
    tournament = (await Tournament.findById(tournament._id).select("+awardApplied +awardOperationId +awardWinPoints"))!;
  }
  // Legacy winners without a recorded operation must not receive a second award.
  if (!tournament.awardOperationId || tournament.awardApplied) return;
  if (!tournament.friendly) {
    await Player.updateOne({ _id: tournament.winner, matchStatOperations: { $ne: tournament.awardOperationId } }, {
      $inc: { tournamentsWon: 1, totalPoints: tournament.awardWinPoints! },
      $addToSet: { matchStatOperations: tournament.awardOperationId }
    });
  }
  await Tournament.updateOne({ _id: tournament._id, awardOperationId: tournament.awardOperationId }, { $set: { awardApplied: true } });
};

export const getGeneralRanking = async () => {
  return Player.find({ active: true })
    .select("-password")
    .sort({ totalPoints: -1, wins: -1, lastName: 1, firstName: 1, _id: 1 });
};

export const getTournamentRanking = async (tournamentId: string) => {
  const tournament = await Tournament.findById(tournamentId).populate("participants", "-password");

  if (!tournament) {
    throw new AppError(404, "Turnir nije pronađen.");
  }

  const matches = await Match.find({
    tournament: tournamentId,
    status: "confirmed",
    winner: { $exists: true }
  });

  const stats = new Map<string, { player: unknown; wins: number; losses: number; matchesPlayed: number; points: number }>();

  for (const player of tournament.participants as unknown[]) {
    const id = (player as { _id: Types.ObjectId })._id.toString();
    stats.set(id, { player, wins: 0, losses: 0, matchesPlayed: 0, points: 0 });
  }

  for (const match of matches) {
    const settings = await getLeagueSettings();
    const winnerId = match.winner?.toString();
    const winnerIds = winnerId === match.player1.toString()
      ? [match.player1, match.player1Partner].filter(Boolean).map((id) => id!.toString())
      : [match.player2, match.player2Partner].filter(Boolean).map((id) => id!.toString());
    const loserIds = winnerId === match.player1.toString()
      ? [match.player2, match.player2Partner].filter(Boolean).map((id) => id!.toString())
      : [match.player1, match.player1Partner].filter(Boolean).map((id) => id!.toString());

    for (const id of winnerIds) {
      if (!stats.has(id)) continue;
      const winnerStats = stats.get(id)!;
      winnerStats.wins += 1;
      winnerStats.matchesPlayed += 1;
      if (!match.friendly) {
        winnerStats.points += settings.matchWinPoints;
      }
    }

    for (const id of loserIds) {
      if (!stats.has(id)) continue;
      const loserStats = stats.get(id)!;
      loserStats.losses += 1;
      loserStats.matchesPlayed += 1;
    }
  }

  if (tournament.winner && !tournament.friendly && stats.has(tournament.winner.toString())) {
    const settings = await getLeagueSettings();
    stats.get(tournament.winner.toString())!.points += settings.tournamentWinPoints;
  }

  return [...stats.values()].sort((a, b) => b.points - a.points || b.wins - a.wins);
};
