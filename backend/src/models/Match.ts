import { Schema, model, type Types } from "mongoose";

export type MatchStatus =
  | "pending"
  | "accepted"
  | "waiting_confirmation"
  | "confirmed"
  | "rejected"
  | "disputed"
  | "cancelled";

export interface SetScore {
  player1Games: number;
  player2Games: number;
}

export interface MatchAttrs {
  tournament?: Types.ObjectId;
  discipline: "singles" | "doubles";
  player1: Types.ObjectId;
  player2: Types.ObjectId;
  player1Partner?: Types.ObjectId;
  player2Partner?: Types.ObjectId;
  sets: SetScore[];
  winner?: Types.ObjectId;
  round: string;
  location?: string;
  scheduledAt?: Date;
  friendly: boolean;
  status: MatchStatus;
  challengedBy?: Types.ObjectId;
  acceptedAt?: Date;
  resultSubmittedBy?: Types.ObjectId;
  resultSubmittedAt?: Date;
  resultConfirmedBy?: Types.ObjectId;
  confirmedAt?: Date;
  rejectedAt?: Date;
  disputedAt?: Date;
  cancelledAt?: Date;
  adminResolvedBy?: Types.ObjectId;
  adminResolutionNote?: string;
  images: string[];
  statsApplied: boolean;
}

const setScoreSchema = new Schema<SetScore>(
  {
    player1Games: { type: Number, required: true, min: 0 },
    player2Games: { type: Number, required: true, min: 0 }
  },
  { _id: false }
);

const matchSchema = new Schema<MatchAttrs>(
  {
    tournament: { type: Schema.Types.ObjectId, ref: "Tournament" },
    discipline: { type: String, enum: ["singles", "doubles"], default: "singles" },
    player1: { type: Schema.Types.ObjectId, ref: "Player", required: true },
    player2: { type: Schema.Types.ObjectId, ref: "Player", required: true },
    player1Partner: { type: Schema.Types.ObjectId, ref: "Player" },
    player2Partner: { type: Schema.Types.ObjectId, ref: "Player" },
    sets: { type: [setScoreSchema], default: [] },
    winner: { type: Schema.Types.ObjectId, ref: "Player" },
    round: { type: String, required: true, trim: true },
    location: { type: String, trim: true },
    scheduledAt: { type: Date },
    friendly: { type: Boolean, default: false },
    status: {
      type: String,
      enum: ["pending", "accepted", "waiting_confirmation", "confirmed", "rejected", "disputed", "cancelled"],
      default: "pending"
    },
    challengedBy: { type: Schema.Types.ObjectId, ref: "Player" },
    acceptedAt: { type: Date },
    resultSubmittedBy: { type: Schema.Types.ObjectId, ref: "Player" },
    resultSubmittedAt: { type: Date },
    resultConfirmedBy: { type: Schema.Types.ObjectId, ref: "Player" },
    confirmedAt: { type: Date },
    rejectedAt: { type: Date },
    disputedAt: { type: Date },
    cancelledAt: { type: Date },
    adminResolvedBy: { type: Schema.Types.ObjectId, ref: "Player" },
    adminResolutionNote: { type: String, trim: true },
    images: { type: [String], default: [] },
    statsApplied: { type: Boolean, default: false, select: false }
  },
  {
    timestamps: true,
    toJSON: {
      transform(_doc, ret) {
        delete (ret as { __v?: number }).__v;
        delete (ret as Partial<MatchAttrs>).statsApplied;
        return ret;
      }
    }
  }
);

matchSchema.index({ tournament: 1, round: 1 });
matchSchema.index({ tournament: 1, player1: 1, player2: 1 });

export const Match = model<MatchAttrs>("Match", matchSchema);
