import cors from "cors";
import express from "express";
import path from "path";
import morgan from "morgan";
import { env } from "./config/env";
import { authRoutes } from "./routes/authRoutes";
import { matchRoutes } from "./routes/matchRoutes";
import { messageRoutes } from "./routes/messageRoutes";
import { playerRoutes } from "./routes/playerRoutes";
import { rankingRoutes } from "./routes/rankingRoutes";
import { settingsRoutes } from "./routes/settingsRoutes";
import { tournamentRoutes } from "./routes/tournamentRoutes";
import { errorHandler } from "./middleware/errorHandler";

export const app = express();

app.use(cors({ origin: env.corsOrigin === "*" ? true : env.corsOrigin }));
app.use("/uploads", express.static(path.resolve(process.cwd(), "uploads")));
app.use(express.json());
app.use(morgan(env.nodeEnv === "production" ? "combined" : "dev"));

app.get("/health", (_req, res) => {
  res.json({ status: "ok" });
});

app.use("/api/auth", authRoutes);
app.use("/api/players", playerRoutes);
app.use("/api/tournaments", tournamentRoutes);
app.use("/api/matches", matchRoutes);
app.use("/api/messages", messageRoutes);
app.use("/api/rankings", rankingRoutes);
app.use("/api/settings", settingsRoutes);

app.use(errorHandler);
