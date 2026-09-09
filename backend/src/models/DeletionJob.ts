import { Schema, model, type InferSchemaType } from "mongoose";

// A durable, private rollback plan. Completed jobs retain only an idempotency receipt.
const deletionJobSchema = new Schema({
  _id: { type: String, required: true },
  kind: { type: String, enum: ["match", "tournament"], required: true },
  target: { type: Schema.Types.ObjectId, required: true },
  actor: { type: Schema.Types.ObjectId, required: true },
  completed: { type: Boolean, default: false },
  matchCount: { type: Number, required: true },
  matchIds: [{ type: Schema.Types.ObjectId }],
  tournamentId: Schema.Types.ObjectId,
  clearWinner: Boolean,
  images: [String],
  deltas: [new Schema({
    player: { type: Schema.Types.ObjectId, required: true },
    operation: { type: Schema.Types.ObjectId, required: true },
    wins: { type: Number, default: 0 }, losses: { type: Number, default: 0 },
    matchesPlayed: { type: Number, default: 0 }, tournamentsWon: { type: Number, default: 0 },
    totalPoints: { type: Number, default: 0 }
  }, { _id: false })]
}, { timestamps: true });

deletionJobSchema.index({ completed: 1, createdAt: 1 });

export const DeletionJob = model("DeletionJob", deletionJobSchema);
export type DeletionJobAttrs = InferSchemaType<typeof deletionJobSchema>;
