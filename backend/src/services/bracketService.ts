import { Types } from "mongoose";
import { Match } from "../models/Match";
import { Tournament } from "../models/Tournament";
import { AppError } from "../middleware/errorHandler";

export const roundLabelForSize = (size: number): string => {
  if (size === 2) return "F";
  if (size === 4) return "SF";
  if (size === 8) return "QF";
  return `R${size}`;
};

const nextPowerOfTwo = (value: number): number => {
  let size = 1;
  while (size < value) size *= 2;
  return size;
};

const previousPowerOfTwo = (value: number): number => {
  let size = 1;
  while (size * 2 <= value) size *= 2;
  return size;
};

const createPairingMatches = async (
  tournamentId: Types.ObjectId,
  players: string[],
  round: string,
  friendly: boolean
): Promise<Types.ObjectId[]> => {
  const createdMatchIds: Types.ObjectId[] = [];

  for (let i = 0; i + 1 < players.length; i += 2) {
    const match = await Match.create({
      tournament: tournamentId,
      player1: players[i],
      player2: players[i + 1],
      round,
      status: "accepted",
      acceptedAt: new Date(),
      friendly
    });
    createdMatchIds.push(match._id);
  }

  return createdMatchIds;
};

export const generateTournamentDraw = async (tournamentId: string) => {
  const tournament = await Tournament.findById(tournamentId);

  if (!tournament) {
    throw new AppError(404, "Turnir nije pronađen.");
  }

  if (tournament.matches.length > 0) {
    throw new AppError(400, "Žrijeb turnira je već formiran.");
  }

  const players = tournament.participants.map((id) => id.toString());

  if (players.length < 2) {
    throw new AppError(400, "Za formiranje žrijeba potrebna su najmanje dva igrača.");
  }

  const createdMatchIds: Types.ObjectId[] = [];
  const byes: string[] = [];

  if (tournament.format === "round_robin") {
    for (let i = 0; i < players.length; i += 1) {
      for (let j = i + 1; j < players.length; j += 1) {
        const match = await Match.create({
          tournament: tournament._id,
          player1: players[i],
          player2: players[j],
          round: "RR",
          status: "accepted",
          acceptedAt: new Date(),
          friendly: tournament.friendly
        });
        createdMatchIds.push(match._id);
      }
    }

    tournament.matches = createdMatchIds;
    tournament.drawGeneratedAt = new Date();
    tournament.status = "active";
    await tournament.save();
    return { tournament, byes, matches: createdMatchIds };
  }

  if (tournament.format === "group_knockout") {
    const groupSize = players.length < 8 ? players.length : 4;
    const groups: string[][] = [];

    for (let i = 0; i < players.length; i += groupSize) {
      groups.push(players.slice(i, i + groupSize));
    }

    for (let groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
      const group = groups[groupIndex];
      const round = `G${groupIndex + 1}`;

      for (let i = 0; i < group.length; i += 1) {
        for (let j = i + 1; j < group.length; j += 1) {
          const match = await Match.create({
            tournament: tournament._id,
            player1: group[i],
            player2: group[j],
            round,
            status: "accepted",
            acceptedAt: new Date(),
            friendly: tournament.friendly
          });
          createdMatchIds.push(match._id);
        }
      }
    }

    tournament.matches = createdMatchIds;
    tournament.drawGeneratedAt = new Date();
    tournament.status = "active";
    await tournament.save();
    return { tournament, byes, matches: createdMatchIds };
  }

  if (tournament.format === "swiss") {
    tournament.matches = await createPairingMatches(tournament._id, players, "SW1", tournament.friendly);
    tournament.drawGeneratedAt = new Date();
    tournament.status = "active";
    await tournament.save();
    return { tournament, byes, matches: tournament.matches };
  }

  if (tournament.format === "double_elimination" || tournament.format === "compass") {
    const bracketSize = nextPowerOfTwo(players.length);
    const roundPrefix = tournament.format === "double_elimination" ? "W" : "C";
    const round = `${roundPrefix}-${roundLabelForSize(bracketSize)}`;
    const slots = [...players];

    while (slots.length < bracketSize) {
      slots.push("BYE");
    }

    for (let i = 0; i < slots.length; i += 2) {
      const player1 = slots[i];
      const player2 = slots[i + 1];

      if (player1 === "BYE" || player2 === "BYE") {
        byes.push(player1 === "BYE" ? player2 : player1);
        continue;
      }

      const match = await Match.create({
        tournament: tournament._id,
        player1,
        player2,
        round,
        status: "accepted",
        acceptedAt: new Date(),
        friendly: tournament.friendly
      });
      createdMatchIds.push(match._id);
    }

    tournament.matches = createdMatchIds;
    tournament.bracketSize = bracketSize;
    tournament.drawGeneratedAt = new Date();
    tournament.status = "active";
    await tournament.save();
    return { tournament, byes, matches: createdMatchIds };
  }

  if (tournament.format === "qualification" && players.length > 4) {
    const mainDrawSize = previousPowerOfTwo(players.length);
    const qualificationSpots = players.length - mainDrawSize;
    const qualificationPlayerCount = qualificationSpots * 2;
    const qualificationPlayers = players.slice(-qualificationPlayerCount);

    for (let i = 0; i < qualificationPlayers.length; i += 2) {
      const match = await Match.create({
        tournament: tournament._id,
        player1: qualificationPlayers[i],
        player2: qualificationPlayers[i + 1],
        round: "Q",
        status: "accepted",
        acceptedAt: new Date(),
        friendly: tournament.friendly
      });
      createdMatchIds.push(match._id);
    }

    tournament.matches = createdMatchIds;
    tournament.bracketSize = mainDrawSize;
    tournament.drawGeneratedAt = new Date();
    tournament.status = "active";
    await tournament.save();

    return { tournament, byes, matches: createdMatchIds };
  }

  const bracketSize = nextPowerOfTwo(players.length);
  const round = roundLabelForSize(bracketSize);
  const slots = [...players];

  while (slots.length < bracketSize) {
    slots.push("BYE");
  }

  for (let i = 0; i < slots.length; i += 2) {
    const player1 = slots[i];
    const player2 = slots[i + 1];

    if (player1 === "BYE" || player2 === "BYE") {
      byes.push(player1 === "BYE" ? player2 : player1);
      continue;
    }

    const match = await Match.create({
      tournament: tournament._id,
      player1,
      player2,
      round,
      status: "accepted",
      acceptedAt: new Date(),
      friendly: tournament.friendly
    });
    createdMatchIds.push(match._id);
  }

  tournament.matches = createdMatchIds;
  tournament.bracketSize = bracketSize;
  tournament.drawGeneratedAt = new Date();
  tournament.status = "active";
  await tournament.save();

  return { tournament, byes, matches: createdMatchIds };
};

const roundOrder = ["Q", "R32", "R16", "QF", "SF", "F"];

const nextRoundLabel = (round: string): string | null => {
  const index = roundOrder.indexOf(round);
  return index === -1 || index === roundOrder.length - 1 ? null : roundOrder[index + 1];
};

const directEntrantsAfterQualification = (
  participantIds: string[],
  qualificationMatches: Array<{ player1: Types.ObjectId; player2: Types.ObjectId }>
): string[] => {
  const qualificationPlayerIds = new Set<string>();

  for (const match of qualificationMatches) {
    qualificationPlayerIds.add(match.player1.toString());
    qualificationPlayerIds.add(match.player2.toString());
  }

  return participantIds.filter((id) => !qualificationPlayerIds.has(id));
};

export const advanceTournamentRound = async (tournamentId: string) => {
  const tournament = await Tournament.findById(tournamentId);

  if (!tournament) {
    throw new AppError(404, "Turnir nije pronađen.");
  }

  const matches = await Match.find({ tournament: tournament._id }).sort({ createdAt: 1 });
  const rounds = roundOrder.filter((round) => matches.some((match) => match.round === round));
  const currentRound = rounds.find((round) => {
    const roundMatches = matches.filter((match) => match.round === round);
    const nextRound = nextRoundLabel(round);
    return nextRound && roundMatches.length > 0 && !matches.some((match) => match.round === nextRound);
  });

  if (!currentRound) {
    const final = matches.find((match) => match.round === "F");
    if (final?.status === "confirmed" && final.winner) {
      tournament.status = "finished";
      tournament.winner = final.winner;
      await tournament.save();
      return { tournament, matchesCreated: [], winner: final.winner };
    }

    throw new AppError(400, "Nijedna runda nije spremna za nastavak takmičenja.");
  }

  const currentMatches = matches.filter((match) => match.round === currentRound);

  if (currentMatches.some((match) => match.status !== "confirmed" || !match.winner)) {
    throw new AppError(400, "Prije prelaska u narednu rundu potrebno je potvrditi sve mečeve tekuće runde.");
  }

  let winners = currentMatches.map((match) => match.winner!.toString());
  let nextRound = nextRoundLabel(currentRound);

  if (currentRound === "Q") {
    const directEntrants = directEntrantsAfterQualification(
      tournament.participants.map((id) => id.toString()),
      currentMatches
    );
    winners = [...directEntrants, ...winners];
    nextRound = roundLabelForSize(winners.length);
  }

  if (!nextRound) {
    throw new AppError(400, "Poslije finala nema naredne runde.");
  }

  const createdMatchIds: Types.ObjectId[] = [];

  for (let i = 0; i < winners.length; i += 2) {
    if (!winners[i + 1]) {
      continue;
    }

    const match = await Match.create({
      tournament: tournament._id,
      player1: winners[i],
      player2: winners[i + 1],
      round: nextRound,
      status: "accepted",
      acceptedAt: new Date(),
      friendly: tournament.friendly
    });
    createdMatchIds.push(match._id);
  }

  tournament.matches.push(...createdMatchIds);
  await tournament.save();

  return { tournament, matchesCreated: createdMatchIds };
};
