import bcrypt from "bcryptjs";
import { Schema, model, type HydratedDocument, type Model } from "mongoose";

export type PlayerRole = "player" | "admin";
export type PlayerPlayStatus = "available" | "unavailable";

export interface PlayerAttrs {
  firstName: string;
  lastName: string;
  email: string;
  password: string;
  birthDate: Date;
  country: string;
  club?: string;
  city?: string;
  sport: string;
  profileImage?: string;
  emailVerified: boolean;
  emailVerificationToken?: string;
  emailVerificationExpires?: Date;
  passwordResetToken?: string;
  passwordResetExpires?: Date;
  role: PlayerRole;
  active: boolean;
  playStatus: PlayerPlayStatus;
  playStatusUpdatedAt?: Date;
  playStatusSource: "manual" | "inactivity";
  lastActiveAt?: Date;
  activityTrackingStartedAt?: Date;
  totalPoints: number;
  wins: number;
  losses: number;
  matchesPlayed: number;
  tournamentsWon: number;
}

export interface PlayerMethods {
  comparePassword(candidatePassword: string): Promise<boolean>;
}

export type PlayerDocument = HydratedDocument<PlayerAttrs, PlayerMethods>;
type PlayerModel = Model<PlayerAttrs, Record<string, never>, PlayerMethods>;

const playerSchema = new Schema<PlayerAttrs, PlayerModel, PlayerMethods>(
  {
    firstName: { type: String, required: true, trim: true },
    lastName: { type: String, required: true, trim: true },
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    password: { type: String, required: true, minlength: 8, select: false },
    birthDate: { type: Date, required: true },
    country: { type: String, required: true, trim: true },
    club: { type: String, trim: true },
    city: { type: String, trim: true, maxlength: 100 },
    sport: { type: String, required: true, trim: true, default: "tennis" },
    profileImage: { type: String, trim: true },
    emailVerified: { type: Boolean, default: false },
    emailVerificationToken: { type: String, select: false },
    emailVerificationExpires: { type: Date, select: false },
    passwordResetToken: { type: String, select: false },
    passwordResetExpires: { type: Date, select: false },
    role: { type: String, enum: ["player", "admin"], default: "player" },
    active: { type: Boolean, default: true },
    playStatus: { type: String, enum: ["available", "unavailable"], default: "available" },
    playStatusUpdatedAt: { type: Date },
    playStatusSource: { type: String, enum: ["manual", "inactivity"], default: "manual" },
    lastActiveAt: { type: Date },
    activityTrackingStartedAt: { type: Date, default: Date.now, select: false },
    totalPoints: { type: Number, default: 0 },
    wins: { type: Number, default: 0 },
    losses: { type: Number, default: 0 },
    matchesPlayed: { type: Number, default: 0 },
    tournamentsWon: { type: Number, default: 0 }
  },
  {
    timestamps: true,
    toJSON: {
      transform(_doc, ret) {
        delete (ret as Partial<PlayerAttrs> & { __v?: number }).password;
        delete (ret as Partial<PlayerAttrs>).emailVerificationToken;
        delete (ret as Partial<PlayerAttrs>).emailVerificationExpires;
        delete (ret as Partial<PlayerAttrs>).passwordResetToken;
        delete (ret as Partial<PlayerAttrs>).passwordResetExpires;
        delete (ret as Partial<PlayerAttrs>).activityTrackingStartedAt;
        delete (ret as { __v?: number }).__v;
        return ret;
      }
    }
  }
);

playerSchema.pre("save", async function hashPassword(next) {
  if (!this.isModified("password")) {
    return next();
  }

  this.password = await bcrypt.hash(this.password, 12);
  next();
});

playerSchema.methods.comparePassword = function comparePassword(candidatePassword: string) {
  return bcrypt.compare(candidatePassword, this.password);
};

playerSchema.index({ totalPoints: -1, wins: -1 });
playerSchema.index({ active: 1, playStatus: 1, lastActiveAt: 1 });

export const Player = model<PlayerAttrs, PlayerModel>("Player", playerSchema);
