# Lokacije i Google Maps

## Sta je dodato

- Profil i podesavanja -> Lokacije (samo glavni admin).
- Dodavanje, uredjivanje i deaktiviranje zajednickih lokacija u Mongo kolekciji `locations`.
- Naziv i opciona adresa su vlastiti unosi kluba. Google pretraga povezuje taj unos
  sa tacnim mjestom preko `googlePlaceId`; ne prepisuje Google naziv/adresu u bazu.
- Pretraga preko Places API (New), eksplicitno na dugme, ne na svako slovo.
- Turnir bira 1-20 lokacija; pojedinacni izazov bira jednu ili nijednu.
- Svaka lokacija turnira ima zaseban link za Google Maps, sa place ID-jem kada postoji.
- Stari tekstualni unosi ostaju vidljivi i mogu se sacuvati bez ponovnog izbora.
- Deaktiviranje ne brise istoriju niti veze sa starim turnirima/mecevima.
- Dugi naslovi vise nisu ograniceni na dvije linije; broj ispred zavrsne zagrade
  ostaje uz prethodnu rijec. Kompaktna sirina kartica je zadrzana.

Registar pocinje prazan. Admin prvo dodaje lokacije. Stari tekstovi i nekadasnji
hardkodovani prijedlozi se ne uvoze automatski, da se ne naprave duplikati ili
pogresne veze sa Google mjestima. Postojeci turnir moze se kasnije povezati sa
registrom kroz Uredi turnir -> Lokacije. Automatski generisanom mecu ne dodjeljuje
se nasumicno jedno od vise mjesta turnira.

## Server

Zadrzati sve postojece `.env` vrijednosti. Dodati samo:

```dotenv
GOOGLE_PLACES_API_KEY=OVDJE_STAVITI_SERVER_KLJUC
```

U Google Cloud projektu ukljuciti **Places API (New)** i billing. Koristiti zaseban
serverski kljuc ogranicen na taj API i javnu izlaznu IP adresu servera. Kljuc ne ide
u Flutter, Git, screenshot ili chat. Postaviti Google Cloud kvote i billing alerts.
Search koristi polja ID, naziv, adresa i atribucije; provjera prije upisa trazi samo ID.
Server dodatno ogranicava Maps pozive na 30 u minuti po procesu (pretraga + provjera).
Za vise backend instanci podesiti zajednicku kvotu preko Google Cloud projekta.

Nakon commita i pusha, na serveru:

```sh
cd ~/coathematchmaker/backend
git pull --ff-only
docker compose up -d --build api
```

Ne mijenjati build pragove zbog ovoga. Za novi ekran potreban je novi mobilni build,
ali poslije toga dodavanje/uredjivanje mjesta ne zahtijeva novo izdanje aplikacije.
Ova izmjena nije podigla build broj i nije deployovana na server.

## Google podaci

Trajno se cuva samo Google place ID. Google nazivi, adrese i atribucije iz pretrage
prikazuju se u aktuelnoj pretrazi, bez trajnog cache-a. Google Maps oznaka ostaje
uz rezultate i prikazuju se vracene atribucije dobavljaca. Podaci se ne crtaju na
drugom map provideru. Otvaranje lokacije koristi zvanicni Maps URL.

Prije produkcije provjeriti javne uslove koriscenja i politiku privatnosti
aplikacije: moraju ukljuciti odgovarajuce Google uslove i politiku privatnosti.
Ti javni dokumenti nisu u ovom repozitorijumu i nisu izmijenjeni ovim zadatkom.
Google preporucuje osvjezavanje ID-jeva starijih od 12 mjeseci; mjesto koje je
premjesteno ili uklonjeno admin moze ponovo povezati preko pretrage.

Izvori: [Places pravila i atribucije](https://developers.google.com/maps/documentation/places/web-service/policies),
[Place IDs](https://developers.google.com/maps/documentation/places/web-service/place-id),
[Text Search](https://developers.google.com/maps/documentation/places/web-service/text-search),
[Maps URLs](https://developers.google.com/maps/documentation/urls/guide).

## Provjera

```sh
flutter analyze
flutter test
cd backend
npm run typecheck
npm test
# Opcioni HTTP + Mongo integracioni test, SAMO lokalni Mongo:
MONGO_TEST_URI=mongodb://127.0.0.1:27019 npm test
```

Integracioni test pravi jedinstvenu bazu `coa_locations_test_*` i po zavrsetku
brise samo nju. Ne koristi produkcijske podatke. Google odgovori u testovima su
simulirani: stvarni kljuc/billing se provjeravaju nakon podesavanja na serveru.

## Povratak

Izvorni fajlovi neposredno prije lokacija, sa svim ranijim izmjenama dizajna, su u:

`.local-backups/locations-20260909/before.tar.gz`

`changes.json` u istom direktorijumu biljezi fajlove i checksum-e prije/poslije.
Arhiva ne sadrzi `.env`, bazu ni uploadovane slike. Nije u Gitu.
Povratak raditi samo za fajlove iz ovog spiska, uz provjeru kasnijih izmjena;
ne prepisivati citav projekat arhivom i ne koristiti `git reset --hard`.
Originalni pre-refresh checkpoint i njegovi hash-evi ostaju netaknuti.
