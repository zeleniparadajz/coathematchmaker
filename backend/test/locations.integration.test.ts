import assert from "node:assert/strict";
import { test } from "node:test";
import mongoose from "mongoose";
import jwt from "jsonwebtoken";
import { once } from "node:events";

// Opt-in only: creates a unique local database and drops only that database.
test("location API authorization, persistence, legacy tournaments and challenges", { skip: !process.env.MONGO_TEST_URI }, async () => {
  const mongoUri = process.env.MONGO_TEST_URI!;
  assert.match(mongoUri, /^mongodb:\/\/(127\.0\.0\.1|localhost):\d+\/?$/);
  process.env.JWT_SECRET = "locations-test-only-secret";
  process.env.REQUIRE_EMAIL_VERIFICATION = "false";
  process.env.GOOGLE_PLACES_API_KEY = "";
  const database = `coa_locations_test_${process.pid}_${Date.now()}`;
  await mongoose.connect(mongoUri, { dbName: database });
  const { app } = await import("../src/app");
  const { Player } = await import("../src/models/Player");
  const { Location } = await import("../src/models/Location");
  const { Tournament } = await import("../src/models/Tournament");
  const server = app.listen(0, "127.0.0.1");
  await once(server, "listening");
  try {
    await Location.init();
    const player = (role: "admin" | "player") => Player.create({ firstName: role, lastName: "Test", role,
      email: `${role}@example.test`, password: "test-password", birthDate: new Date("1990-01-01"), country: "ME", sport: "tennis" });
    const admin = await player("admin");
    const member = await player("player");
    const token = (id: string) => jwt.sign({ sub: id }, process.env.JWT_SECRET!);
    const adminToken = token(String(admin._id));
    const memberToken = token(String(member._id));
    const port = (server.address() as { port: number }).port;
    async function request(path: string, auth = memberToken, method = "GET", body?: unknown) {
      const response = await fetch(`http://127.0.0.1:${port}/api${path}`, {
        method, headers: { "Content-Type": "application/json", ...(auth ? { Authorization: `Bearer ${auth}` } : {}) },
        ...(body ? { body: JSON.stringify(body) } : {})
      });
      return { status: response.status, data: await response.json() };
    }
    assert.equal((await request("/locations", "")).status, 401);
    assert.equal((await request("/locations", memberToken, "POST", { name: "X" })).status, 403);
    assert.equal((await request("/locations/search", memberToken, "POST", { query: "Budva" })).status, 403);
    assert.equal((await request("/locations/search", adminToken, "POST", { query: "Budva" })).status, 503);
    assert.equal((await request("/locations", adminToken, "POST", { name: " " })).status, 400);
    const a = (await request("/locations", adminToken, "POST", { name: "Teren A", address: "Budva" })).data.location;
    const b = (await request("/locations", adminToken, "POST", { name: "Teren B", address: "Bar" })).data.location;
    const body = { name: "Kobaja Grande (Sezona 2)", discipline: "singles", category: "Seniori", surface: "Hard", startDate: "2026-10-01", endDate: "2026-10-02" };
    const created = await request("/tournaments", memberToken, "POST", { ...body, locationIds: [a._id, b._id] });
    assert.equal(created.status, 201);
    assert.deepEqual(created.data.tournament.locations.map((v: { _id: string }) => v._id), [a._id, b._id]);
    const id = created.data.tournament._id;
    assert.equal((await request(`/locations/${a._id}`, memberToken, "PATCH", { name: "Hacked" })).status, 403);
    assert.equal((await request(`/locations/${a._id}`, adminToken, "PATCH", { name: "Teren A novi" })).status, 200);
    assert.equal((await request(`/tournaments/${id}`)).data.tournament.locations[0].name, "Teren A novi");
    await request(`/locations/${b._id}`, adminToken, "PATCH", { active: false });
    assert.equal((await request("/locations?all=true", memberToken)).data.locations.length, 1);
    assert.equal((await request("/locations?all=true", adminToken)).data.locations.length, 2);
    assert.equal((await request("/tournaments", memberToken, "POST", { ...body, locationIds: [b._id] })).status, 400);
    assert.equal((await request(`/tournaments/${id}`, memberToken, "PATCH", { locationIds: [a._id, b._id] })).status, 200);
    assert.equal((await request(`/tournaments/${id}`, memberToken, "PATCH", { locationIds: [a._id, a._id] })).status, 400);
    assert.equal((await request(`/tournaments/${id}`, memberToken, "PATCH", { name: "New title" })).status, 200);
    assert.equal((await Tournament.findById(id))!.locations.length, 2);
    const legacy = await request("/tournaments", memberToken, "POST", { ...body, location: "Stari teren" });
    assert.equal(legacy.status, 201);
    await request(`/tournaments/${legacy.data.tournament._id}`, memberToken, "PATCH", { name: "Old tournament renamed" });
    assert.equal((await request(`/tournaments/${legacy.data.tournament._id}`)).data.tournament.location, "Stari teren");
    const challenge = await request("/matches/challenge", memberToken, "POST", { opponentId: admin._id, locationId: a._id });
    assert.equal(challenge.status, 201);
    assert.equal(challenge.data.match.venue._id, a._id);
    assert.equal(challenge.data.match.location, "Teren A novi, Budva");
    assert.equal((await request("/matches/challenge", memberToken, "POST", { opponentId: admin._id, locationId: b._id })).status, 400);
  } finally {
    server.closeAllConnections();
    await new Promise<void>((resolve, reject) => server.close((error) => error ? reject(error) : resolve()));
    assert.equal(mongoose.connection.name, database);
    await mongoose.connection.dropDatabase();
    await mongoose.disconnect();
  }
});
