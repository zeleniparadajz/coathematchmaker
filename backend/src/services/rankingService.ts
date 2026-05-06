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
    throw new AppError(400, "Winner must be player1/team1 or player2/team2");
  }

  if (match.friendly) {
    await Match.findByIdAndUpdate(match._id, { statsApplied: true });
    return;
  }

  const winnerIds = winnerId === player1Id
    ? [match.player1, match.player1Partner].filter(Boolean)
    : [match.player2, match.player2Partner].filter(Boolean);
  const loserIds = winnerId === player1Id
    ? [match.player2, match.player2Partner].filter(Boolean)
    : [match.player1, match.player1Partner].filter(Boolean);
  const settings = await getLeagueSettings();
  const winnerIncrement = { wins: 1, matchesPlayed: 1, totalPoints: settings.matchWinPoints };
  const loserIncrement = { losses: 1, matchesPlayed: 1 };

  await Promise.all(
    winnerIds.map((id) =>
      Player.findByIdAndUpdate(id, { $inc: winnerIncrement })
    )
  );

  await Promise.all(
    loserIds.map((id) =>
      Player.findByIdAndUpdate(id, { $inc: loserIncrement })
    )
  );

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
    if (!tournament.friendly) {
      await Player.findByIdAndUpdate(winnerId, {
        $inc: { tournamentsWon: 1, totalPoints: settings.tournamentWinPoints }
      });
    }
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
