import { z } from "zod";
import { Types } from "mongoose";
import { Conversation } from "../models/Conversation";
import { Message } from "../models/Message";
import { Player } from "../models/Player";
import { AppError } from "../middleware/errorHandler";
import { asyncHandler } from "../middleware/asyncHandler";

export const startConversationSchema = z.object({
  participantId: z.string().min(1)
});

export const sendMessageSchema = z.object({
  text: z.string().trim().min(1).max(2000)
});

const ensureObjectId = (id: string, label: string): void => {
  if (!Types.ObjectId.isValid(id)) {
    throw new AppError(400, `Identifikator za polje ${label} nije ispravan.`);
  }
};

const ensureConversationAccess = async (conversationId: string, userId: string) => {
  ensureObjectId(conversationId, "conversation");
  const conversation = await Conversation.findOne({
    _id: conversationId,
    participants: userId
  });

  if (!conversation) {
    throw new AppError(404, "Razgovor nije pronađen.");
  }

  return conversation;
};

const populateConversation = (id: Types.ObjectId | string) => {
  return Conversation.findById(id)
    .populate("participants", "-password")
    .populate("lastMessageBy", "-password");
};

const unreadFor = async (conversationId: Types.ObjectId, userId: string, readAt?: Date): Promise<number> => {
  return Message.countDocuments({
    conversation: conversationId,
    sender: { $ne: userId },
    ...(readAt ? { createdAt: { $gt: readAt } } : {})
  });
};

export const listConversations = asyncHandler(async (req, res) => {
  const conversations = await Conversation.find({ participants: req.user!.id })
    .populate("participants", "-password")
    .populate("lastMessageBy", "-password")
    .sort({ lastMessageAt: -1, updatedAt: -1 });

  const enriched = await Promise.all(
    conversations.map(async (conversation) => {
      const readAt = conversation.readBy?.get(req.user!.id);
      const unreadCount = await unreadFor(conversation._id, req.user!.id, readAt);
      return {
        ...conversation.toJSON(),
        unreadCount
      };
    })
  );

  res.json({ conversations: enriched });
});

export const startConversation = asyncHandler(async (req, res) => {
  const participantId = req.body.participantId;
  ensureObjectId(participantId, "participant");

  if (participantId === req.user!.id) {
    throw new AppError(400, "Ne možete započeti razgovor sa sobom.");
  }

  const participant = await Player.findById(participantId);
  if (!participant || !participant.active) {
    throw new AppError(404, "Igrač nije pronađen.");
  }

  const participants = [req.user!.id, participantId].sort();
  let conversation = await Conversation.findOne({
    participants: { $all: participants, $size: 2 }
  });

  if (!conversation) {
    conversation = await Conversation.create({
      participants,
      readBy: new Map([[req.user!.id, new Date()]])
    });
  }

  res.status(201).json({ conversation: await populateConversation(conversation._id) });
});

export const listMessages = asyncHandler(async (req, res) => {
  const conversationId = String(req.params.id);
  await ensureConversationAccess(conversationId, req.user!.id);

  const messages = await Message.find({ conversation: conversationId })
    .populate("sender", "-password")
    .sort({ createdAt: 1 });

  res.json({ messages });
});

export const sendMessage = asyncHandler(async (req, res) => {
  const conversation = await ensureConversationAccess(String(req.params.id), req.user!.id);
  const message = await Message.create({
    conversation: conversation._id,
    sender: req.user!.playerId,
    text: req.body.text
  });

  conversation.lastMessage = req.body.text;
  conversation.lastMessageAt = new Date();
  conversation.lastMessageBy = req.user!.playerId;
  conversation.readBy.set(req.user!.id, new Date());
  await conversation.save();

  res.status(201).json({
    message: await Message.findById(message._id).populate("sender", "-password"),
    conversation: await populateConversation(conversation._id)
  });
});

export const markConversationRead = asyncHandler(async (req, res) => {
  const conversation = await ensureConversationAccess(String(req.params.id), req.user!.id);
  conversation.readBy.set(req.user!.id, new Date());
  await conversation.save();

  res.json({ conversation: await populateConversation(conversation._id) });
});

export const unreadCount = asyncHandler(async (req, res) => {
  const conversations = await Conversation.find({ participants: req.user!.id });
  const counts = await Promise.all(
    conversations.map((conversation) =>
      unreadFor(conversation._id, req.user!.id, conversation.readBy?.get(req.user!.id))
    )
  );
  res.json({ unreadCount: counts.reduce((sum, count) => sum + count, 0) });
});
