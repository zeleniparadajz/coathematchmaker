# Coa The Matchmaker Backend

REST API za Flutter aplikaciju za tenis klub ili lokalnu ligu.

## Stack

- Node.js + Express
- TypeScript
- MongoDB + Mongoose
- JWT auth
- Docker + docker-compose

## Lokalno pokretanje preko Dockera

```bash
cd backend
cp .env.example .env
docker compose up --build
```

API je dostupan na:

```text
http://localhost:4000
```

Ako u `.env` staviš npr. `PORT=5001`, API će biti dostupan na:

```text
http://localhost:5001
```

Health check:

```bash
curl http://localhost:4000/health
```

## Lokalno pokretanje bez Dockera

Potrebna je lokalna MongoDB instanca.

```bash
cd backend
cp .env.example .env
npm install
npm run dev
```

Ako MongoDB nije u Dockeru, u `.env` promijeni:

```text
MONGO_URI=mongodb://localhost:27017/coathematchmaker
```

Za Docker compose se koristi `DOCKER_MONGO_URI`, jer iz API containera MongoDB nije `localhost`, nego Docker servis `mongo`.

## Auth

Registracija igrača:

```http
POST /api/auth/register
```

```json
{
  "firstName": "Novak",
  "lastName": "Djokovic",
  "email": "novak@example.com",
  "password": "password123",
  "birthDate": "1987-05-22",
  "country": "Serbia",
  "club": "Local Tennis Club"
}
```

Registracija admina koristi isti endpoint, uz `adminCode` koji mora odgovarati `ADMIN_REGISTRATION_CODE` iz `.env`.

Login:

```http
POST /api/auth/login
```

```json
{
  "email": "novak@example.com",
  "password": "password123"
}
```

Email potvrda:

- `GET /api/auth/verify-email?token=<token>` - potvrđuje email
- `POST /api/auth/resend-verification` - šalje novi verification link
- `POST /api/auth/forgot-password` - šalje email za reset lozinke
- `GET /api/auth/reset-password?token=<token>` - otvara formu za novi password
- `POST /api/auth/reset-password` - API reset lozinke, body: `{ "token": "...", "password": "newPassword123" }`

U development modu, ako `RESEND_API_KEY` nije podešen, verification link se ispisuje u backend log. Za online testiranje podesi:

```text
APP_URL=http://161.97.74.146:4000
REQUIRE_EMAIL_VERIFICATION=true
RESEND_API_KEY=...
EMAIL_FROM=Coa The Matchmaker <verified-sender@tvoj-domen.com>
```

`APP_URL` mora biti javni URL backend API-ja, jer se taj link šalje u emailu. Ako testiraš sa telefona i backend je u Dockeru na Linux serveru, ostavi IP ili domen servera, npr. `http://161.97.74.146:4000`. Za produkciju je bolje staviti domen sa HTTPS-om.

Za Resend slanje:

- `RESEND_API_KEY` mora biti validan API key iz Resend naloga
- `EMAIL_FROM` treba da bude verifikovan sender/domen, npr. `Coa The Matchmaker <noreply@tvoj-domen.com>`
- `onboarding@resend.dev` je dobar samo za ograničeno testiranje i može biti blokiran za slanje na tuđe email adrese
- poslije izmjene `.env` restartuj Docker containere

Ako želiš privremeno testiranje bez blokiranja login-a prije email potvrde:

```text
REQUIRE_EMAIL_VERIFICATION=false
```

Kad je `REQUIRE_EMAIL_VERIFICATION=true`, običan igrač dobija email nakon registracije i ne može koristiti JWT/login dok ne otvori verification link. Admin nalozi kreirani sa validnim `adminCode` su odmah potvrđeni.

Odgovor vraća JWT token:

```json
{
  "token": "...",
  "player": {}
}
```

Za zaštićene rute šalji header:

```text
Authorization: Bearer <token>
```

## Glavni endpoint-i

### Players

- `GET /api/players` - lista igrača
- `GET /api/players/me` - moj profil
- `PATCH /api/players/me` - izmjena mog profila
- `POST /api/players/me/profile-image` - upload moje profilne slike
- `GET /api/players/:id` - detalji igrača
- `PATCH /api/players/:id` - admin izmjena igrača
- `POST /api/players/:id/profile-image` - admin upload slike za igrača

Upload profilne slike:

```bash
curl -X POST http://localhost:5001/api/players/me/profile-image \
  -H "Authorization: Bearer <token>" \
  -F "profileImage=@/path/to/photo.jpg"
```

API vraća relativni URL, npr. `/uploads/profile-images/file.jpg`. Flutter ga spaja sa baznim URL-om API-ja.

### Tournaments

- `GET /api/tournaments` - lista turnira
- `POST /api/tournaments` - admin kreira turnir
- `GET /api/tournaments/:id` - detalji turnira
- `PATCH /api/tournaments/:id` - admin izmjena turnira
- `POST /api/tournaments/:id/register` - prijava trenutno ulogovanog igrača
- `POST /api/tournaments/:id/participants` - admin dodaje igrača
- `DELETE /api/tournaments/:id/participants/:playerId` - admin uklanja igrača prije žrijeba
- `POST /api/tournaments/:id/matches` - admin ručno kreira meč u turniru
- `POST /api/tournaments/:id/generate-draw` - admin automatski formira žrijeb
- `POST /api/tournaments/:id/advance-round` - admin generiše sljedeću rundu iz confirmed pobjednika
- `POST /api/tournaments/:id/finish` - admin završava turnir i dodjeljuje pobjednika
- `GET /api/tournaments/:id/rankings` - ranking unutar turnira

Primjer kreiranja turnira:

```json
{
  "name": "Ljetnja liga 2026",
  "location": "Podgorica",
  "surface": "Clay",
  "category": "Seniori",
  "format": "elimination",
  "startDate": "2026-06-01",
  "endDate": "2026-06-15",
  "status": "upcoming"
}
```

Turnir čuva naziv, lokaciju, podlogu, kategoriju, datum početka/kraja, status, listu učesnika i listu mečeva. Podržani formati su `elimination`, `qualification`, `round_robin`, `group_knockout`, `double_elimination`, `compass` i `swiss`.

Automatski žrijeb:

- `elimination` pravi prvu rundu prema najbližem 2^n bracketu i dodjeljuje BYE ako broj igrača nije 8, 16, 32 itd.
- runde se označavaju kao `R32`, `R16`, `QF`, `SF`, `F`
- `round_robin` automatski pravi meč svakog sa svakim i runda je `RR`
- `group_knockout` pravi round-robin mečeve po grupama, runde `G1`, `G2` itd.
- `double_elimination` pravi početni winners bracket sa rundama `W-R16`, `W-QF` itd.
- `compass` pravi početni compass bracket sa rundama `C-R16`, `C-QF` itd.
- `swiss` pravi prvo kolo uparenih mečeva sa rundom `SW1`

### Matches

- `GET /api/matches` - lista mečeva
- `GET /api/matches?tournament=<id>` - mečevi po turniru
- `GET /api/matches/my` - moji mečevi i challenge-i
- `GET /api/matches/pending` - pending challenge-i gdje sam izazvani igrač
- `GET /api/matches/disputed` - admin lista spornih mečeva
- `GET /api/matches/:id` - detalji meča
- `POST /api/matches/challenge` - igrač kreira challenge protiv drugog igrača
- `POST /api/matches/:id/accept` - izazvani igrač prihvata challenge
- `POST /api/matches/:id/reject` - izazvani igrač odbija challenge
- `POST /api/matches/:id/submit-result` - jedan od igrača unosi rezultat nakon prihvatanja i čekanja
- `POST /api/matches/:id/confirm-result` - drugi igrač potvrđuje rezultat
- `POST /api/matches/:id/dispute` - drugi igrač osporava rezultat
- `POST /api/matches/:id/admin-resolve` - admin potvrđuje, odbija ili poništava sporni meč
- `POST /api/matches` - admin direktno unosi meč
- `PATCH /api/matches/:id` - admin uređuje meč

Challenge flow:

1. User A kreira challenge protiv User B.
2. Meč dobija status `pending`.
3. User B prihvata ili odbija.
4. Nakon prihvatanja status je `accepted`.
5. Rezultat se može unijeti tek nakon `resultEntryDelayMinutes`.
6. Jedan igrač unosi rezultat, status postaje `waiting_confirmation`.
7. Drugi igrač potvrđuje ili osporava rezultat.
8. Tek na `confirmed` status se računaju poeni.

Statusi:

```text
pending, accepted, waiting_confirmation, confirmed, rejected, disputed, cancelled
```

Primjer challenge-a:

```json
{
  "opponentId": "PLAYER_2_ID",
  "tournamentId": "OPTIONAL_TOURNAMENT_ID",
  "round": "Challenge"
}
```

Primjer unosa rezultata:

```json
{
  "sets": [
    { "player1Games": 6, "player2Games": 4 },
    { "player1Games": 7, "player2Games": 5 }
  ],
  "winner": "PLAYER_1_ID",
  "round": "Finale"
}
```

Admin resolve:

```json
{
  "action": "confirm",
  "winner": "PLAYER_1_ID",
  "sets": [
    { "player1Games": 6, "player2Games": 4 }
  ],
  "note": "Ručno riješeno poslije provjere."
}
```

### Settings

- `GET /api/settings` - trenutna liga podešavanja
- `PATCH /api/settings` - admin mijenja podešavanja

Podešavanja:

```json
{
  "resultEntryDelayMinutes": 60,
  "matchWinPoints": 10,
  "tournamentWinPoints": 50
}
```

### Rankings

- `GET /api/rankings` - generalna rang lista svih aktivnih igrača
- `GET /api/tournaments/:id/rankings` - rang lista za turnir

Pravila:

- pobjeda daje broj poena iz `matchWinPoints`
- osvajanje turnira daje broj poena iz `tournamentWinPoints`
- poeni iz meča se računaju samo kada je status meča `confirmed`
- ranking ignoriše `pending`, `accepted`, `waiting_confirmation`, `rejected`, `disputed` i `cancelled`
- generalna lista se sortira po ukupnim poenima
- ako su poeni isti, prednost ima igrač sa više pobjeda

## Napomene za Flutter

U Android emulatoru `localhost` iz aplikacije obično nije Mac, nego emulator. Za API sa Mac-a često koristi:

```text
http://10.0.2.2:4000
```

Za iOS simulator obično radi:

```text
http://localhost:4000
```

Na fizičkom telefonu koristi IP adresu Mac-a u lokalnoj mreži, npr:

```text
http://192.168.1.20:4000
```

MongoDB u Dockeru:

- API container koristi `MONGO_URI=mongodb://mongo:27017/coathematchmaker`
- MongoDB Compass sa Mac-a koristi `mongodb://localhost:27019/coathematchmaker` ako je compose port mapiran kao `27019:27017`
- promjena host porta ne briše podatke; Docker volume `backend_mongo_data` i dalje čuva staru bazu dok ga eksplicitno ne obrišeš
