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
  private detailsInFlight = new Map<string, Promise<GooglePlace>>();

  constructor(private apiKey: string, private request: typeof fetch = fetch, private limit = 120) {}

  private async call(path: string, fieldMask: string, body?: unknown) {
    if (!this.apiKey) throw new AppError(503, "Google Maps pretraga nije podešena na serveru.");
    if (Date.now() - this.windowStart >= 60_000) {
      this.windowStart = Date.now();
      this.requests = 0;
    }
    if (++this.requests > this.limit) throw new AppError(429, "Previše zahtjeva za Google Maps. Pokušajte za minut.");
    let response: Response;
    try {
      response = await this.request(`https://places.googleapis.com/v1/${path}`, {
        method: body ? "POST" : "GET",
        headers: { "Content-Type": "application/json", "X-Goog-Api-Key": this.apiKey, "X-Goog-FieldMask": fieldMask },
        ...(body ? { body: JSON.stringify(body) } : {}),
        signal: AbortSignal.timeout(8000)
      });
    } catch {
      throw new AppError(502, "Google Maps trenutno nije dostupan. Pokušajte ponovo.");
    }
    if (!response.ok) {
      if (response.status === 404) throw new AppError(400, "Mjesto više nije dostupno na Google mapama.");
      if (response.status === 429) throw new AppError(503, "Kvota za Google Maps je potrošena. Pokušajte kasnije.");
      // Never log the key, request headers or upstream body.
      throw new AppError(502, "Zahtjev za Google Maps nije uspio. Provjerite Places API (New), ključ i podešavanja naplate.");
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

  async autocomplete(query: string, sessionToken: string, language = "sr"): Promise<GooglePlace[]> {
    const data = await this.call("places:autocomplete",
      "suggestions.placePrediction.placeId,suggestions.placePrediction.structuredFormat,suggestions.placePrediction.text", {
        input: query, sessionToken, languageCode: language, regionCode: "ME",
        locationBias: { rectangle: { low: { latitude: 41.8, longitude: 18.4 }, high: { latitude: 43.6, longitude: 20.4 } } }
      });
    return (Array.isArray(data.suggestions) ? data.suggestions : [])
      .flatMap((item: { placePrediction?: { placeId?: string; text?: { text?: string }; structuredFormat?: {
        mainText?: { text?: string }; secondaryText?: { text?: string };
      } } }) => {
        const place = item.placePrediction;
        return place?.placeId ? [{ id: place.placeId,
          displayName: { text: place.structuredFormat?.mainText?.text ?? place.text?.text ?? "" },
          formattedAddress: place.structuredFormat?.secondaryText?.text ?? "" }] : [];
      });
  }

  async details(placeId: string, sessionToken?: string, language = "sr"): Promise<GooglePlace> {
    placeIdSchema.parse(placeId);
    const query = new URLSearchParams({ languageCode: language });
    if (sessionToken) query.set("sessionToken", sessionToken);
    const path = `places/${encodeURIComponent(placeId)}?${query}`;
    const pending = this.detailsInFlight.get(path);
    if (pending) return pending;
    const request = this.call(path, "id,displayName,formattedAddress,attributions").then(data => {
      if (data.id !== placeId || !data.displayName?.text) throw new AppError(502, "Google Maps je vratio neispravan odgovor.");
      return { id: data.id, displayName: data.displayName, formattedAddress: data.formattedAddress,
        attributions: data.attributions ?? [] } as GooglePlace;
    });
    this.detailsInFlight.set(path, request);
    // Coalesce simultaneous screen loads, but retain no provider content after completion.
    try { return await request; }
    finally { this.detailsInFlight.delete(path); }
  }
}
