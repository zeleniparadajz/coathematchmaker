import mongoose from "mongoose";
import { env } from "./env";
import { runCompatibilityMigrations } from "../services/migrationService";

export const connectDatabase = async (): Promise<void> => {
  mongoose.set("strictQuery", true);
  await mongoose.connect(env.mongoUri);
  await runCompatibilityMigrations();
  console.log("MongoDB connected");
};
