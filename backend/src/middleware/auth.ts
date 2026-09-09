import jwt from "jsonwebtoken";
import { Types } from "mongoose";
import type { NextFunction, Request, Response } from "express";
import { env } from "../config/env";
import { AppError } from "./errorHandler";
import type { AuthRole } from "../types/express";
import { Player } from "../models/Player";
import { recordPlayerActivity } from "../services/activityService";

interface JwtPayload {
  sub: string;
  role: AuthRole;
}

export const authenticate = (req: Request, _res: Response, next: NextFunction): void => {
  const header = req.headers.authorization;

  if (!header?.startsWith("Bearer ")) {
    throw new AppError(401, "Potrebno je da se prijavite.");
  }

  const token = header.slice("Bearer ".length);
  const decoded = jwt.verify(token, env.jwtSecret) as JwtPayload;

  Player.findById(decoded.sub)
    .then(async (player) => {
      if (!player) {
        throw new AppError(401, "Korisnički nalog više ne postoji.");
      }

      if (!player.active) {
        throw new AppError(403, "Korisnički nalog nije aktivan.");
      }

      if (env.requireEmailVerification && !player.emailVerified) {
        throw new AppError(403, "Potvrdi email prije korišćenja aplikacije");
      }

      req.user = {
        id: decoded.sub,
        role: player.role,
        playerId: new Types.ObjectId(decoded.sub)
      };

      await recordPlayerActivity(player._id);

      next();
    })
    .catch(next);
};

export const authorize =
  (...roles: AuthRole[]) =>
  (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new AppError(401, "Potrebno je da se prijavite.");
    }

    if (!roles.includes(req.user.role)) {
      throw new AppError(403, "Nemate dozvolu za ovu radnju.");
    }

    next();
  };
