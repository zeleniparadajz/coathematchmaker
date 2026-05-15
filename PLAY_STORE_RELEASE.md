# COA Play Store Release

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
