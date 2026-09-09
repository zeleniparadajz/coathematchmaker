import assert from "node:assert/strict";
import { test } from "node:test";
import { locationSchema, locationIdsSchema, resolveLocations, tournamentLocationPatch } from "../src/services/locationService";
import { GooglePlacesService } from "../src/services/googlePlacesService";

const first = { _id: "123456789012345678901234", name: "Klub A", address: "Budva", active: true };
const second = { _id: "123456789012345678901235", name: "Klub B", address: "Bar", active: false };

test("venue input rejects invalid IDs, duplicates, empty names and untrusted fields", () => {
  assert.equal(locationIdsSchema.safeParse([first._id, first._id]).success, false);
  assert.equal(locationIdsSchema.safeParse(["not-an-id"]).success, false);
  assert.equal(locationSchema.safeParse({ name: "   " }).success, false);
  assert.equal(locationSchema.safeParse({ name: "A", googlePlaceId: "../../secret" }).success, false);
  assert.deepEqual(locationSchema.parse({ name: " A ", latitude: 10, provider: "google" }), { name: "A", address: "", active: true });
});

test("resolution preserves chosen order and permits inactive venues only for an existing reference", async () => {
  const find = async () => [first, second];
  assert.deepEqual((await resolveLocations([second._id, first._id], [second._id], find)).map((v) => v.name), ["Klub B", "Klub A"]);
  await assert.rejects(resolveLocations([second._id], [], find), /vise nije dostupna/);
  await assert.rejects(resolveLocations(["123456789012345678901236"], [], find), /vise nije dostupna/);
});

test("new tournaments use shared venues; legacy edits remain backwards compatible", async () => {
  const resolve = async () => [first, second];
  assert.deepEqual(await tournamentLocationPatch({ locationIds: [first._id, second._id] }, undefined, resolve), {
    locations: [first._id, second._id], location: "Klub A, Budva; Klub B, Bar"
  });
  const existing = { location: "Stari teren", locations: [first._id] };
  assert.deepEqual(await tournamentLocationPatch({}, existing), {});
  assert.deepEqual(await tournamentLocationPatch({ location: "Stari teren" }, existing), {});
  assert.deepEqual(await tournamentLocationPatch({ location: "Novi unos" }, existing), { location: "Novi unos", locations: [] });
  await assert.rejects(tournamentLocationPatch({ locationIds: [] }), /barem jednu/);
  await assert.rejects(tournamentLocationPatch({}), /barem jednu/);
});

test("Google search is server-side, restricted fields, no cache and friendly errors", async () => {
  let calls = 0;
  const service = new GooglePlacesService("test-key", async (url, init) => {
    calls++;
    assert.equal(url, "https://places.googleapis.com/v1/places:searchText");
    assert.equal(init?.method, "POST");
    assert.equal((init?.headers as Record<string, string>)["X-Goog-Api-Key"], "test-key");
    assert.equal((init?.headers as Record<string, string>)["X-Goog-FieldMask"].includes("attributions"), true);
    assert.equal(JSON.parse(init!.body as string).textQuery, "Klub Budva");
    return Response.json({ places: [{ id: "place-a", displayName: { text: "A" } }] });
  });
  assert.equal((await service.search("Klub Budva"))[0].id, "place-a");
  await service.search("Klub Budva");
  assert.equal(calls, 2);
  await assert.rejects(new GooglePlacesService("").search("Budva"), /nije podesena/);
  await assert.rejects(new GooglePlacesService("private-key", async () => new Response("secret upstream error", { status: 403 })).search("Budva"),
    (error: Error) => !error.message.includes("private-key") && !error.message.includes("secret upstream"));
  await assert.rejects(new GooglePlacesService("key", async () => { throw Error("network failure"); }).search("Budva"), /trenutno nije dostupan/);
});

test("Google verifies a place ID and limits calls across all users of the instance", async () => {
  let calls = 0;
  const service = new GooglePlacesService("key", async (url, init) => {
    calls++;
    assert.equal(url, "https://places.googleapis.com/v1/places/place-a");
    assert.equal((init?.headers as Record<string, string>)["X-Goog-FieldMask"], "id");
    return Response.json({ id: "place-a" });
  });
  for (let i = 0; i < 30; i++) await service.verify("place-a");
  await assert.rejects(service.verify("place-a"), /Previse Maps zahtjeva/);
  assert.equal(calls, 30);
});
