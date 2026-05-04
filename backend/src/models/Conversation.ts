import { Schema, model, type Types } from "mongoose";

export interface ConversationAttrs {
  participants: Types.ObjectId[];
  lastMessage?: string;
  lastMessageAt?: Date;
  lastMessageBy?: Types.ObjectId;
  readBy: Map<string, Date>;
}

const conversationSchema = new Schema<ConversationAttrs>(
  {
    participants: [{ type: Schema.Types.ObjectId, ref: "Player", required: true }],
    lastMessage: { type: String, trim: true },
    lastMessageAt: { type: Date },
    lastMessageBy: { type: Schema.Types.ObjectId, ref: "Player" },
    readBy: { type: Map, of: Date, default: {} }
  },
  {
    timestamps: true,
    toJSON: {
      transform(_doc, ret) {
        delete (ret as { __v?: number }).__v;
        return ret;
      }
    }
  }
);

conversationSchema.index({ participants: 1, lastMessageAt: -1 });

export const Conversation = model<ConversationAttrs>("Conversation", conversationSchema);
