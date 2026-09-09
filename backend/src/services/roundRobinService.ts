import { Types } from "mongoose";
import { Tournament, type TournamentAttrs } from "../models/Tournament";
import { Match, type MatchAttrs } from "../models/Match";
import { Player } from "../models/Player";
import { AppError } from "../middleware/errorHandler";
import { roundLabelForSize } from "./bracketService";
import { leagueCompletionProblem, leagueRankingRules, roundRobinTable, seededPairs } from "./roundRobinRules";
import { getLeagueSettings } from "./settingsService";

type TournamentDoc = TournamentAttrs & { _id: Types.ObjectId };

export function validateKnockoutSettings(tournament: Pick<TournamentAttrs, "format" | "discipline" | "knockoutSize">) {
  if (tournament.knockoutSize && (tournament.format !== "round_robin" || tournament.discipline !== "singles")) {
    throw new AppError(400, "Knockout zavrsnica je dostupna za round-robin singl turnire.");
  }
}

export async function roundRobinState(tournament: TournamentDoc) {
  const matches = await Match.find({ tournament: tournament._id });
  const ids = tournament.participants.map(String);
  const standings = roundRobinTable(ids, matches);
  const seeds = tournament.knockoutStartedAt
    ? tournament.knockoutSeeds.map(String)
    : standings.slice(0, tournament.knockoutSize || 0).map((row) => row.playerId);
  const knownMatches = new Set(tournament.knockoutRounds.flatMap((r) => r.matchIds.map(String)));
  const problem = tournament.status === "finished" ? "Turnir je zavrsen." :
    tournament.winner && !tournament.knockoutStartedAt ? "Turnir vec ima odredjenog pobjednika." :
    !tournament.knockoutSize ? "Knockout zavrsnica nije ukljucena." :
    ids.length < tournament.knockoutSize ? "Nema dovoljno ucesnika za izabranu zavrsnicu." :
    matches.some((m) => m.round === "RR" && (m.discipline !== "singles" || m.player1Partner || m.player2Partner)) ? "Zavrsnica zahtijeva singl ligaske meceve." :
    matches.some((m) => m.round !== "RR" && !knownMatches.has(String(m._id))) ? "Turnir vec ima meceve van ligaske faze." :
    leagueCompletionProblem(ids, matches);
  const current = tournament.knockoutRounds.at(-1);
  const currentMatches = current ? current.matchIds.map((id) => matches.find((m) => String(m._id) === String(id))) : [];
  const ready = currentMatches.length > 0 && currentMatches.every((m) => m?.status === "confirmed" && m.winner);
  return {
    standings, rankingRules: leagueRankingRules, seeds,
    pairs: seeds.length === tournament.knockoutSize && seeds.length >= 2 ? seededPairs(seeds) : [],
    canStart: !tournament.knockoutStartedAt && !problem,
    blockedReason: problem,
    started: Boolean(tournament.knockoutStartedAt),
    currentRound: current?.round ?? null,
    canAdvance: ready && tournament.status !== "finished",
    needsRepair: currentMatches.some((m) => !m),
    finished: tournament.status === "finished",
    winnerId: tournament.winner?.toString() ?? null
  };
}

// Match IDs are reserved in one atomic tournament update. Retrying materialization
// after a dropped connection uses those same IDs and never overwrites results.
async function materializeRounds(tournament: TournamentDoc) {
  let pairs = seededPairs(tournament.knockoutSeeds.map(String));
  for (const plan of tournament.knockoutRounds) {
    for (const [i, id] of plan.matchIds.entries()) {
      if (!pairs[i]) throw new AppError(409, "Knockout parovi nijesu spremni.");
      try {
        await Match.updateOne({ _id: id }, { $setOnInsert: {
          tournament: tournament._id, player1: pairs[i][0], player2: pairs[i][1],
          discipline: "singles", round: plan.round, status: "accepted", acceptedAt: new Date(), friendly: tournament.friendly
        } }, { upsert: true });
      } catch (error) {
        if ((error as { code?: number }).code !== 11000) throw error;
      }
    }
    await Tournament.updateOne({ _id: tournament._id }, { $addToSet: { matches: { $each: plan.matchIds } } });
    const matches = await Match.find({ _id: { $in: plan.matchIds } });
    const winners = plan.matchIds.map((id) => matches.find((m) => String(m._id) === String(id))?.winner?.toString());
    pairs = [];
    for (let i = 0; i + 1 < winners.length; i += 2) {
      if (winners[i] && winners[i + 1]) pairs.push([winners[i]!, winners[i + 1]!]);
    }
  }
}

export async function startRoundRobinKnockout(id: string, approvedSeeds: string[]) {
  let tournament = await Tournament.findById(id);
  if (!tournament) throw new AppError(404, "Tournament not found");
  validateKnockoutSettings(tournament);
  const state = await roundRobinState(tournament);
  if (approvedSeeds.join(",") !== state.seeds.join(",")) {
    throw new AppError(409, "Tabela ili broj ucesnika su promijenjeni. Ponovo pregledajte parove.");
  }
  if (!tournament.knockoutStartedAt) {
    if (!state.canStart) throw new AppError(400, state.blockedReason!);
    const plan = { round: roundLabelForSize(approvedSeeds.length),
      matchIds: Array.from({ length: approvedSeeds.length / 2 }, () => new Types.ObjectId()) };
    const updated = await Tournament.findOneAndUpdate({
      _id: id, knockoutStartedAt: { $exists: false }, knockoutSize: tournament.knockoutSize,
      format: "round_robin", discipline: "singles", status: { $ne: "finished" }, participants: tournament.participants
    }, { $set: { knockoutSeeds: approvedSeeds, knockoutStartedAt: new Date(), knockoutRounds: [plan], status: "active" } }, { new: true });
    tournament = updated ?? await Tournament.findById(id);
    if (!tournament?.knockoutStartedAt || tournament.knockoutSeeds.map(String).join(",") !== approvedSeeds.join(",")) {
      throw new AppError(409, "Turnir je izmijenjen. Osvjezite pregled.");
    }
  }
  await materializeRounds(tournament);
  return roundRobinState(tournament);
}

export async function advanceRoundRobinKnockout(id: string, expectedRound: string) {
  const tournament = await Tournament.findById(id);
  if (!tournament?.knockoutStartedAt) throw new AppError(400, "Knockout zavrsnica nije pokrenuta.");
  const current = tournament.knockoutRounds.at(-1)!;
  if (current.round !== expectedRound) throw new AppError(409, "Runda je vec promijenjena. Osvjezite pregled.");
  await materializeRounds(tournament);
  const matches = await Match.find({ _id: { $in: current.matchIds } });
  if (matches.length !== current.matchIds.length || matches.some((m) => m.status !== "confirmed" || !m.winner)) {
    throw new AppError(400, "Svi mecevi ove runde moraju imati potvrdjen rezultat.");
  }
  if (current.round === "F") {
    const winner = matches[0].winner!;
    const settings = await getLeagueSettings();
    const finished = await Tournament.findOneAndUpdate({ _id: id, winner: { $exists: false } },
      { $set: { status: "finished", winner } });
    if (finished && !finished.friendly) {
      await Player.updateOne({ _id: winner }, { $inc: { tournamentsWon: 1, totalPoints: settings.tournamentWinPoints } });
    }
  } else {
    const next = { round: roundLabelForSize(current.matchIds.length),
      matchIds: Array.from({ length: current.matchIds.length / 2 }, () => new Types.ObjectId()) };
    await Tournament.updateOne({ _id: id, "knockoutRounds.round": { $ne: next.round }, status: { $ne: "finished" } },
      { $push: { knockoutRounds: next } });
    await materializeRounds((await Tournament.findById(id))!);
  }
  return roundRobinState((await Tournament.findById(id))!);
}

export async function ensureManualLeagueMatch(tournamentId: string | undefined, round: string, discipline = "singles") {
  if (!tournamentId) return;
  const tournament = await Tournament.findById(tournamentId);
  if (tournament?.knockoutSize && (tournament.knockoutStartedAt || round !== "RR" || discipline !== "singles")) {
    throw new AppError(400, "Knockout meceve formira zavrsnica. Rucni unos je moguc samo za ligasku fazu prije zavrsnice.");
  }
}

export async function protectHybridMatch(match: MatchAttrs, body: Record<string, unknown>) {
  if (!match.tournament) return;
  const tournament = await Tournament.findById(match.tournament);
  if (!tournament?.knockoutSize) return;
  for (const key of ["player1", "player2", "player1Partner", "player2Partner", "tournament", "round", "discipline", "friendly"] as const) {
    if (body[key] !== undefined && String(body[key]) !== String(match[key])) {
      throw new AppError(400, "Ucesnici i faza ligaskog/knockout meca su zakljucani.");
    }
  }
  if (match.status === "confirmed") {
    if ((body.winner !== undefined && String(body.winner) !== String(match.winner)) ||
      (body.status !== undefined && body.status !== match.status) ||
      (body.sets !== undefined && JSON.stringify(body.sets) !== JSON.stringify(match.sets.map((s) => ({ player1Games: s.player1Games, player2Games: s.player2Games }))))) {
      throw new AppError(400, "Potvrdjeni rezultati lige i zavrsnice su zakljucani.");
    }
  }
}
