import assert from "node:assert/strict";
import { test } from "node:test";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";
import express from "express";
import { once } from "node:events";
import { GooglePlacesService } from "../src/services/googlePlacesService";

test("direct Google selection, multiple venues, permissions, duplicates and provider outages", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const uri = process.env.MONGO_TEST_URI!;
  assert.match(uri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "autocomplete-test-only";
  process.env.REQUIRE_EMAIL_VERIFICATION = "false";
  const database = `coa_autocomplete_test_${process.pid}_${Date.now()}`;
  await mongoose.connect(uri, { dbName: database });
  const { Location } = await import("../src/models/Location");
  const { Player } = await import("../src/models/Player");
  const { Tournament } = await import("../src/models/Tournament");
  const { createLocationRoutes } = await import("../src/routes/locationRoutes");
  const { tournamentRoutes } = await import("../src/routes/tournamentRoutes");
  const { errorHandler } = await import("../src/middleware/errorHandler");
  let down = false;
  let googleCalls = 0;
  const maps = new GooglePlacesService("mock-only", async (value, init) => {
    googleCalls++;
    if (down) return new Response("upstream secret", { status: 500 });
    const url = new URL(String(value));
    if (url.pathname.endsWith(":autocomplete")) {
      assert.equal(JSON.parse(init!.body as string).sessionToken, "session_token_123456");
      return Response.json({ suggestions: [{ placePrediction: { placeId: "google-a", text: { text: "Google A" } } }] });
    }
    const id = url.pathname.split("/").at(-1);
    return Response.json({ id, displayName: { text: `Provider name ${id}` }, formattedAddress: "Provider address", attributions: [{ provider: "Attribution" }] });
  });
  const app = express().use(express.json());
  app.use("/api/locations", createLocationRoutes(maps));
  app.use("/api/tournaments", tournamentRoutes);
  app.use(errorHandler);
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    await Location.init();
    const createPlayer = (role: "player" | "admin") => Player.create({ firstName: role, lastName: "Test", role,
      email: `${role}@test.example`, password: "password123", birthDate: new Date("1990-01-01"), country: "ME", sport: "tennis" });
    const admin = await createPlayer("admin");
    const member = await createPlayer("player");
    const auth = (id: unknown) => jwt.sign({ sub: String(id) }, process.env.JWT_SECRET!);
    const memberToken = auth(member._id);
    const adminToken = auth(admin._id);
    const base = `http://127.0.0.1:${(server.address() as { port: number }).port}/api`;
    const request = async (path: string, body?: unknown, token = memberToken, method = "POST") => {
      const response = await fetch(base + path, { method, headers: { "Content-Type": "application/json", ...(token ? { Authorization: `Bearer ${token}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {}) });
      return { status: response.status, cache: response.headers.get("cache-control"), data: await response.json() };
    };
    const selection = (placeId: string) => ({ placeId, sessionToken: "session_token_123456", language: "en" });
    assert.equal((await request("/locations/autocomplete", { query: "Club", ...selection("google-a") }, "")).status, 401);
    assert.equal((await request("/locations/autocomplete", { query: "ab", sessionToken: "session_token_123456" })).status, 400);
    const predictions = await request("/locations/autocomplete", { query: "Club", sessionToken: "session_token_123456" });
    assert.equal(predictions.status, 200);
    assert.equal(predictions.cache, "no-store");
    assert.equal(predictions.data.places[0].id, "google-a");
    assert.equal((await request("/locations/google", { ...selection("../../bad") })).status, 400);
    const first = await request("/locations/google", { ...selection("google-a"), name: "Untrusted provider text", active: false });
    assert.equal(first.status, 200);
    assert.equal(first.data.location.googleDetails.displayName.text, "Provider name google-a");
    const a = first.data.location._id;
    const raw = await Location.findById(a).lean();
    assert.equal(raw!.googleOnly, true);
    assert.equal(raw!.name, "");
    assert.equal(raw!.address, "");
    assert.equal(raw!.active, true);
    assert.equal("googleDetails" in raw!, false);
    assert.equal((await request("/locations/google", selection("google-a"))).data.location._id, a);
    const simultaneous = await Promise.all([request("/locations/google", selection("google-b")), request("/locations/google", selection("google-b"))]);
    const b = simultaneous[0].data.location._id;
    assert.equal(b, simultaneous[1].data.location._id);
    assert.equal(await Location.countDocuments({ googlePlaceId: "google-b" }), 1);
    const manual = await request("/locations", { name: "Moj naziv", address: "Moj grad" }, adminToken);
    assert.equal(manual.status, 201);
    assert.equal((await request("/locations", { name: "Not allowed" })).status, 403);
    const ids = [a, manual.data.location._id, b];
    const tournament = await request("/tournaments", { name: "Three venues", discipline: "singles", locationIds: ids,
      location: "Provider text must not become a snapshot", category: "Seniori", surface: "Hard", startDate: "2026-10-01", endDate: "2026-10-02" });
    assert.equal(tournament.status, 201);
    assert.deepEqual(tournament.data.tournament.locations.map((location: { _id: string }) => location._id), ids);
    assert.equal(tournament.data.tournament.locations[0].name, "Google Maps");
    assert.equal(tournament.data.tournament.locations[0].customName, "");
    const storedTournament = await Tournament.findById(tournament.data.tournament._id).lean();
    assert.equal(storedTournament!.location, "Google Maps; Moj naziv, Moj grad; Google Maps");
    const resolved = await request("/locations/resolve", { ids });
    assert.equal(resolved.data.places[a].formattedAddress, "Provider address");
    assert.equal(resolved.data.places[manual.data.location._id], undefined);
    assert.equal((await request(`/locations/${a}`, { name: "Hacked" }, memberToken, "PATCH")).status, 403);
    assert.equal((await request(`/locations/${a}`, { name: "Naš teren", address: "Naša adresa" }, adminToken, "PATCH")).status, 200);
    assert.equal((await Location.findById(a))!.name, "Naš teren");
    await request(`/locations/${a}`, { active: false }, adminToken, "PATCH");
    assert.equal((await request("/locations/google", selection("google-a"))).status, 400);
    down = true;
    assert.deepEqual((await request("/locations/resolve", { ids: [b] })).data.places, {});
    const failed = await request("/locations/google", selection("google-c"));
    assert.equal(failed.status, 502);
    assert.equal(JSON.stringify(failed.data).includes("upstream secret"), false);
    assert.equal(await Location.countDocuments({ googlePlaceId: "google-c" }), 0);
    assert.ok(googleCalls > 0);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close(error => error ? reject(error) : resolve()));
    assert.equal(mongoose.connection.name, database);
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
