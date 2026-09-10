# COA Play Store Release

## Izdanje 1.0.3 (8), 9. septembar 2026.

- Android App Bundle, paket `me.coathematchmaker.app`.
- Izvor funkcionalnih izmjena: commit `64e5519` (`edit admin`).
- Verzija u `pubspec.yaml`: `1.0.3+8`.
- Koristi postojeći upload ključ; ne praviti novi keystore za ovo izdanje.
- iOS paket nije napravljen niti poslat. Verzija u `pubspec.yaml` je zajednička,
  pa je prije kasnijeg iOS izdanja treba provjeriti u App Store Connect-u.

Komanda za ponavljanje ovog Android builda:

```bash
flutter pub get
flutter build appbundle --release --no-pub --build-name=1.0.3 --build-number=8 --dart-define=API_URL=https://coabackapi.zeleniparadajz.me
```

Prije javne objave:

1. Provjeriti da build 8 nije ranije korišćen ni na jednoj Play Console stazi.
2. Postaviti najnoviji backend na server, uključujući izmjene rezultata,
   filtera i brisanja. Prije toga napraviti rezervnu kopiju baze i slika.
3. Postaviti AAB na Internal testing i provjeriti prijavu, slike, oba jezika,
   lokacije, rezultate i administratorske radnje na namjenskim test podacima.
4. Zatim poslati provjereno izdanje na produkcijsku stazu.
5. Tek kada je izdanje javno dostupno korisnicima, postaviti
   `APP_ANDROID_LATEST_BUILD=8`. Za obavezno ažuriranje postaviti i
   `APP_ANDROID_MIN_SUPPORTED_BUILD=8`, tek nakon pune dostupnosti izdanja,
   ne tokom ograničene postepene objave. Promjene zahtijevaju ponovno kreiranje
   API kontejnera. iOS vrijednosti ostaju nepromijenjene.

Sama izrada ili slanje AAB-a ne mijenja serversku konfiguraciju.
Tokom pripreme server je vraćao Android minimum 7 i latest 7; te vrijednosti
nisu mijenjane. Priprema paketa ne podrazumijeva deploy backenda niti objavu
na Play Store-u.

### Provjera napravljenog paketa

- Paket za slanje: `build/releases/COA-1.0.3-8.aab` (oko 60 MB).
- Originalni izlaz: `build/app/outputs/bundle/release/app-release.aab`.
- SHA-256: `2d55e16940bc94615c5b02356e07ac9400f1b456c687dfb5a175f150ef409ad1`.
- Manifest potvrđuje `me.coathematchmaker.app`, verziju `1.0.3`, build `8`,
  minimum Android API 24 i target API 36. Nije uključen debug režim.
- Provjeren potpis svih 434 stavke prema postojećem ključu `coa-upload`.
  Prihvatanje tog ključa provjerava se i prilikom slanja u Play Console.
- `bundletool validate` je prošao; paket traži 16 KB poravnanje, a svih
  12 ugrađenih nativnih biblioteka prošlo je provjeru ELF LOAD poravnanja.
- Prošlo je 115 Flutter testova, 21 backend test na lokalnim test bazama,
  `flutter analyze` i backend `npm run typecheck`.
- Instalacija ovog release paketa na Android uređaju još nije provjerena.
- Flutter je automatski dodao `android.builtInKotlin=false` i
  `android.newDsl=false` u `android/gradle.properties`. Upozorenja o budućoj
  Kotlin migraciji nisu spriječila izradu; zavisnosti nisu nadograđivane.

### Šta je novo

Izbor jezika MNE/ENG, poboljšan prikaz slika i novi filteri mečeva.
Dodate su zajedničke lokacije, više mjesta za turnire i Round-robin sa
opcionom knockout fazom. Prikaz poslednje aktivnosti i dostupnosti igrača.
Poboljšane su ispravke rezultata i administratorsko upravljanje turnirima i
mečevima, uz ispravke grešaka i poboljšanja stabilnosti.

### What's new

Choose MNE or English, enjoy improved photos and new match filters.
Shared venues, multiple tournament locations and optional knockout stages
for Round-robin tournaments are now available. See players' last activity
and availability. Improved result corrections and admin tools for managing
tournaments and matches, plus bug fixes and stability improvements.

### Povratak koda

Stanje prije promjene verzije sačuvano je u
`.local-backups/play-release-20260909/before.tar.gz`, a funkcionalne izmjene
u commitu `64e5519`. Rezervna kopija koda ne vraća podatke obrisane iz baze.
Stariji build se ne može ponovo objaviti kao novi Play Store update;
eventualni povratak funkcionalnosti zahtijeva novi, veći build broj.

## 1. Backend URL

Backend za testing i production:

```bash
https://coabackapi.zeleniparadajz.me
```

Build komanda:

```bash
flutter build appbundle --release --dart-define=API_URL=https://coabackapi.zeleniparadajz.me
```

## 2. Release signing

Napravi upload keystore:

```bash
keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias coa-upload
```

Zatim kopiraj template:

```bash
cp android/key.properties.example android/key.properties
```

U `android/key.properties` upiši prave lozinke.

`android/key.properties` i `*.jks` su ignorisani u git-u i ne smiju se commitovati.

## 3. Build za Play Console

```bash
flutter clean
flutter pub get
flutter build appbundle --release --dart-define=API_URL=https://coabackapi.zeleniparadajz.me
```

Output:

```text
build/app/outputs/bundle/release/app-release.aab
```

## 4. Play Console checklist

- App package: `me.coathematchmaker.app`
- App name: `COA`
- Upload: `app-release.aab`
- Track prvo: Internal testing
- Privacy Policy URL je obavezan jer app koristi naloge, slike i poruke.
- Data Safety: email, profilni podaci, slike, poruke, app activity.

## 5. Važno

Rotiraj Resend API key koji je bio vidljiv u chatu i `.env`.
