import { Schema, model, type Types } from "mongoose";

export type TournamentStatus = "upcoming" | "active" | "finished";
export type TournamentVisibility = "public" | "private";
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
  discipline: "singles" | "doubles";
  location: string;
  locations: Types.ObjectId[];
  surface: string;
  category: string;
  format: TournamentFormat;
  knockoutSize: number;
  knockoutSeeds: Types.ObjectId[];
  knockoutStartedAt?: Date;
  knockoutRounds: { round: string; matchIds: Types.ObjectId[] }[];
  startDate: Date;
  endDate: Date;
  status: TournamentStatus;
  visibility: TournamentVisibility;
  friendly: boolean;
  owner: Types.ObjectId;
  admins: Types.ObjectId[];
  participants: Types.ObjectId[];
  matches: Types.ObjectId[];
  images: string[];
  bracketSize?: number;
  drawGeneratedAt?: Date;
  winner?: Types.ObjectId;
  awardApplied?: boolean;
  awardOperationId?: Types.ObjectId;
  awardWinPoints?: number;
}

const tournamentSchema = new Schema<TournamentAttrs>(
  {
    name: { type: String, required: true, trim: true },
    discipline: { type: String, enum: ["singles", "doubles"], default: "singles" },
    location: { type: String, required: true, trim: true },
    locations: [{ type: Schema.Types.ObjectId, ref: "Location" }],
    surface: { type: String, required: true, trim: true, default: "Hard" },
    category: { type: String, required: true, trim: true },
    format: {
      type: String,
      enum: ["elimination", "round_robin", "qualification", "group_knockout", "double_elimination", "compass", "swiss"],
      default: "elimination"
    },
    startDate: { type: Date, required: true },
    knockoutSize: { type: Number, enum: [0, 2, 4, 8, 16], default: 0 },
    knockoutSeeds: [{ type: Schema.Types.ObjectId, ref: "Player" }],
    knockoutStartedAt: { type: Date },
    knockoutRounds: [{
      _id: false,
      round: { type: String, required: true },
      matchIds: [{ type: Schema.Types.ObjectId, ref: "Match" }]
    }],
    endDate: { type: Date, required: true },
    status: { type: String, enum: ["upcoming", "active", "finished"], default: "upcoming" },
    visibility: { type: String, enum: ["public", "private"], default: "public" },
    friendly: { type: Boolean, default: false },
    owner: { type: Schema.Types.ObjectId, ref: "Player", required: true },
    admins: [{ type: Schema.Types.ObjectId, ref: "Player" }],
    participants: [{ type: Schema.Types.ObjectId, ref: "Player" }],
    matches: [{ type: Schema.Types.ObjectId, ref: "Match" }],
    images: { type: [String], default: [] },
    bracketSize: { type: Number },
    drawGeneratedAt: { type: Date },
    winner: { type: Schema.Types.ObjectId, ref: "Player" },
    awardApplied: { type: Boolean, select: false },
    awardOperationId: { type: Schema.Types.ObjectId, select: false },
    awardWinPoints: { type: Number, min: 0, select: false }
  },
  {
    timestamps: true,
    toJSON: {
      transform(_doc, ret) {
        delete (ret as { __v?: number }).__v;
        delete (ret as Partial<TournamentAttrs>).awardApplied;
        delete (ret as Partial<TournamentAttrs>).awardOperationId;
        delete (ret as Partial<TournamentAttrs>).awardWinPoints;
        return ret;
      }
    }
  }
);

tournamentSchema.index({ status: 1, startDate: 1 });
tournamentSchema.index({ visibility: 1, startDate: -1 });
tournamentSchema.index({ owner: 1, startDate: -1 });
tournamentSchema.index({ admins: 1, startDate: -1 });
tournamentSchema.index({ participants: 1, startDate: -1 });

export const Tournament = model<TournamentAttrs>("Tournament", tournamentSchema);
