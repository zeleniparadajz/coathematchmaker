import { Router } from "express";
import {
  listConversations,
  listMessages,
  markConversationRead,
  sendMessage,
  sendMessageSchema,
  startConversation,
  startConversationSchema,
  unreadCount
} from "../controllers/messageController";
import { authenticate } from "../middleware/auth";
import { validate } from "../middleware/validate";

export const messageRoutes = Router();

messageRoutes.use(authenticate);

messageRoutes.get("/unread-count", unreadCount);
messageRoutes.get("/conversations", listConversations);
messageRoutes.post("/conversations", validate(startConversationSchema), startConversation);
messageRoutes.get("/conversations/:id/messages", listMessages);
messageRoutes.post("/conversations/:id/messages", validate(sendMessageSchema), sendMessage);
messageRoutes.patch("/conversations/:id/read", markConversationRead);
