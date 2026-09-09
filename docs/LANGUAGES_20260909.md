# MNE and ENG

Open the profile menu, choose Moj profil / My profile, then select MNE or ENG.
The choice applies immediately and is saved locally as `app_language`, including
after signing out and reopening the app. MNE is the default on a fresh install.
Switching languages does not save profile edits or write to the server.

MNE preserves existing text, including the requested spellings `sledeci`
(with the appropriate diacritic) and `redoslijed`. ENG translates navigation,
forms, statistics, tournament controls, validation, errors and update screens.
Player names, tournament names, addresses, chat messages and other user data
are not translated. The selector does not redesign the existing screens.

## Implementation

- `lib/l10n/app_language.dart`: local preference and language controller.
- `lib/l10n/app_strings.dart`: Flutter localization delegate and text helpers.
- `lib/l10n/english.dart`: explicit MNE-source to English catalog.
- `lib/l10n/server_aliases.dart`: compatibility with older backend error text.
- Flutter's native controls use Serbian Latin for MNE and English for ENG.
- Add UI copy through `context.tr(source, arguments)` and update the catalog.
- Keep API identifiers, enum values and user data outside the translation layer.

## Backend and Release

No database migration or new profile field is required. This needs a new mobile
build to reach installed users; no version/build number was changed here.

The backend app-config response adds optional `messageEn`. Set
`APP_UPDATE_MESSAGE_EN` to customize English mandatory-update copy. The existing
`APP_UPDATE_MESSAGE` remains MNE. Both have defaults; the new app also works
with the old backend using built-in English update text. Build thresholds,
platform detection and mandatory-update enforcement are unchanged.

## Restore Point

`.local-backups/languages-20260909/before.tar.gz` contains the state immediately
before bilingual support, including the preceding Serbian copy corrections.
Restore only the affected files after comparing any later changes. Do not
reset the repository to HEAD: that would also discard preceding work.
For a full rollback, also remove the files introduced by this task after checking
for later edits: `lib/l10n/`, `test/localization_test.dart` and this document.
Then run `flutter pub get` to restore the snapshot's dependency configuration.
No production database or server settings were modified by this change.

## Verification

Flutter tests cover both languages across phone/tablet layouts, enlarged text,
profile switching, saved preferences, logout/restart, validation, auth recovery,
Google venue selection, knockout actions and cached mandatory updates. Backend
tests run against an isolated local Mongo test database. Visual captures are in
the language backup directory; no production data was used.
