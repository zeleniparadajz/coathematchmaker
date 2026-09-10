import { Schema, model } from "mongoose";

export interface LocationAttrs {
  name: string;
  address: string;
  googlePlaceId?: string;
  googleOnly: boolean;
  active: boolean;
}

// Labels belong to the club; only the Google place ID is persisted from Places.
const locationSchema = new Schema<LocationAttrs>({
  name: { type: String, default: "", required: function () { return !this.googleOnly; }, trim: true, maxlength: 160 },
  address: { type: String, trim: true, default: "", maxlength: 300 },
  googlePlaceId: { type: String },
  googleOnly: { type: Boolean, default: false },
  active: { type: Boolean, default: true }
}, { timestamps: true });

locationSchema.index({ googlePlaceId: 1 }, { unique: true, sparse: true });
locationSchema.index({ active: 1, name: 1 });

locationSchema.set("toJSON", { transform: (_doc, value) => {
  // Older clients still receive a usable label; the actual provider text is not stored.
  if (value.googleOnly) Object.assign(value, { customName: value.name, name: value.name || "Google Maps" });
  return value;
} });

export const Location = model<LocationAttrs>("Location", locationSchema);
