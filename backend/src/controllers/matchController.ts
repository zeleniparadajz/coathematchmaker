import { z } from "zod";
import { Types } from "mongoose";
import { Match, type MatchStatus } from "../models/Match";
import { Player } from "../models/Player";
import { Tournament } from "../models/Tournament";
import { AppError } from "../middleware/errorHandler";
import { asyncHandler } from "../middleware/asyncHandler";
import { applyConfirmedMatchStats } from "../services/rankingService";
import { getLeagueSettings } from "../services/settingsService";
import { saveUploadedImage } from "../services/uploadService";

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
  scheduledAt: z.coerce.date().optional(),
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
  scheduledAt: z.coerce.date().optional()
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
    throw new AppError(400, `${label} must be a valid id`);
  }
};

const validateWinner = (player1: string, player2: string, winner?: string): void => {
  if (winner && winner !== player1 && winner !== player2) {
    throw new AppError(400, "Winner must be player1/team1 or player2/team2");
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
    throw new AppError(400, "Match players must be different");
  }

  playerIds.forEach((id, index) => validateObjectId(id, `player${index + 1}`));

  const players = await Promise.all(playerIds.map((id) => Player.findById(id)));

  if (players.some((player) => !player)) {
    throw new AppError(404, "All match players must exist");
  }

  if (!tournamentId) {
    return;
  }

  validateObjectId(tournamentId, "tournament");
  const tournament = await Tournament.findById(tournamentId);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  const participantIds = tournament.participants.map((id) => id.toString());

  if (!playerIds.every((id) => participantIds.includes(id))) {
    throw new AppError(400, "All match players must be tournament participants");
  }
};

const ensureScheduledAtWithinTournament = async (
  tournamentId?: string,
  scheduledAt?: Date
): Promise<void> => {
  if (!tournamentId || !scheduledAt) return;

  const tournament = await Tournament.findById(tournamentId);
  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  const start = new Date(tournament.startDate);
  start.setHours(0, 0, 0, 0);
  const end = new Date(tournament.endDate);
  end.setHours(23, 59, 59, 999);

  if (scheduledAt < start || scheduledAt > end) {
    throw new AppError(400, "Match date must be inside tournament dates");
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
    throw new AppError(403, "You can only act on your own matches");
  }
};

const getActorSide = (match: { player1: Types.ObjectId; player2: Types.ObjectId; player1Partner?: Types.ObjectId; player2Partner?: Types.ObjectId }, userId: string): "player1" | "player2" | null => {
  if (match.player1.toString() === userId || match.player1Partner?.toString() === userId) return "player1";
  if (match.player2.toString() === userId || match.player2Partner?.toString() === userId) return "player2";
  return null;
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
  const filter = typeof req.query.tournament === "string" ? { tournament: req.query.tournament } : {};
  const matches = await Match.find(filter)
    .populate("tournament")
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
    throw new AppError(404, "Match not found");
  }

  res.json({ match });
});

export const createChallenge = asyncHandler(async (req, res) => {
  const player1 = req.user!.id;
  const player2 = req.body.opponentId;
  const player1Partner = req.body.partnerId;
  const player2Partner = req.body.opponentPartnerId;

  if (req.body.discipline === "doubles" && (!player1Partner || !player2Partner)) {
    throw new AppError(400, "Doubles matches require four players");
  }

  await ensurePlayersAndTournament(player1, player2, player1Partner, player2Partner, req.body.tournamentId);
  await ensureScheduledAtWithinTournament(req.body.tournamentId, req.body.scheduledAt);
  const challengedPlayers = await Player.find({
    _id: { $in: [player2, player2Partner].filter(Boolean) },
    playStatus: "unavailable"
  });

  if (challengedPlayers.length > 0 && !isAdmin(req.user!.role)) {
    throw new AppError(400, "This player is not receiving match challenges right now");
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
    scheduledAt: req.body.scheduledAt,
    status: "pending",
    challengedBy: req.user!.playerId
  });

  res.status(201).json({ match: await populateMatch(match._id) });
});

export const acceptMatch = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Match not found");
  }

  if (!isAdmin(req.user!.role) && ![match.player2.toString(), match.player2Partner?.toString()].includes(req.user!.id)) {
    throw new AppError(403, "Only challenged player can accept this match");
  }

  if (match.status !== "pending") {
    throw new AppError(400, "Only pending matches can be accepted");
  }

  match.status = "accepted";
  match.acceptedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const rejectMatch = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id);

  if (!match) {
    throw new AppError(404, "Match not found");
  }

  if (!isAdmin(req.user!.role) && ![match.player2.toString(), match.player2Partner?.toString()].includes(req.user!.id)) {
    throw new AppError(403, "Only challenged player can reject this match");
  }

  if (match.status !== "pending") {
    throw new AppError(400, "Only pending matches can be rejected");
  }

  match.status = "rejected";
  match.rejectedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const submitResult = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Match not found");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.status !== "accepted") {
    throw new AppError(400, "Result can only be submitted for accepted matches");
  }

  const delay = await canSubmitResult(match.acceptedAt);

  if (!delay.allowed && !isAdmin(req.user!.role)) {
    throw new AppError(400, `Result entry is available in ${delay.minutesLeft} minute(s)`);
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
    throw new AppError(404, "Match not found");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.status !== "waiting_confirmation") {
    throw new AppError(400, "Only waiting confirmation matches can be confirmed");
  }

  if (!match.resultSubmittedBy) {
    throw new AppError(400, "Result submitter is missing");
  }

  if (!isAdmin(req.user!.role) && match.resultSubmittedBy.toString() === req.user!.id) {
    throw new AppError(400, "The same player cannot submit and confirm a result");
  }

  const side = getActorSide(match, req.user!.id);

  if (!isAdmin(req.user!.role) && !side) {
    throw new AppError(403, "Only match participants can confirm result");
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
    throw new AppError(404, "Match not found");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.status !== "waiting_confirmation") {
    throw new AppError(400, "Only submitted results can be disputed");
  }

  if (!isAdmin(req.user!.role) && match.resultSubmittedBy?.toString() === req.user!.id) {
    throw new AppError(400, "The result submitter cannot dispute their own submission");
  }

  match.status = "disputed";
  match.disputedAt = new Date();
  await match.save();

  res.json({ match: await populateMatch(match._id) });
});

export const adminResolve = asyncHandler(async (req, res) => {
  const match = await Match.findById(req.params.id).select("+statsApplied");

  if (!match) {
    throw new AppError(404, "Match not found");
  }

  if (match.statsApplied) {
    throw new AppError(400, "Ranking stats are already applied for this match");
  }

  if (req.body.action === "confirm") {
    const winner = req.body.winner ?? match.winner?.toString();
    const sets = req.body.sets ?? match.sets;

    if (!winner || !sets?.length) {
      throw new AppError(400, "Winner and sets are required to confirm a match");
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
  if (req.body.discipline === "doubles" && (!req.body.player1Partner || !req.body.player2Partner)) {
    throw new AppError(400, "Doubles matches require four players");
  }
  await ensurePlayersAndTournament(req.body.player1, req.body.player2, req.body.player1Partner, req.body.player2Partner, req.body.tournament);
  await ensureScheduledAtWithinTournament(req.body.tournament, req.body.scheduledAt);
  validateWinner(req.body.player1, req.body.player2, req.body.winner);

  if (req.body.status === "confirmed" && !req.body.winner) {
    throw new AppError(400, "Confirmed match must have a winner");
  }

  if (req.body.status === "rejected" && req.body.winner) {
    throw new AppError(400, "Rejected match cannot have a winner");
  }

  const now = new Date();
  const match = await Match.create({
    ...req.body,
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
    throw new AppError(404, "Match not found");
  }

  const nextTournament = req.body.tournament ?? match.tournament?.toString();
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
      throw new AppError(400, "Cannot change a match after ranking stats are applied");
    }
  }

  if (nextDiscipline === "doubles" && (!nextPlayer1Partner || !nextPlayer2Partner)) {
    throw new AppError(400, "Doubles matches require four players");
  }
  await ensurePlayersAndTournament(nextPlayer1, nextPlayer2, nextPlayer1Partner, nextPlayer2Partner, nextTournament);
  await ensureScheduledAtWithinTournament(nextTournament, nextScheduledAt);
  validateWinner(nextPlayer1, nextPlayer2, nextWinner);

  if (nextStatus === "confirmed" && !nextWinner) {
    throw new AppError(400, "Confirmed match must have a winner");
  }

  if (nextStatus === "rejected" && nextWinner) {
    throw new AppError(400, "Rejected match cannot have a winner");
  }

  Object.assign(match, {
    ...req.body,
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
    throw new AppError(404, "Match not found");
  }

  ensureParticipantOrAdmin(match, req.user!.id, req.user!.role);

  if (match.images.length >= 5) {
    throw new AppError(400, "Match gallery can contain up to 5 images");
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
