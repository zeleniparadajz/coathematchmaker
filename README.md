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

Flutter app production default koristi backend na `https://coabackapi.zeleniparadajz.me`.
Za lokalno testiranje možeš override-ovati URL kroz dart define, npr. `--dart-define=API_URL=http://localhost:4000`.
