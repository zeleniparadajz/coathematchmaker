import { AppError } from "../middleware/errorHandler";
import { placeIdSchema } from "./locationService";

export type GooglePlace = {
  id: string;
  displayName?: { text?: string };
  formattedAddress?: string;
  attributions?: { provider: string; providerUri?: string }[];
};

export class GooglePlacesService {
  private windowStart = 0;
  private requests = 0;

  constructor(private apiKey: string, private request: typeof fetch = fetch) {}

  private async call(path: string, fieldMask: string, body?: unknown) {
    if (!this.apiKey) throw new AppError(503, "Google Maps pretraga nije podesena na serveru.");
    if (Date.now() - this.windowStart >= 60_000) {
      this.windowStart = Date.now();
      this.requests = 0;
    }
    if (++this.requests > 30) throw new AppError(429, "Previse Maps zahtjeva. Pokusajte za minut.");
    let response: Response;
    try {
      response = await this.request(`https://places.googleapis.com/v1/${path}`, {
        method: body ? "POST" : "GET",
        headers: { "Content-Type": "application/json", "X-Goog-Api-Key": this.apiKey, "X-Goog-FieldMask": fieldMask },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(8000)
      });
    } catch {
      throw new AppError(502, "Google Maps trenutno nije dostupan. Pokusajte ponovo.");
    }
    if (!response.ok) {
      if (response.status === 404) throw new AppError(400, "Mjesto vise nije dostupno na Google Maps.");
      if (response.status === 429) throw new AppError(503, "Google Maps kvota je potrosena. Pokusajte kasnije.");
      // Never log the key, request headers or upstream body.
      throw new AppError(502, "Google Maps zahtjev nije uspio. Provjerite Places API (New), kljuc i billing.");
    }
    try { return await response.json(); }
    catch { throw new AppError(502, "Google Maps je vratio neispravan odgovor."); }
  }

  async search(query: string): Promise<GooglePlace[]> {
    const data = await this.call("places:searchText", "places.id,places.displayName,places.formattedAddress,places.attributions", {
      textQuery: query, pageSize: 8, languageCode: "sr", regionCode: "ME"
    });
    return Array.isArray(data.places) ? data.places : [];
  }

  async verify(placeId: string): Promise<void> {
    placeIdSchema.parse(placeId);
    await this.call(`places/${encodeURIComponent(placeId)}`, "id");
  }
}
