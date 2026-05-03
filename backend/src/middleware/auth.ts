import jwt from "jsonwebtoken";
import { Types } from "mongoose";
import type { NextFunction, Request, Response } from "express";
import { env } from "../config/env";
import { AppError } from "./errorHandler";
import type { AuthRole } from "../types/express";
import { Player } from "../models/Player";

interface JwtPayload {
  sub: string;
  role: AuthRole;
}

export const authenticate = (req: Request, _res: Response, next: NextFunction): void => {
  const header = req.headers.authorization;

  if (!header?.startsWith("Bearer ")) {
    throw new AppError(401, "Authorization token is required");
  }

  const token = header.slice("Bearer ".length);
  const decoded = jwt.verify(token, env.jwtSecret) as JwtPayload;

  Player.findById(decoded.sub)
    .then((player) => {
      if (!player) {
        throw new AppError(401, "Authenticated player no longer exists");
      }

      if (!player.active) {
        throw new AppError(403, "Player account is inactive");
      }

      req.user = {
        id: decoded.sub,
        role: player.role,
        playerId: new Types.ObjectId(decoded.sub)
      };

      next();
    })
    .catch(next);
};

export const authorize =
  (...roles: AuthRole[]) =>
  (req: Request, _res: Response, next: NextFunction): void => {
    if (!req.user) {
      throw new AppError(401, "Authentication required");
    }

    if (!roles.includes(req.user.role)) {
      throw new AppError(403, "You do not have permission to perform this action");
    }

    next();
  };
