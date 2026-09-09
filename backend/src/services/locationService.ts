import { z } from "zod";
import { Location } from "../models/Location";
import { AppError } from "../middleware/errorHandler";

export const locationIdSchema = z.string().regex(/^[a-f\d]{24}$/i);
export const placeIdSchema = z.string().min(1).max(1024).regex(/^[A-Za-z0-9_-]+$/);
export const locationIdsSchema = z.array(locationIdSchema).max(20)
  .refine((ids) => new Set(ids).size === ids.length, "Duplicate locations");

export const locationSchema = z.object({
  name: z.string().trim().min(1).max(160),
  address: z.string().trim().max(300).default(""),
  googlePlaceId: placeIdSchema.nullable().optional(),
  active: z.boolean().default(true)
});

export type VenueRecord = { _id: { toString(): string }; name: string; address: string; active: boolean };
export const locationLabel = (venue: Pick<VenueRecord, "name" | "address">) =>
  [venue.name, venue.address].filter(Boolean).join(", ");

export async function resolveLocations(
  ids: string[],
  existingIds: string[] = [],
  find = (values: string[]): Promise<VenueRecord[]> => Location.find({ _id: { $in: values } }).lean()
) {
  locationIdsSchema.parse(ids);
  if (ids.length === 0) return [];
  const venues = await find(ids);
  return ids.map((id) => {
    const venue = venues.find((item) => item._id.toString() === id);
    if (!venue || (!venue.active && !existingIds.includes(id))) {
      throw new AppError(400, "Izabrana lokacija vise nije dostupna. Osvjezite listu.");
    }
    return venue;
  });
}

export async function tournamentLocationPatch(
  body: { location?: string; locationIds?: string[] },
  existing?: { location: string; locations?: { toString(): string }[] },
  resolve = resolveLocations
) {
  if (body.locationIds !== undefined) {
    const venues = await resolve(body.locationIds, existing?.locations?.map(String));
    const location = venues.length ? venues.map(locationLabel).join("; ") : body.location?.trim();
    if (!location) throw new AppError(400, "Izaberite barem jednu lokaciju.");
    return { locations: body.locationIds, location };
  }
  if (body.location !== undefined) {
    const location = body.location.trim();
    if (!location) throw new AppError(400, "Izaberite barem jednu lokaciju.");
    // Old app versions still send a plain string. Preserve references on unrelated edits.
    return location === existing?.location ? {} : { location, locations: [] };
  }
  if (!existing) throw new AppError(400, "Izaberite barem jednu lokaciju.");
  return {};
}

export async function matchLocationPatch(
  body: { location?: string; locationId?: string | null },
  existing?: { location?: string; venue?: { toString(): string } }
) {
  if (body.locationId) {
    const [venue] = await resolveLocations([body.locationId], existing?.venue ? [String(existing.venue)] : []);
    return { venue: body.locationId, location: locationLabel(venue) };
  }
  if (body.locationId === null || (body.location !== undefined && body.location !== existing?.location)) {
    return { venue: null, location: body.location?.trim() ?? "" };
  }
  return {};
}
