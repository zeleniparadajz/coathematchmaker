# User-Facing Language

- The app has MNE and ENG languages, selected in My Profile and persisted on the device. MNE is the default and preserves the existing wording. ENG uses English.
- For MNE UI copy, validation messages and emails, use literary Serbian, ijekavian pronunciation, in Latin script. Use Serbian vocabulary, not Croatian-specific alternatives.
- Preserve the user's explicit spellings: `sledeći` (and `sledeća`, `sledeće`) and `redoslijed`.
- Use proper diacritics and forms such as `vrijeme`, `mjesto`, `pobjednik`, `promijeni`, `obavještenje`, `podešavanja`, `učesnik` and `korišćenje`.
- Prefer clear Serbian labels such as `lozinka`, `rang-lista`, `izazov` and `administrator` over mixed English/Serbian copy.
- Preserve brand names and the requested tournament labels `Round-robin` and `knockout`.
- Do not translate API keys, enum values, routes, identifiers or user-entered data. Keep the backend message prefix `Potvrdi email`: released mobile clients use it to offer verification-email resending.
- Language-only changes must not alter app behaviour or layout. Update text assertions and check compact-screen layouts when labels change.
- Localize UI literals with `context.tr(source, arguments)` and maintain `lib/l10n/english.dart`. Use `{p0}` placeholders for dynamic values. Translate server errors at display boundaries with `context.serverMessage`, not inside API parsing or business logic.
- Never translate names, addresses, chat messages or form-controller values. Test both languages, including live switching, persistence and narrow screens.
