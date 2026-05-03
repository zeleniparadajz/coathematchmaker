# Coa The Matchmaker

Flutter mobile app + Node.js backend za tenis igrače, turnire, mečeve i rang liste.

Backend je u zasebnom folderu:

```bash
cd backend
cp .env.example .env
docker compose up --build
```

API radi na:

```text
http://localhost:4000
```

Detaljna backend dokumentacija je u [backend/README.md](backend/README.md).

Flutter app koristi backend na `http://localhost:4000`. Ako testiraš na Android emulatoru, u [api_client.dart](lib/services/api_client.dart) promijeni base URL na `http://10.0.2.2:4000`.
