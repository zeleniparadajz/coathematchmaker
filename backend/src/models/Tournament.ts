import { Schema, model, type Types } from "mongoose";

export type TournamentStatus = "upcoming" | "active" | "finished";
export type TournamentFormat =
  | "elimination"
  | "round_robin"
  | "qualification"
  | "group_knockout"
  | "double_elimination"
  | "compass"
  | "swiss";

export interface TournamentAttrs {
  name: string;
  location: string;
  surface: string;
  category: string;
  format: TournamentFormat;
  startDate: Date;
  endDate: Date;
  status: TournamentStatus;
  participants: Types.ObjectId[];
  matches: Types.ObjectId[];
  images: string[];
  bracketSize?: number;
  drawGeneratedAt?: Date;
  winner?: Types.ObjectId;
}

const tournamentSchema = new Schema<TournamentAttrs>(
  {
    name: { type: String, required: true, trim: true },
    location: { type: String, required: true, trim: true },
    surface: { type: String, required: true, trim: true, default: "Hard" },
    category: { type: String, required: true, trim: true },
    format: {
      type: String,
      enum: ["elimination", "round_robin", "qualification", "group_knockout", "double_elimination", "compass", "swiss"],
      default: "elimination"
    },
    startDate: { type: Date, required: true },
    endDate: { type: Date, required: true },
    status: { type: String, enum: ["upcoming", "active", "finished"], default: "upcoming" },
    participants: [{ type: Schema.Types.ObjectId, ref: "Player" }],
    matches: [{ type: Schema.Types.ObjectId, ref: "Match" }],
    images: { type: [String], default: [] },
    bracketSize: { type: Number },
    drawGeneratedAt: { type: Date },
    winner: { type: Schema.Types.ObjectId, ref: "Player" }
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

tournamentSchema.index({ status: 1, startDate: 1 });

export const Tournament = model<TournamentAttrs>("Tournament", tournamentSchema);
