import { Types } from "mongoose";
import { Match, type MatchAttrs } from "../models/Match";
import { Player } from "../models/Player";
import { Tournament } from "../models/Tournament";
import { AppError } from "../middleware/errorHandler";
import { getLeagueSettings } from "./settingsService";

export const applyConfirmedMatchStats = async (match: MatchAttrs & { _id: Types.ObjectId }): Promise<void> => {
  if (match.status !== "confirmed" || !match.winner || match.statsApplied) {
    return;
  }

  const winnerId = match.winner.toString();
  const player1Id = match.player1.toString();
  const player2Id = match.player2.toString();

  if (winnerId !== player1Id && winnerId !== player2Id) {
    throw new AppError(400, "Winner must be player1 or player2");
  }

  const loserId = winnerId === player1Id ? match.player2 : match.player1;
  const settings = await getLeagueSettings();

  await Player.findByIdAndUpdate(match.winner, {
    $inc: { wins: 1, matchesPlayed: 1, totalPoints: settings.matchWinPoints }
  });

  await Player.findByIdAndUpdate(loserId, {
    $inc: { losses: 1, matchesPlayed: 1 }
  });

  await Match.findByIdAndUpdate(match._id, { statsApplied: true });
};

export const awardTournamentWin = async (tournamentId: string, winnerId: string): Promise<void> => {
  const tournament = await Tournament.findById(tournamentId);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  if (!tournament.participants.some((participantId) => participantId.toString() === winnerId)) {
    throw new AppError(400, "Winner must be a participant in the tournament");
  }

  const alreadyHadWinner = Boolean(tournament.winner);

  tournament.status = "finished";
  tournament.winner = new Types.ObjectId(winnerId);
  await tournament.save();

  if (!alreadyHadWinner) {
    const settings = await getLeagueSettings();
    await Player.findByIdAndUpdate(winnerId, {
      $inc: { tournamentsWon: 1, totalPoints: settings.tournamentWinPoints }
    });
  }
};

export const getGeneralRanking = async () => {
  return Player.find({ active: true })
    .select("-password")
    .sort({ totalPoints: -1, wins: -1, lastName: 1, firstName: 1 });
};

export const getTournamentRanking = async (tournamentId: string) => {
  const tournament = await Tournament.findById(tournamentId).populate("participants", "-password");

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
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
    const loserId = winnerId === match.player1.toString() ? match.player2.toString() : match.player1.toString();

    if (winnerId && stats.has(winnerId)) {
      const winnerStats = stats.get(winnerId)!;
      winnerStats.wins += 1;
      winnerStats.matchesPlayed += 1;
      winnerStats.points += settings.matchWinPoints;
    }

    if (stats.has(loserId)) {
      const loserStats = stats.get(loserId)!;
      loserStats.losses += 1;
      loserStats.matchesPlayed += 1;
    }
  }

  if (tournament.winner && stats.has(tournament.winner.toString())) {
    const settings = await getLeagueSettings();
    stats.get(tournament.winner.toString())!.points += settings.tournamentWinPoints;
  }

  return [...stats.values()].sort((a, b) => b.points - a.points || b.wins - a.wins);
};
