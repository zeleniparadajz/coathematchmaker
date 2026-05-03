import { Router } from "express";
import { generalRanking } from "../controllers/rankingController";
import { authenticate } from "../middleware/auth";

export const rankingRoutes = Router();

rankingRoutes.use(authenticate);
rankingRoutes.get("/", generalRanking);
