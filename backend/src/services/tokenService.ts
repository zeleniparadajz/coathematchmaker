import jwt from "jsonwebtoken";
import type { SignOptions } from "jsonwebtoken";
import { env } from "../config/env";
import type { PlayerDocument } from "../models/Player";

export const signAuthToken = (player: PlayerDocument): string => {
  const options: SignOptions = {
    subject: player._id.toString(),
    expiresIn: env.jwtExpiresIn as SignOptions["expiresIn"]
  };

  return jwt.sign(
    {
      role: player.role
    },
    env.jwtSecret,
    options
  );
};
