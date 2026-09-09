# Round-robin sa opcionom knockout zavrsnicom

## Koriscenje

U kreiranju ili uredjivanju turnira izabrati **Round-robin + knockout (opciono)**.
Prekidac **Knockout zavrsnica** ukljucuje zavrsnicu sa 2, 4, 8 ili 16 ucesnika.
Iskljucen prekidac ostavlja obican round-robin. Naziv formata na kartici i detalju
postaje **Round-robin + knockout** samo kada je opcija ukljucena; vlastiti naziv
turnira se ne mijenja. Trenutno je zavrsnica za singl, ne za dubl timove.

Opcija se moze ukljuciti na postojecoj, nezavrsenoj round-robin ligi bez brisanja
meceva. Nakon formiranja ligaskih meceva ucesnici i disciplina su zakljucani.
Knockout broj moze se mijenjati do pokretanja zavrsnice. Druge vrste turnira,
ukljucujuci raniju opciju `group_knockout`, nijesu prosirene ovim zadatkom.

Tabela koristi samo potvrdjene `RR` meceve, ukljucujuci prijateljske. Poredak:

1. Broj pobjeda.
2. Broj medjusobnih pobjeda unutar grupe sa istim ukupnim brojem pobjeda.
3. Ukupna razlika osvojenih i izgubljenih setova u ligi.
4. Ukupna razlika osvojenih i izgubljenih gemova u ligi.
5. Redosljed prijave (redosljed u `participants`) ako sve ostalo ostane jednako.

Ovo su pravila aplikacije, ne tvrdnja o univerzalnim teniskim pravilima.
Pravila su dostupna preko info ikone pored tabele; nema nasumicnog razrjesavanja.

Svaki par ucesnika mora imati tacno jedan RR mec sa potvrdjenim rezultatom prije
pocetka zavrsnice. Nepotpuni, duplirani, sporni ili otkazani mecevi blokiraju start.
Admin turnira, vlasnik ili glavni admin pregleda i potvrdi parove. Za 4 ucesnika
parovi su 1-4 i 2-3. U vecim zrijebovima prva dva nosioca ostaju u razlicitim
polovinama. Zastarjeli pregled parova se odbija i trazi ponovno ucitavanje.

Prikazi **Liga** i **Knockout** su odvojeni. Dodavanje knockout meceva ne mijenja
ligasku tabelu. Mec se otvara dodirom, kroz postojeci ekran za unos/potvrdu rezultata.
Naredna runda se formira tek poslije potvrde svih rezultata trenutne runde.
Potvrdjeno finale omogucava **Potvrdi pobjednika**. Prijateljski turniri ne dobijaju
rang bodove; takmicarski koriste postojece postavke bodovanja.

## Podaci i API

Postojeci `format: round_robin` ostaje isti radi kompatibilnosti. Novi podaci:

- `knockoutSize`: 0 (iskljuceno), 2, 4, 8 ili 16.
- `knockoutSeeds`: zamrznuti redosljed kvalifikovanih igraca.
- `knockoutStartedAt`: pocetak zavrsnice.
- `knockoutRounds`: nazivi rundi i unaprijed rezervisani ID-jevi meceva.

`GET /api/tournaments/:id/round-robin` vraca tabelu, pravila, predlozene parove i
stanje faze. Postojece provjere privatnosti turnira vaze i za ovaj endpoint.
`POST /api/tournaments/:id/start-knockout` prima `seeds` iz odobrenog pregleda.
`POST /api/tournaments/:id/advance-round` za zavrsnicu prima trenutni `round`.
Mutacije su ogranicene na upravljace turnira. Stari klijenti ne brisu novu opciju
ako ne posalju `knockoutSize`; aplikacija nema novu env varijablu za ovu funkciju.

Rezervisanje ID-jeva je atomsko na dokumentu turnira, a upis meceva ponovljiv po
istim ID-jevima. Ponovljeni/simultani klikovi ne dupliraju zrijeb i ne prepisuju
rezultate. Ako je formiranje prekinuto, admin ima **Dovrsi formiranje meceva**.
Potvrdjeni rezultati i identiteti meceva u ukljucenom hibridnom turniru su zakljucani;
rucno dodavanje meceva poslije pocetka zavrsnice je blokirano.

## Deploy i provjera

Nema migracije, izmjene `.env`, build broja ili automatskog deploya.
Poslije commita/pusha povuci backend i izgradi API servis:

```sh
cd ~/coathematchmaker/backend
git pull --ff-only
docker compose up -d --build api
```

Novi mobilni kod pokrenuti nakon backend deploya. Za korisnike prodavnice potreban
je novi mobilni build; ovu promjenu nije potrebno ukljucivati za svaki turnir kroz env.

```sh
flutter analyze
flutter test
cd backend
npm run typecheck
MONGO_TEST_URI=mongodb://127.0.0.1:27019 npm test
```

Integracioni test radi u zasebnoj privremenoj lokalnoj bazi `coa_knockout_test_*`
i brise samo nju. Pokriva dozvole, privatnost, ukljucivanje na staroj ligi,
nepotpunu ligu, zastarjeli pregled, istovremene klikove, oporavak nepotpunog upisa,
napredovanje za 2/4/8/16, zakljucane rezultate i jednokratnu potvrdu pobjednika.
Widget testovi pokrivaju formu, stanje opcije, potvrdu/odustajanje, odvojene faze
i sirine 320/390/1024 uz uvecan tekst na uskom telefonu.

Vizuelna provjera:

```sh
flutter test test/round_robin_test.dart --update-goldens --dart-define=CAPTURE_KNOCKOUT=true
```

## Povratak

Stanje prije ovog zadatka je commit `0223e35c011985a62fa7c089d4ee55c2f28e7479`
i lokalna arhiva `.local-backups/round-robin-knockout-20260909/before.tar.gz`.
Arhiva obuhvata kod, testove i dokumentaciju; ne ukljucuje `.env`, Mongo podatke
ili uploadovane slike. Raniji backup-i nijesu mijenjani.

Vracati samo izmjene ovog zadatka, uz prethodnu provjeru kasnijih izmjena. Ne
prepisivati citav projekat i ne koristiti `git reset --hard`. Vracanje koda nije
vracanje produkcijske baze: eventualno vec odigrani knockout mecevi moraju ostati
sacuvani i prije povratka koda zahtijevaju poseban dogovor.
