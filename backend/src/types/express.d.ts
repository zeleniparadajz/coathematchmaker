import type { Types } from "mongoose";

export type AuthRole = "player" | "admin";

declare global {
  namespace Express {
    interface Request {
      user?: {
        id: string;
        role: AuthRole;
        playerId: Types.ObjectId;
      };
    }
  }
}

export {};
