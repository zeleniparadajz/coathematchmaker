import { z } from "zod";
import { Tournament } from "../models/Tournament";
import { Player } from "../models/Player";
import { Match } from "../models/Match";
import { AppError } from "../middleware/errorHandler";
import { asyncHandler } from "../middleware/asyncHandler";
import { awardTournamentWin } from "../services/rankingService";
import { advanceTournamentRound, generateTournamentDraw } from "../services/bracketService";
import { saveUploadedImage } from "../services/uploadService";

export const createTournamentSchema = z.object({
  name: z.string().min(1),
  location: z.string().min(1),
  surface: z.string().min(1).default("Hard"),
  category: z.string().min(1),
  format: z
    .enum(["elimination", "round_robin", "qualification", "group_knockout", "double_elimination", "compass", "swiss"])
    .default("elimination"),
  startDate: z.coerce.date(),
  endDate: z.coerce.date(),
  status: z.enum(["upcoming", "active", "finished"]).optional()
});

export const updateTournamentSchema = createTournamentSchema.partial().extend({
  winner: z.string().optional()
});

export const finishTournamentSchema = z.object({
  winnerId: z.string().min(1)
});

export const addParticipantSchema = z.object({
  playerId: z.string().min(1)
});

export const createTournamentMatchSchema = z.object({
  player1: z.string().min(1),
  player2: z.string().min(1),
  round: z.enum(["Q", "R32", "R16", "QF", "SF", "F", "RR"]).default("R16")
});

export const listTournaments = asyncHandler(async (req, res) => {
  const filter = typeof req.query.status === "string" ? { status: req.query.status } : {};
  const tournaments = await Tournament.find(filter)
    .populate("participants", "-password")
    .populate("winner", "-password")
    .sort({ startDate: -1 });

  res.json({ tournaments });
});

export const getTournament = asyncHandler(async (req, res) => {
  const tournament = await Tournament.findById(req.params.id)
    .populate("participants", "-password")
    .populate({
      path: "matches",
      populate: [
        { path: "player1", select: "-password" },
        { path: "player2", select: "-password" },
        { path: "winner", select: "-password" }
      ]
    })
    .populate("winner", "-password");

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  res.json({ tournament });
});

export const createTournament = asyncHandler(async (req, res) => {
  if (req.body.endDate < req.body.startDate) {
    throw new AppError(400, "End date must be after start date");
  }

  const tournament = await Tournament.create(req.body);
  res.status(201).json({ tournament });
});

export const updateTournament = asyncHandler(async (req, res) => {
  if (req.body.endDate && req.body.startDate && req.body.endDate < req.body.startDate) {
    throw new AppError(400, "End date must be after start date");
  }

  const tournament = await Tournament.findByIdAndUpdate(req.params.id, req.body, {
    new: true,
    runValidators: true
  }).populate("participants", "-password");

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  res.json({ tournament });
});

export const registerForTournament = asyncHandler(async (req, res) => {
  const playerId = req.user!.id;
  const player = await Player.findById(playerId);

  if (!player?.active) {
    throw new AppError(403, "Only active players can register for tournaments");
  }

  const tournament = await Tournament.findById(req.params.id);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  if (tournament.status !== "upcoming") {
    throw new AppError(400, "Registration is allowed only for upcoming tournaments");
  }

  if (!tournament.participants.some((participantId) => participantId.toString() === playerId)) {
    tournament.participants.push(req.user!.playerId);
    await tournament.save();
  }

  await tournament.populate("participants", "-password");
  res.json({ tournament });
});

export const addParticipant = asyncHandler(async (req, res) => {
  const { playerId } = req.body;
  const player = await Player.findById(playerId);

  if (!player) {
    throw new AppError(404, "Player not found");
  }

  const tournament = await Tournament.findById(req.params.id);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  if (!tournament.participants.some((participantId) => participantId.toString() === playerId)) {
    tournament.participants.push(player._id);
    await tournament.save();
  }

  await tournament.populate("participants", "-password");
  res.json({ tournament });
});

export const removeParticipant = asyncHandler(async (req, res) => {
  const tournament = await Tournament.findById(req.params.id);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  if (tournament.matches.length > 0) {
    throw new AppError(400, "Cannot remove participants after draw is generated");
  }

  tournament.participants = tournament.participants.filter((participantId) => participantId.toString() !== req.params.playerId);
  await tournament.save();
  await tournament.populate("participants", "-password");
  res.json({ tournament });
});

export const createTournamentMatch = asyncHandler(async (req, res) => {
  const tournament = await Tournament.findById(req.params.id);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  if (req.body.player1 === req.body.player2) {
    throw new AppError(400, "Players must be different");
  }

  const participantIds = tournament.participants.map((id) => id.toString());

  if (!participantIds.includes(req.body.player1) || !participantIds.includes(req.body.player2)) {
    throw new AppError(400, "Both players must be tournament participants");
  }

  const match = await Match.create({
    tournament: tournament._id,
    player1: req.body.player1,
    player2: req.body.player2,
    round: req.body.round,
    status: "accepted",
    acceptedAt: new Date()
  });

  tournament.matches.push(match._id);
  await tournament.save();

  const populated = await Match.findById(match._id)
    .populate("player1", "-password")
    .populate("player2", "-password")
    .populate("winner", "-password");

  res.status(201).json({ match: populated });
});

export const generateDraw = asyncHandler(async (req, res) => {
  const result = await generateTournamentDraw(String(req.params.id));
  const tournament = await Tournament.findById(req.params.id)
    .populate("participants", "-password")
    .populate({
      path: "matches",
      populate: [
        { path: "player1", select: "-password" },
        { path: "player2", select: "-password" },
        { path: "winner", select: "-password" }
      ]
    });

  res.json({ tournament, byes: result.byes });
});

export const advanceRound = asyncHandler(async (req, res) => {
  const result = await advanceTournamentRound(String(req.params.id));
  const tournament = await Tournament.findById(req.params.id)
    .populate("participants", "-password")
    .populate({
      path: "matches",
      populate: [
        { path: "player1", select: "-password" },
        { path: "player2", select: "-password" },
        { path: "winner", select: "-password" }
      ]
    })
    .populate("winner", "-password");

  res.json({ tournament, matchesCreated: result.matchesCreated, winner: result.winner });
});

export const finishTournament = asyncHandler(async (req, res) => {
  await awardTournamentWin(String(req.params.id), req.body.winnerId);

  const tournament = await Tournament.findById(req.params.id)
    .populate("participants", "-password")
    .populate("winner", "-password");

  res.json({ tournament });
});

export const uploadTournamentImage = asyncHandler(async (req, res) => {
  const tournament = await Tournament.findById(req.params.id);

  if (!tournament) {
    throw new AppError(404, "Tournament not found");
  }

  if (tournament.images.length >= 5) {
    throw new AppError(400, "Tournament gallery can contain up to 5 images");
  }

  const image = await saveUploadedImage(req.body as Buffer, req.headers["content-type"], {
    fieldName: "image",
    folder: "tournament-images",
    maxSizeMb: 8
  });

  tournament.images.push(image);
  await tournament.save();
  await tournament.populate("participants", "-password");

  res.json({ image, tournament });
});
