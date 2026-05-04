import { Schema, model, type Types } from "mongoose";

export interface MessageAttrs {
  conversation: Types.ObjectId;
  sender: Types.ObjectId;
  text: string;
}

const messageSchema = new Schema<MessageAttrs>(
  {
    conversation: { type: Schema.Types.ObjectId, ref: "Conversation", required: true },
    sender: { type: Schema.Types.ObjectId, ref: "Player", required: true },
    text: { type: String, required: true, trim: true, maxlength: 2000 }
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

messageSchema.index({ conversation: 1, createdAt: -1 });

export const Message = model<MessageAttrs>("Message", messageSchema);
