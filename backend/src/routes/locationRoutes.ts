import { Router } from "express";
import { z } from "zod";
import { env } from "../config/env";
import { authenticate, authorize } from "../middleware/auth";
import { asyncHandler } from "../middleware/asyncHandler";
import { AppError } from "../middleware/errorHandler";
import { validate } from "../middleware/validate";
import { Location } from "../models/Location";
import { locationSchema, locationIdSchema } from "../services/locationService";
import { GooglePlacesService } from "../services/googlePlacesService";

export const locationRoutes = Router();
const maps = new GooglePlacesService(env.googlePlacesApiKey);

locationRoutes.use(authenticate);
locationRoutes.get("/", asyncHandler(async (req, res) => {
  const filter = req.user!.role === "admin" && req.query.all === "true" ? {} : { active: true };
  res.json({ locations: await Location.find(filter).sort({ name: 1, _id: 1 }) });
}));

locationRoutes.post("/search", authorize("admin"), validate(z.object({ query: z.string().trim().min(3).max(200) })),
  asyncHandler(async (req, res) => {
    res.set("Cache-Control", "no-store");
    res.json({ places: await maps.search(req.body.query) });
  }));

locationRoutes.post("/", authorize("admin"), validate(locationSchema), asyncHandler(async (req, res) => {
  if (req.body.googlePlaceId) await maps.verify(req.body.googlePlaceId);
  const location = await Location.create({ ...req.body, googlePlaceId: req.body.googlePlaceId || undefined });
  res.status(201).json({ location });
}));

locationRoutes.patch("/:id", authorize("admin"), validate(locationSchema.partial()), asyncHandler(async (req, res) => {
  const id = locationIdSchema.parse(req.params.id);
  const existing = await Location.findById(id);
  if (!existing) throw new AppError(404, "Lokacija nije pronađena.");
  if (req.body.googlePlaceId && req.body.googlePlaceId !== existing.googlePlaceId) {
    await maps.verify(req.body.googlePlaceId);
  }
  const { googlePlaceId, ...body } = req.body;
  Object.assign(existing, body);
  if (googlePlaceId !== undefined) existing.googlePlaceId = googlePlaceId || undefined;
  await existing.save();
  res.json({ location: existing });
}));
