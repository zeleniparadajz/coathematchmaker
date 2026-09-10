# Lokacije: automatska pretraga i vise mjesta

## Korisnicki tok

- Novi turnir / Uredi turnir -> Lokacije otvara zajednicki izbor.
- Kucanje najmanje tri znaka automatski pokrece Google Places Autocomplete (New),
  nakon 400 ms pauze. Ne postoji obavezno dugme za pretragu, unos linka niti
  poseban formular za Google mjesto. Stariji odgovori ne mijenjaju novije rezultate.
- Jedan dodir na Google predlog dodaje mjesto u izbor. Pretraga se ocisti, pa se
  odmah moze traziti sledece mjesto. Turnir cuva do 20 lokacija, u izabranom redoslijedu.
- Izabrana mjesta imaju pojedinacne oznake za uklanjanje i brojac. Dok je tastatura
  otvorena potvrda je u vrhu ekrana, sa brojem izabranih mjesta.
- U formi turnira svako mjesto je zaseban red, umjesto jednog dugog spojenog naziva.
- Glavni admin ima i "Dodaj rucno", cak i kada nema rezultata ili Google ne radi.
  Ukucani tekst se prenosi u naziv; sopstveni naziv i adresu moze izmijeniti.
- Profil -> Lokacije -> dodavanje koristi isti novi izbor. Uredjivanje postojece
  lokacije i dalje omogucava sopstveni naziv/adresu, vezu sa Google mjestom i deaktiviranje.
- Obicni clanovi mogu traziti i izabrati Google mjesto za turnir/izazov, ali ne
  mogu preimenovati ili deaktivirati zajednicka mjesta niti praviti rucne unose.
- Izazov i dalje bira samo jedno mjesto. Stari tekstualni unosi i neaktivna mjesta
  vec vezana za postojeci turnir ostaju podrzani.

## Podaci i API

Postojeca kolekcija `locations` i niz `Tournament.locations` su zadrzani.
Novo polje `googleOnly` razlikuje direktno izabrano Google mjesto od ranijeg
klupskog unosa. Podrazumijevana vrijednost je false; migracija starih zapisa nije potrebna.

Autentifikovane rute:

- `POST /api/locations/autocomplete`: query, sessionToken, language (sr/en).
- `POST /api/locations/google`: placeId, sessionToken, language; provjeri mjesto i
  vrati postojeci zapis ili napravi novi. Ne prihvata Google naziv/adresu od klijenta.
- `POST /api/locations/details`: zavrsava sesiju pri povezivanju rucnog unosa.
- `POST /api/locations/resolve`: do 20 lokalnih ID-jeva; privremeni podaci za prikaz.

Google-only zapis trajno cuva samo Google place ID od podataka dobavljaca. Naziv
i adresa iz Google odgovora ne prepisuju se u Mongo, istoriju turnira niti lokalni
persistentni cache. LeagueService ih razrjesava za tekuci prikaz. Paralelni zahtjevi
za iste detalje dijele samo aktivni zahtjev; zavrseni odgovori se ne kesiraju.
Sopstveni nazivi/adrese imaju prednost i trajno se cuvaju kao i ranije.

Za turnire/meceve se u tekstualni legacy snapshot upisuje sopstveni naziv ili
genericka oznaka "Google Maps", nikada automatski Google naziv/adresa.
Stariji build dobija genericku oznaku za nova Google-only mjesta. Novi prikaz,
ako Google nije dostupan, zadrzava sopstveni naziv ili "Google Maps" i tacan Maps
link; ne prikazuje izmisljeno mjesto i ne blokira cijelu stranicu.

Indeks `googlePlaceId` ostaje unique/sparse. Istovremeni izbor istog mjesta
ne stvara duplikat. Izbor ne reaktivira ranije deaktivirano mjesto.
Sve location rute koriste `Cache-Control: no-store`. Kljuc ostaje iskljucivo na serveru.
Nova pretraga/izbor/razrjesavanje imaju 30 zahtjeva/minut po korisniku; ukupno je
do 120 poziva/minut po API procesu. Za produkciju zadrzati Google Cloud kvote i
upozorenja za naplatu. Ovo nisu zajednicke kvote za vise API instanci.
Detalji se traze pri prikazu, pa automatska pretraga i broj pregleda uticu na potrosnju.

Prikaz sadrzi Google Maps atribuciju i atribucije drugih dobavljaca kada postoje.
Relevantna dokumentacija: [Autocomplete](https://developers.google.com/maps/documentation/places/web-service/place-autocomplete),
[sesije](https://developers.google.com/maps/documentation/places/web-service/using-session-tokens),
[pravila cuvanja i atribucije](https://developers.google.com/maps/documentation/places/web-service/policies).
Javni uslovi koriscenja i politika privatnosti i dalje moraju pokrivati Google Maps.

## Primjena i provjera

Koristi se isti `GOOGLE_PLACES_API_KEY` i ukljuceni Places API (New); nema novog
obaveznog `.env` polja. Prvo postaviti ovaj backend, pa novi mobilni build.
Pripremljeni `COA-1.0.3-8.aab` nije promijenjen i ne sadrzi ove naknadne izmjene.
Verzija u `pubspec.yaml` nije ponovo povecavana. Nije uradjen deploy, push ili
upload novog paketa, niti su promijenjeni serverski pragovi za update.

Testovi koriste simulirane Google odgovore i izolovane lokalne Mongo baze,
bez naplate pravih Google zahtjeva ili mijenjanja produkcijskih podataka.
Stvarni kljuc, ogranicenje IP adrese i billing treba provjeriti nakon deploya.
Snimci ekrana: `.local-backups/location-autocomplete-20260910/*.png`.

Zavrsna provjera: 130 Flutter testova i 25 backend testova proslo, bez preskocenih
backend integracionih testova. `flutter analyze --no-pub`, `npm run typecheck`,
`npm run build` i `git diff --check` su prosli. Vizuelno su pregledani standardni
ekran pretrage, uski ekran sa tri izbora i ekran sa otvorenom tastaturom.

## Povratak

Prethodne verzije izmijenjenih fajlova su u:
`.local-backups/location-autocomplete-20260910/before.tar.gz`.
Ova arhiva ne sadrzi `.env`, bazu, kljuceve ili slike korisnika.
Postojece izmjene pripreme builda 8 ostale su netaknute.

Novi fajlovi za ovu izmjenu su:

- `lib/services/place_search_controller.dart`
- `lib/widgets/google_maps_attribution.dart`
- `test/location_autocomplete_test.dart`
- `backend/test/locationAutocomplete.integration.test.ts`
- ovaj dokument

Vracati samo ove izmjene, uz provjeru kasnijih izmjena u istim fajlovima.
Ne raditi `git reset --hard`. Povratak koda ne brise nove zapise iz baze;
prije povratka backenda napraviti kopiju baze, jer stari backend ne poznaje
Google-only zapise bez klupskog naziva.
