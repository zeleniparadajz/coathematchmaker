import { Schema, model } from "mongoose";

export interface LeagueSettingsAttrs {
  resultEntryDelayMinutes: number;
  matchWinPoints: number;
  tournamentWinPoints: number;
}

const leagueSettingsSchema = new Schema<LeagueSettingsAttrs>(
  {
    resultEntryDelayMinutes: { type: Number, default: 60, min: 0 },
    matchWinPoints: { type: Number, default: 10, min: 0 },
    tournamentWinPoints: { type: Number, default: 50, min: 0 }
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

export const LeagueSettings = model<LeagueSettingsAttrs>("LeagueSettings", leagueSettingsSchema);
