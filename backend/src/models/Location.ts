import { Schema, model } from "mongoose";

export interface LocationAttrs {
  name: string;
  address: string;
  googlePlaceId?: string;
  active: boolean;
}

// Labels belong to the club; only the Google place ID is persisted from Places.
const locationSchema = new Schema<LocationAttrs>({
  name: { type: String, required: true, trim: true, maxlength: 160 },
  address: { type: String, trim: true, default: "", maxlength: 300 },
  googlePlaceId: { type: String },
  active: { type: Boolean, default: true }
}, { timestamps: true });

locationSchema.index({ googlePlaceId: 1 }, { unique: true, sparse: true });
locationSchema.index({ active: 1, name: 1 });

export const Location = model<LocationAttrs>("Location", locationSchema);
