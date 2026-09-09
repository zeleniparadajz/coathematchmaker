import { createHash } from "node:crypto";
import fs from "node:fs/promises";
import path from "node:path";
import { Types } from "mongoose";
import { Match } from "../models/Match";
import { Tournament } from "../models/Tournament";
import { Player } from "../models/Player";
import { DeletionJob, type DeletionJobAttrs } from "../models/DeletionJob";
import { AppError } from "../middleware/errorHandler";
import { roundOrder } from "./bracketService";

type Kind = "match" | "tournament";
type DeleteInput = {
  revision: string;
  legacyMatchPoints?: Record<string, number>;
  legacyTournamentAwardApplied?: boolean;
  legacyTournamentPoints?: number;
};

async function deletionState(kind: Kind, id: string) {
  if (!Types.ObjectId.isValid(id)) throw new AppError(400, "Identifikator nije ispravan.");
  const matches = await Match.find(kind === "tournament" ? { tournament: id } : { _id: id })
    .select("+statsApplied +statsOperationId +resultReset").sort({ _id: 1 });
  const tournamentId = kind === "tournament" ? id : matches[0]?.tournament;
  const tournament = tournamentId ? await Tournament.findById(tournamentId).select("+awardApplied +awardOperationId +awardWinPoints") : null;
  if (kind === "tournament" ? !tournament : !matches.length) {
    throw new AppError(404, kind === "tournament" ? "Turnir nije pronađen." : "Meč nije pronađen.");
  }
  let blockedReason: string | null = null;
  if (kind === "match" && tournament) {
    const match = matches[0];
    const rounds = await Match.distinct("round", { tournament: tournament._id });
    const current = roundOrder.indexOf(match.round);
    const later = current >= 0 && rounds.some((round) => roundOrder.indexOf(round) > current);
    const generated = Boolean(tournament.drawGeneratedAt || tournament.matches.some((mid) => mid.equals(match._id)));
    const knockout = tournament.knockoutRounds.find((r) => r.matchIds.some((mid) => mid.equals(match._id)));
    if (later || (tournament.knockoutStartedAt && match.round === "RR") ||
      (knockout && (knockout.round !== "F" || tournament.knockoutRounds.at(-1)?.round !== "F")) ||
      (generated && tournament.format !== "round_robin" && match.round !== "F")) {
      blockedReason = "Meč je dio formiranog žrijeba ili utiče na kasnije runde. Možete ispraviti rezultat ili obrisati cijeli turnir sa svim mečevima.";
    }
  }
  const revision = createHash("sha256").update(JSON.stringify({ kind, tournament: tournament?.toObject(),
    matches: matches.map((m) => m.toObject()), blockedReason })).digest("hex");
  return { matches, tournament, revision, blockedReason };
}

export async function deletionPreview(kind: Kind, id: string) {
  const state = await deletionState(kind, id);
  const legacy = state.matches.filter((m) => !m.friendly && m.statsApplied && m.statsWinPoints === undefined && !m.resultReset);
  const playerIds = legacy.flatMap((m) => [m.player1, m.player2]);
  const players = await Player.find({ _id: { $in: playerIds } }).select("firstName lastName");
  const name = (id: Types.ObjectId) => {
    const player = players.find((p) => p._id.equals(id));
    return player ? `${player.firstName} ${player.lastName}` : String(id);
  };
  return {
    revision: state.revision,
    matchCount: state.matches.length,
    imageCount: state.matches.reduce((n, m) => n + m.images.length, 0) + (kind === "tournament" ? state.tournament?.images.length ?? 0 : 0),
    blockedReason: state.blockedReason,
    clearsTournamentWinner: kind === "match" && Boolean(state.tournament?.winner),
    legacyMatches: legacy.map((m) => ({ id: m.id, label: `${name(m.player1)} - ${name(m.player2)}` })),
    needsLegacyTournamentAward: Boolean(state.tournament?.winner && !state.tournament.friendly && state.tournament.awardApplied === undefined && !state.tournament.awardOperationId)
  };
}

export async function deleteCompetition(kind: Kind, id: string, actor: Types.ObjectId, input: DeleteInput) {
  const key = `${kind}:${id}`;
  let job = await DeletionJob.findById(key);
  if (!job) {
    const { matches, tournament, revision, blockedReason } = await deletionState(kind, id);
    if (blockedReason) throw new AppError(409, blockedReason);
    if (revision !== input.revision) throw new AppError(409, "Podaci su promijenjeni. Ponovo otvorite potvrdu brisanja.");
    const deltas: { player: Types.ObjectId; operation: Types.ObjectId; wins?: number; losses?: number; matchesPlayed?: number; tournamentsWon?: number; totalPoints?: number }[] = [];
    const players = await Player.find({ _id: { $in: matches.flatMap((m) => [m.player1, m.player2, m.player1Partner, m.player2Partner]) } }).select("+matchStatOperations");
    const hadOperation = (player: Types.ObjectId, operation?: Types.ObjectId) =>
      Boolean(operation && players.find((p) => p._id.equals(player))?.matchStatOperations.some((op) => op.equals(operation)));
    for (const match of matches) {
      if (match.friendly || (!match.statsApplied && !match.statsOperationId)) continue;
      const points = match.resultReset?.points ?? match.statsWinPoints ?? input.legacyMatchPoints?.[match.id];
      if (points === undefined) throw new AppError(400, "Unesite ranije dodijeljene poene za svaki označeni meč.");
      if (!match.winner || (![match.player1, match.player2].some((pid) => pid.equals(match.winner!)))) {
        throw new AppError(409, "Statistika meča nema ispravnog pobjednika. Prvo ispravite podatke meča.");
      }
      const firstWins = match.winner.equals(match.player1);
      const sides = [[match.player1, match.player1Partner], [match.player2, match.player2Partner]];
      for (const [index, side] of sides.entries()) for (const player of side.filter((pid): pid is Types.ObjectId => Boolean(pid))) {
        // Reverse only applied increments, including interrupted confirms/resets.
        if (match.statsOperationId && !hadOperation(player, match.statsOperationId)) continue;
        if (match.resultReset && hadOperation(player, match.resultReset.id)) continue;
        const won = firstWins === (index === 0);
        deltas.push({ player, operation: new Types.ObjectId(), matchesPlayed: -1,
          ...(won ? { wins: -1, totalPoints: -points } : { losses: -1 }) });
      }
    }
    if (tournament?.winner && !tournament.friendly) {
      const winner = await Player.findById(tournament.winner).select("+matchStatOperations");
      let applied = tournament.awardOperationId
        ? winner?.matchStatOperations.some((op) => op.equals(tournament.awardOperationId!)) ?? false
        : tournament.awardApplied;
      if (applied === undefined) applied = input.legacyTournamentAwardApplied;
      if (applied === undefined) throw new AppError(400, "Potvrdite da li su ranije dodijeljeni titula i poeni za turnir.");
      if (applied) {
        const points = tournament.awardWinPoints ?? input.legacyTournamentPoints;
        if (points === undefined) throw new AppError(400, "Unesite ranije dodijeljene poene za osvajanje turnira.");
        deltas.push({ player: tournament.winner, operation: new Types.ObjectId(), tournamentsWon: -1, totalPoints: -points });
      }
    }
    const totals = new Map<string, Record<string, number>>();
    for (const delta of deltas) {
      const total = totals.get(String(delta.player)) ?? {};
      for (const field of ["wins", "losses", "matchesPlayed", "tournamentsWon", "totalPoints"] as const) {
        total[field] = (total[field] ?? 0) + (delta[field] ?? 0);
      }
      totals.set(String(delta.player), total);
    }
    for (const player of await Player.find({ _id: { $in: [...totals.keys()] } })) {
      if (Object.entries(totals.get(player.id)!).some(([field, amount]) => (player.get(field) ?? 0) + amount < 0)) {
        throw new AppError(400, "Poeni ili statistika nisu usklađeni. Provjerite unesene ranije poene i podatke igrača prije brisanja.");
      }
    }
    job = await DeletionJob.create({ _id: key, kind, target: id, actor, matchCount: matches.length,
      matchIds: matches.map((m) => m._id), tournamentId: tournament?._id, clearWinner: Boolean(tournament?.winner),
      deltas, images: [...matches.flatMap((m) => m.images), ...(kind === "tournament" ? tournament?.images ?? [] : [])] });
  }
  await finishDeletion(job);
  return { deleted: true, matchCount: job.matchCount };
}

export function ownedGalleryPath(value: string): string | null {
  if (/^https?:\/\//.test(value)) {
    try {
      const url = new URL(value);
      if (!["coabackapi.zeleniparadajz.me", "161.97.74.146", "localhost"].includes(url.hostname)) return null;
      value = url.pathname;
    } catch { return null; }
  }
  if (!/^\/uploads\/(match-images|tournament-images)\/[a-zA-Z0-9._-]+$/.test(value)) return null;
  if ([".", ".."].includes(path.basename(value))) return null;
  return path.resolve(process.cwd(), value.slice(1));
}

async function finishDeletion(job: DeletionJobAttrs) {
  if (job.completed) return;
  for (const delta of job.deltas) {
    await Player.updateOne({ _id: delta.player, matchStatOperations: { $ne: delta.operation } }, {
      $inc: { wins: delta.wins, losses: delta.losses, matchesPlayed: delta.matchesPlayed,
        tournamentsWon: delta.tournamentsWon, totalPoints: delta.totalPoints },
      $addToSet: { matchStatOperations: delta.operation }
    });
  }
  await Match.deleteMany({ _id: { $in: job.matchIds } });
  if (job.kind === "tournament") {
    await Tournament.deleteOne({ _id: job.target });
  } else if (job.tournamentId) {
    await Tournament.updateOne({ _id: job.tournamentId }, {
      $pull: { matches: { $in: job.matchIds }, knockoutRounds: { matchIds: { $in: job.matchIds } } },
      ...(job.clearWinner ? { $set: { status: "active" }, $unset: { winner: "", awardApplied: "", awardOperationId: "", awardWinPoints: "" } } : {})
    });
    const remaining = await Tournament.findById(job.tournamentId);
    if (remaining && !await Match.exists({ tournament: remaining._id })) {
      await Tournament.updateOne({ _id: remaining._id }, { $unset: { drawGeneratedAt: "", bracketSize: "" } });
    }
    if (remaining?.knockoutStartedAt && !remaining.knockoutRounds.length) {
      await Tournament.updateOne({ _id: remaining._id, knockoutRounds: { $size: 0 } }, {
        $unset: { knockoutStartedAt: "" }, $set: { knockoutSeeds: [], status: "active" }
      });
    }
  }
  if (job.images.length) {
    const referenced = new Set([
      ...await Match.distinct("images"), ...await Tournament.distinct("images"), ...await Player.distinct("profileImage")
    ].map(ownedGalleryPath).filter(Boolean));
    for (const image of new Set(job.images)) {
      const file = ownedGalleryPath(image);
      if (!file || referenced.has(file)) continue;
      await fs.rm(file, { force: true });
    }
  }
  await DeletionJob.updateOne({ _id: job._id }, {
    $set: { completed: true }, $unset: { deltas: "", images: "", matchIds: "", tournamentId: "", clearWinner: "" }
  });
}

export async function resumeDeletions() {
  for (const job of await DeletionJob.find({ completed: false }).sort({ createdAt: 1 })) await finishDeletion(job);
}
