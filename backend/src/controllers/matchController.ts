import { z } from "zod";
import { Types } from "mongoose";
import { Match, type MatchStatus } from "../models/Match";
import { Player } from "../models/Player";
import { Tournament } from "../models/Tournament";
import { AppError } from "../middleware/errorHandler";
import { asyncHandler } from "../middleware/asyncHandler";
import { applyConfirmedMatchStats } from "../services/rankingService";
import { getLeagueSettings } from "../services/settingsService";
import { expireInactivePlayers } from "../services/activityService";
import { saveUploadedImage } from "../services/uploadService";
import { locationIdSchema, matchLocationPatch } from "../services/locationService";
import { ensureManualLeagueMatch, protectHybridMatch } from "../services/roundRobinService";

const setScoreSchema = z.object({
  player1Games: z.number().int().min(0),
  player2Games: z.number().int().min(0)
});

const resultSchema = z.object({
  sets: z.array(setScoreSchema).min(1),
  winner: z.string().min(1),
  round: z.string().min(1).optional()
});

export const createMatchSchema = z.object({
  tournament: z.string().min(1).optional(),
  discipline: z.enum(["singles", "doubles"]).default("singles"),
  player1: z.string().min(1),
  player2: z.string().min(1),
  player1Partner: z.string().min(1).optional(),
  player2Partner: z.string().min(1).optional(),
  sets: z.array(setScoreSchema).default([]),
  winner: z.string().optional(),
  round: z.string().min(1).default("Challenge"),
  location: z.string().optional(),
  locationId: locationIdSchema.nullable().optional(),
  scheduledAt: z.coerce.date().optional(),
  friendly: z.boolean().default(false),
  status: z
    .enum(["pending", "accepted", "waiting_confirmation", "confirmed", "rejected", "disputed", "cancelled"])
    .default("pending")
});

export const challengeMatchSchema = z.object({
  opponentId: z.string().min(1),
  partnerId: z.string().min(1).optional(),
  opponentPartnerId: z.string().min(1).optional(),
  discipline: z.enum(["singles", "doubles"]).default("singles"),
  tournamentId: z.string().min(1).optional(),
  round: z.string().min(1).default("Challenge"),
  location: z.string().optional(),
  locationId: locationIdSchema.nullable().optional(),
  scheduledAt: z.coerce.date().optional(),
  friendly: z.boolean().default(false)
});

export const submitResultSchema = resultSchema;

export const updateMatchSchema = createMatchSchema.partial();

export const adminResolveSchema = z.object({
  action: z.enum(["confirm", "reject", "cancel"]),
  sets: z.array(setScoreSchema).optional(),
  winner: z.string().optional(),
  note: z.string().optional()
});

const isAdmin = (role?: string) => role === "admin";

const validateObjectId = (id: string, label: string): void => {
  if (!Types.ObjectId.isValid(id)) {
    throw new AppError(400, `Identifikator za polje ${label} nije ispravan.`);
  }
};

const validateWinner = (player1: string, player2: string, winner?: string): void => {
  if (winner && winner !== player1 && winner !== player2) {
    throw new AppError(400, "Pobjednik mora biti jedan od igrača ili timova u meču.");
  }
};

const ensurePlayersAndTournament = async (
  player1Id: string,
  player2Id: string,
  player1PartnerId?: string,
  player2PartnerId?: string,
  tournamentId?: string
): Promise<void> => {
  const playerIds = [player1Id, player2Id, player1PartnerId, player2PartnerId].filter(Boolean) as string[];

  if (new Set(playerIds).size !== playerIds.length) {
    throw new AppError(400, "Igrači u meču moraju biti različiti.");
  }

  playerIds.forEach((id, index) => validateObjectId(id, `player${index + 1}`));

  const players = await Promise.all(playerIds.map((id) => Player.findById(id)));

  if (players.some((player) => !player)) {
    throw new AppError(404, "Neki od izabranih igrača ne postoje.");
  }

  if (!tournamentId) {
    return;
  }

  validateObjectId(tournamentId, "tournament");
  const tournament = await Tournament.findById(tournamentId);

  if (!tournament) {
    throw new AppError(404, "Turnir nije pronađen.");
  }

  const participantIds = tournament.participants.map((id) => id.toString());

  if (!playerIds.every((id) => participantIds.includes(id))) {
    throw new AppError(400, "Svi igrači u meču moraju biti učesnici turnira.");
  }
};

const ensureScheduledAtWithinTournament = async (
  tournamentId?: string,
  scheduledAt?: Date
): Promise<void> => {
  if (!tournamentId || !scheduledAt) return;

  const tournament = await Tournament.findById(tournamentId);
  if (!tournament) {
    throw new AppError(404, "Turnir nije pronađen.");
  }

  const start = new Date(tournament.startDate);
  start.setHours(0, 0, 0, 0);
  const end = new Date(tournament.endDate);
  end.setHours(23, 59, 59, 999);

  if (scheduledAt < start || scheduledAt > end) {
    throw new AppError(400, "Termin meča mora biti u okviru trajanja turnira.");
  }
};

const matchPlayerIds = (match: {
  player1: Types.ObjectId;
  player2: Types.ObjectId;
  player1Partner?: Types.ObjectId;
  player2Partner?: Types.ObjectId;
}) => [match.player1, match.player2, match.player1Partner, match.player2Partner].filter(Boolean).map((id) => id!.toString());

const ensureParticipantOrAdmin = (match: { player1: Types.ObjectId; player2: Types.ObjectId; player1Partner?: Types.ObjectId; player2Partner?: Types.ObjectId }, userId: string, role?: string): void => {
  if (isAdmin(role)) {
    return;
  }

  const isParticipant = matchPlayerIds(match).includes(userId);

  if (!isParticipant) {
    throw new AppError(403, "Možete upravljati samo svojim mečevima.");
  }
};

const getActorSide = (match: { player1: Types.ObjectId; player2: Types.ObjectId; player1Partner?: Types.ObjectId; player2Partner?: Types.ObjectId }, userId: string): "player1" | "player2" | null => {
  if (match.player1.toString() === userId || match.player1Partner?.toString() === userId) return "player1";
  if (match.player2.toString() === userId || match.player2Partner?.toString() === userId) return "player2";
  return null;
};

const visibleMatchFilter = (userId: string, role?: string, base: Record<string, unknown> = {}) => {
  if (isAdmin(role)) {
    return base;
  }

  return {
    $and: [
      base,
      {
        $or: [
          { friendly: { $ne: true } },
          { player1: userId },
          { player2: userId },
          { player1Partner: userId },
          { player2Partner: userId }
        ]
      }
    ]
  };
};

const canSubmitResult = async (acceptedAt?: Date): Promise<{ allowed: boolean; minutesLeft: number }> => {
  const settings = await getLeagueSettings();

  if (!acceptedAt) {
    return { allowed: false, minutesLeft: settings.resultEntryDelayMinutes };
  }

  const earliest = acceptedAt.getTime() + settings.resultEntryDelayMinutes * 60 * 1000;
  const minutesLeft = Math.max(0, Math.ceil((earliest - Date.now()) / 60000));

  return { allowed: minutesLeft === 0, minutesLeft };
};

const populateMatch = (id: Types.ObjectId | string) => {
  return Match.findById(id)
    .populate("tournament")
    .populate("venue")
    .populate("player1", "-password")
    .populate("player2", "-password")
    .populate("player1Partner", "-password")
    .populate("player2Partner", "-password")
    .populate("winner", "-password")
    .populate("challengedBy", "-password")
    .populate("resultSubmittedBy", "-password")
    .populate("resultConfirmedBy", "-password");
};

export const listMatches = asyncHandler(async (req, res) => {
  const filter: Record<string, unknown> = typeof req.query.tournament === "string" ? { tournament: req.query.tournament } : {};

  if (!isAdmin(req.user!.role)) {
    const hiddenTournaments = await Tournament.find({
      visibility: "private",
      owner: { $ne: req.user!.id },
      admins: { $ne: req.user!.id },
      participants: { $ne: req.user!.id }
    }).select("_id");
    filter.tournament = {
      ...(typeof filter.tournament === "string" ? { $eq: filter.tournament } : {}),
      $nin: hiddenTournaments.map((tournament) => tournament._id)
    };
  }

  const matches = await Match.find(visibleMatchFilter(req.user!.id, req.user!.role, filter))
    .populate("tournament")
    .populate("venue")
    .populate("player1", "-password")
    .populate("player2", "-password")
    .populate("player1Partner", "-password")
    .populate("player2Partner", "-password")
    .populate("winner", "-password")
    .sort({ createdAt: -1 });

  res.json({ matches });
});

export const getMyMatches = asyncHandler(async (req, res) => {
  const matches = await Match.find({
    $or: [{ player1: req.user!.id }, { player2: req.user!.id }, { player1Partner: req.user!.id }, { player2Partner: req.user!.id }]
  })
    .populate("tournament")
    .populate("venue")
    .populate("player1", "-password")
    .populate("player2", "-password")
    .populate("player1Partner", "-password")
    .populate("player2Partner", "-password")
    .populate("winner", "-password")
    .populate("resultSubmittedBy", "-password")
    .sort({ createdAt: -1 });

  res.json({ matches });
});

export const getPendingMatches = asyncHandler(async (req, res) => {
  const matches = await Match.find({
    $or: [{ player2: req.user!.id }, { player2Partner: req.user!.id }],
    status: "pending"
  })
    .populate("tournament")
    .populate("venue")
    .populate("player1", "-password")
    .populate("player2", "-password")
    .populate("player1Partner", "-password")
    .populate("player2Partner", "-password")
    .sort({ createdAt: -1 });

  res.json({ matches });
});

export const getDisputedMatches = asyncHandler(async (_req, res) => {
  const matches = await Match.find({ status: "disputed" })
    .populate("tournament")
    .populate("venue")
    .populate("player1", "-password")
    .populate("player2", "-password")
    .populate("player1Partner", "-password")
    .populate("player2Partner", "-password")
    .populate("winner", "-password")
    .populate("resultSubmittedBy", "-password")
    .sort({ disputedAt: -1 });

  res.json({ matches });
});

export const getMatch = asyncHandler(async (req, res) => {
  const match = await populateMatch(String(req.params.id));

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  if (match.friendly && !isAdmin(req.user!.role) && !matchPlayerIds(match).includes(req.user!.id)) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  res.json({ match });
});

export const createChallenge = asyncHandler(async (req, res) => {
  await ensureManualLeagueMatch(req.body.tournamentId, req.body.round, req.body.discipline);
  const player1 = req.user!.id;
  const player2 = req.body.opponentId;
  const player1Partner = req.body.partnerId;
  const player2Partner = req.body.opponentPartnerId;

  if (req.body.discipline === "doubles" && (!player1Partner || !player2Partner)) {
    throw new AppError(400, "Za dubl meč potrebna su četiri igrača.");
  }

  await ensurePlayersAndTournament(player1, player2, player1Partner, player2Partner, req.body.tournamentId);
  await ensureScheduledAtWithinTournament(req.body.tournamentId, req.body.scheduledAt);
  const tournament = req.body.tournamentId ? await Tournament.findById(req.body.tournamentId) : null;
  await expireInactivePlayers(new Date(), [player2, player2Partner].filter(Boolean));
  const challengedPlayers = await Player.find({
    _id: { $in: [player2, player2Partner].filter(Boolean) },
    playStatus: "unavailable"
  });

  if (challengedPlayers.length > 0 && !isAdmin(req.user!.role)) {
    throw new AppError(400, "Ovaj igrač trenutno ne prima izazove za meč.");
  }

  const match = await Match.create({
    tournament: req.body.tournamentId,
    discipline: req.body.discipline,
    player1,
    player2,
    player1Partner,
    player2Partner,
    round: req.body.round,
    location: req.body.location,
    ...await matchLocationPatch(req.body),
    scheduledAt: req.body.scheduledAt,
    friendly: tournament?.friendly ?? req.body.friendly,
    status: "pending",
    challengedBy: req.user!.playerId
  });

  res.status(201).json({ match: await populateMatch(match._id) });
});

export const acceptMatch = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  if (!isAdmin(req.user!.role) && ![match.player2.toString(), match.player2Partner?.toString()].includes(req.user!.id)) {
    throw new AppError(403, "Samo izazvani igrač može prihvatiti izazov.");
  }

  if (match.status !== "pending") {
    throw new AppError(400, "Moguće je prihvatiti samo izazove koji čekaju odgovor.");
  }

  match.status = "accepted";
  match.acceptedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const rejectMatch = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id);

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  if (!isAdmin(req.user!.role) && ![match.player2.toString(), match.player2Partner?.toString()].includes(req.user!.id)) {
    throw new AppError(403, "Samo izazvani igrač može odbiti izazov.");
  }

  if (match.status !== "pending") {
    throw new AppError(400, "Moguće je odbiti samo izazove koji čekaju odgovor.");
  }

  match.status = "rejected";
  match.rejectedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const submitResult = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);
  await protectHybridMatch(match, req.body);

  if (match.status !== "accepted") {
    throw new AppError(400, "Rezultat je moguće unijeti samo za dogovorene mečeve.");
  }

  const delay = await canSubmitResult(match.acceptedAt);

  if (!delay.allowed && !isAdmin(req.user!.role)) {
    throw new AppError(400, `Unos rezultata biće dostupan za ${delay.minutesLeft} min.`);
  }

  validateWinner(match.player1.toString(), match.player2.toString(), req.body.winner);

  match.sets = req.body.sets;
  match.winner = new Types.ObjectId(req.body.winner);
  match.round = req.body.round ?? match.round;
  match.status = "waiting_confirmation";
  match.resultSubmittedBy = req.user!.playerId;
  match.resultSubmittedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const confirmResult = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.status !== "waiting_confirmation") {
    throw new AppError(400, "Moguće je potvrditi samo rezultate koji čekaju potvrdu.");
  }

  if (!match.resultSubmittedBy) {
    throw new AppError(400, "Nedostaje podatak o igraču koji je unio rezultat.");
  }

  if (!isAdmin(req.user!.role) && match.resultSubmittedBy.toString() === req.user!.id) {
    throw new AppError(400, "Isti igrač ne može unijeti i potvrditi rezultat.");
  }

  const side = getActorSide(match, req.user!.id);

  if (!isAdmin(req.user!.role) && !side) {
    throw new AppError(403, "Rezultat mogu potvrditi samo učesnici meča.");
  }

  match.status = "confirmed";
  match.resultConfirmedBy = req.user!.playerId;
  match.confirmedAt = new Date();
  await match.save();
  await applyConfirmedMatchStats(match);

  res.json({ match: await populateMatch(match._id) });
});

export const disputeResult = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id);

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.status !== "waiting_confirmation") {
    throw new AppError(400, "Moguće je osporiti samo rezultate poslate na potvrdu.");
  }

  if (!isAdmin(req.user!.role) && match.resultSubmittedBy?.toString() === req.user!.id) {
    throw new AppError(400, "Igrač ne može osporiti rezultat koji je sam unio.");
  }

  match.status = "disputed";
  match.disputedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const adminResolve = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  if (match.statsApplied) {
    throw new AppError(400, "Statistika ovog meča već je uračunata u rang-listu.");
  }
  await protectHybridMatch(match, { ...req.body,
    status: req.body.action === "confirm" ? "confirmed" : req.body.action === "cancel" ? "cancelled" : "rejected"
  });

  if (req.body.action === "confirm") {
    const winner = req.body.winner ?? match.winner?.toString();
    const sets = req.body.sets ?? match.sets;

    if (!winner || !sets?.length) {
      throw new AppError(400, "Za potvrdu meča potrebno je unijeti pobjednika i rezultate setova.");
    }

    validateWinner(match.player1.toString(), match.player2.toString(), winner);

    match.winner = new Types.ObjectId(winner);
    match.sets = sets;
    match.status = "confirmed";
    match.confirmedAt = new Date();
  }

  if (req.body.action === "reject") {
    match.status = "rejected";
    match.rejectedAt = new Date();
  }

  if (req.body.action === "cancel") {
    match.status = "cancelled";
    match.cancelledAt = new Date();
  }

  match.adminResolvedBy = req.user!.playerId;
  match.adminResolutionNote = req.body.note;
  await match.save();

  if (match.status === "confirmed") {
    await applyConfirmedMatchStats(match);
  }

  res.json({ match: await populateMatch(match._id) });
});

export const createMatch = asyncHandler(async (req, res) => {
  await ensureManualLeagueMatch(req.body.tournament, req.body.round, req.body.discipline);
  if (req.body.discipline === "doubles" && (!req.body.player1Partner || !req.body.player2Partner)) {
    throw new AppError(400, "Za dubl meč potrebna su četiri igrača.");
  }
  await ensurePlayersAndTournament(req.body.player1, req.body.player2, req.body.player1Partner, req.body.player2Partner, req.body.tournament);
  await ensureScheduledAtWithinTournament(req.body.tournament, req.body.scheduledAt);
  validateWinner(req.body.player1, req.body.player2, req.body.winner);

  if (req.body.status === "confirmed" && !req.body.winner) {
    throw new AppError(400, "Potvrđeni meč mora imati pobjednika.");
  }

  if (req.body.status === "rejected" && req.body.winner) {
    throw new AppError(400, "Odbijeni meč ne može imati pobjednika.");
  }

  const now = new Date();
  const tournament = req.body.tournament ? await Tournament.findById(req.body.tournament) : null;
  const match = await Match.create({
    ...req.body,
    ...await matchLocationPatch(req.body),
    friendly: tournament?.friendly ?? req.body.friendly,
    acceptedAt: ["accepted", "waiting_confirmation", "confirmed"].includes(req.body.status as MatchStatus) ? now : undefined,
    resultSubmittedBy: ["waiting_confirmation", "confirmed"].includes(req.body.status as MatchStatus) ? req.user!.playerId : undefined,
    resultSubmittedAt: ["waiting_confirmation", "confirmed"].includes(req.body.status as MatchStatus) ? now : undefined,
    resultConfirmedBy: req.body.status === "confirmed" ? req.user!.playerId : undefined,
    confirmedAt: req.body.status === "confirmed" ? now : undefined
  });
  await applyConfirmedMatchStats(match);

  res.status(201).json({ match: await populateMatch(match._id) });
});

export const updateMatch = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  const nextTournament = req.body.tournament ?? match.tournament?.toString();
  await protectHybridMatch(match, req.body);
  if (nextTournament !== match.tournament?.toString()) {
    await ensureManualLeagueMatch(nextTournament, req.body.round ?? match.round, req.body.discipline ?? match.discipline);
  }
  const nextPlayer1 = req.body.player1 ?? match.player1.toString();
  const nextPlayer2 = req.body.player2 ?? match.player2.toString();
  const nextPlayer1Partner = req.body.player1Partner ?? match.player1Partner?.toString();
  const nextPlayer2Partner = req.body.player2Partner ?? match.player2Partner?.toString();
  const nextWinner = req.body.winner ?? match.winner?.toString();
  const nextStatus = req.body.status ?? match.status;
  const nextDiscipline = req.body.discipline ?? match.discipline;
  const nextScheduledAt = req.body.scheduledAt ?? match.scheduledAt;

  if (match.statsApplied) {
    const identityChanged =
      nextTournament !== match.tournament?.toString() ||
      nextPlayer1 !== match.player1.toString() ||
      nextPlayer2 !== match.player2.toString() ||
      nextPlayer1Partner !== match.player1Partner?.toString() ||
      nextPlayer2Partner !== match.player2Partner?.toString() ||
      nextWinner !== match.winner?.toString() ||
      nextStatus !== match.status;

    if (identityChanged) {
      throw new AppError(400, "Meč nije moguće mijenjati nakon obračuna statistike za rang-listu.");
    }
  }

  if (nextDiscipline === "doubles" && (!nextPlayer1Partner || !nextPlayer2Partner)) {
    throw new AppError(400, "Za dubl meč potrebna su četiri igrača.");
  }
  await ensurePlayersAndTournament(nextPlayer1, nextPlayer2, nextPlayer1Partner, nextPlayer2Partner, nextTournament);
  await ensureScheduledAtWithinTournament(nextTournament, nextScheduledAt);
  validateWinner(nextPlayer1, nextPlayer2, nextWinner);

  if (nextStatus === "confirmed" && !nextWinner) {
    throw new AppError(400, "Potvrđeni meč mora imati pobjednika.");
  }

  if (nextStatus === "rejected" && nextWinner) {
    throw new AppError(400, "Odbijeni meč ne može imati pobjednika.");
  }

  Object.assign(match, {
    ...req.body,
    ...await matchLocationPatch(req.body, match),
    tournament: nextTournament ? new Types.ObjectId(nextTournament) : undefined,
    discipline: nextDiscipline,
    player1: new Types.ObjectId(nextPlayer1),
    player2: new Types.ObjectId(nextPlayer2),
    player1Partner: nextPlayer1Partner ? new Types.ObjectId(nextPlayer1Partner) : undefined,
    player2Partner: nextPlayer2Partner ? new Types.ObjectId(nextPlayer2Partner) : undefined,
    winner: nextWinner ? new Types.ObjectId(nextWinner) : undefined
  });

  await match.save();
  await applyConfirmedMatchStats(match);

  res.json({ match: await populateMatch(match._id) });
});

export const uploadMatchImage = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id);

  if (!match) {
    throw new AppError(404, "Meč nije pronađen.");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.images.length >= 5) {
    throw new AppError(400, "Galerija meča može imati najviše 5 slika.");
  }

  const image = await saveUploadedImage(req.body as Buffer, req.headers["content-type"], {
    fieldName: "image",
    folder: "match-images",
    maxSizeMb: 8
  });

  match.images.push(image);
  await match.save();

  res.json({ image, match: await populateMatch(match._id) });
});
