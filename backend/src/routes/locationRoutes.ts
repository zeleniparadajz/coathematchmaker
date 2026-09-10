import { Router } from "express";
import { z } from "zod";
import { env } from "../config/env";
import { authenticate, authorize } from "../middleware/auth";
import { asyncHandler } from "../middleware/asyncHandler";
import { AppError } from "../middleware/errorHandler";
import { validate } from "../middleware/validate";
import { Location } from "../models/Location";
import { locationSchema, locationIdSchema, locationIdsSchema, placeIdSchema } from "../services/locationService";
import { GooglePlacesService } from "../services/googlePlacesService";

export function createLocationRoutes(maps = new GooglePlacesService(env.googlePlacesApiKey)) {
  const locationRoutes = Router();
  const language = z.enum(["sr", "en"]).default("sr");
  const sessionToken = z.string().regex(/^[A-Za-z0-9_-]{16,36}$/);
  const placeRequest = z.object({ placeId: placeIdSchema, sessionToken, language });
  const windows = new Map<string, { start: number; count: number }>();
  const limitUser = (id: string) => {
    const now = Date.now();
    for (const [key, window] of windows) if (now - window.start >= 60_000) windows.delete(key);
    const window = windows.get(id) ?? { start: now, count: 0 };
    windows.set(id, window);
    if (++window.count > 30) throw new AppError(429, "Previše zahtjeva za Google Maps. Pokušajte za minut.");
  };

  locationRoutes.use(authenticate);
  locationRoutes.use((_req, res, next) => { res.set("Cache-Control", "no-store"); next(); });
  locationRoutes.get("/", asyncHandler(async (req, res) => {
    const filter = req.user!.role === "admin" && req.query.all === "true" ? {} : { active: true };
    res.json({ locations: await Location.find(filter).sort({ name: 1, _id: 1 }) });
  }));

  locationRoutes.post("/search", authorize("admin"), validate(z.object({ query: z.string().trim().min(3).max(200) })),
    asyncHandler(async (req, res) => {
      res.set("Cache-Control", "no-store");
      res.json({ places: await maps.search(req.body.query) });
    }));

  locationRoutes.post("/autocomplete", validate(z.object({ query: z.string().trim().min(3).max(200), sessionToken, language })),
    asyncHandler(async (req, res) => {
      limitUser(req.user!.id);
      res.json({ places: await maps.autocomplete(req.body.query, req.body.sessionToken, req.body.language) });
    }));

  locationRoutes.post("/details", validate(placeRequest), asyncHandler(async (req, res) => {
    limitUser(req.user!.id);
    res.json({ place: await maps.details(req.body.placeId, req.body.sessionToken, req.body.language) });
  }));

  // Selection stores only the stable Google ID. Provider names/addresses remain response-only.
  locationRoutes.post("/google", validate(placeRequest), asyncHandler(async (req, res) => {
    limitUser(req.user!.id);
    const googleDetails = await maps.details(req.body.placeId, req.body.sessionToken, req.body.language);
    let location = await Location.findOne({ googlePlaceId: req.body.placeId });
    if (!location) {
      try {
        location = await Location.create({ googlePlaceId: req.body.placeId, googleOnly: true });
      } catch (error) {
        if ((error as { code?: number }).code !== 11000) throw error;
        location = await Location.findOne({ googlePlaceId: req.body.placeId });
      }
    }
    if (!location || !location.active) throw new AppError(400, "Izabrana lokacija više nije dostupna. Osvježite listu.");
    res.json({ location: { ...location.toObject(), googleDetails: location.googleOnly ? googleDetails : undefined } });
  }));

  locationRoutes.post("/resolve", validate(z.object({ ids: locationIdsSchema, language })), asyncHandler(async (req, res) => {
    limitUser(req.user!.id);
    const locations = await Location.find({ _id: { $in: req.body.ids }, googleOnly: true });
    const places: Record<string, unknown> = {};
    // Do not fail a tournament or match page when Maps is temporarily unavailable.
    await Promise.all(locations.map(async (location) => {
      if (!location.googlePlaceId) return;
      try { places[String(location._id)] = await maps.details(location.googlePlaceId, undefined, req.body.language); }
      catch { /* The client retains its own label and the exact Maps link. */ }
    }));
    res.json({ places });
  }));

  locationRoutes.post("/", authorize("admin"), validate(locationSchema), asyncHandler(async (req, res) => {
    if (req.body.googlePlaceId) await maps.verify(req.body.googlePlaceId);
    const location = await Location.create({ ...req.body, googlePlaceId: req.body.googlePlaceId || undefined });
    res.status(201).json({ location });
  }));

  locationRoutes.patch("/:id", authorize("admin"), validate(locationSchema.partial().extend({ name: z.string().trim().max(160).optional() })), asyncHandler(async (req, res) => {
    const id = locationIdSchema.parse(req.params.id);
    const existing = await Location.findById(id);
    if (!existing) throw new AppError(404, "Lokacija nije pronađena.");
    if (req.body.googlePlaceId && req.body.googlePlaceId !== existing.googlePlaceId) {
      await maps.verify(req.body.googlePlaceId);
    }
    const { googlePlaceId, ...body } = req.body;
    Object.assign(existing, body);
    if (googlePlaceId !== undefined) existing.googlePlaceId = googlePlaceId || undefined;
    if (googlePlaceId === null) existing.googleOnly = false;
    await existing.save();
    res.json({ location: existing });
  }));
  return locationRoutes;
}

export const locationRoutes = createLocationRoutes();
