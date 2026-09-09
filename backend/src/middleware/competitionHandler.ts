import type { NextFunction, Request, Response } from "express";
import { resumeDeletions } from "../services/deletionService";

let writes: Promise<unknown> = Promise.resolve();

// The deployed API is a single process with standalone Mongo. Serialize competition
// writes and finish durable deletion plans before accepting another mutation.
export const competitionHandler = (route: (req: Request, res: Response, next: NextFunction) => Promise<unknown>) =>
  (req: Request, res: Response, next: NextFunction): void => {
    if (["GET", "HEAD", "OPTIONS"].includes(req.method)) {
      route(req, res, next).catch(next);
      return;
    }
    const run = writes.then(async () => { await resumeDeletions(); return route(req, res, next); });
    writes = run.catch(() => undefined);
    run.catch(next);
  };
