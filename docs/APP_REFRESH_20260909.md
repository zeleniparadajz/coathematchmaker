# COA refresh: 9 September 2026

## Restore point

The source tree before these changes, including the user's existing iOS and
pubspec.lock edits, is stored locally at:

`.local-backups/pre-refresh-20260909/before.tar.gz`

The backup is intentionally excluded from Git. It does not contain the server's
database, uploads, credentials or `.env`.

Check whether the changes can be restored without overwriting later edits:

```sh
node tool/change_checkpoint.mjs check
```

To restore the pre-refresh source after reviewing the check:

```sh
node tool/change_checkpoint.mjs restore
flutter pub get
```

The restore script refuses to overwrite files edited since this change set was
sealed. Existing user changes present before the refresh remain intact. Rebuild
the simulator after restoring; restoring source does not replace an installed app.

## Automatic update checks

The app reads the installed version and build from the native package using
`package_info_plus`. There is no separate `APP_BUILD_NUMBER` constant to maintain.
It sends `platform=ios` or `platform=android`, `build`, and `version` to
`GET /api/app-config` at startup, on resume (15-second debounce), and every five
minutes while in the foreground. Store installation is performed by the OS/store,
not by the backend. No store build has been uploaded by this change.

The server `.env` controls the policies independently:

```dotenv
# Example only. Set these to builds actually available to your users.
APP_IOS_MIN_SUPPORTED_BUILD=6
APP_IOS_LATEST_BUILD=6
APP_ANDROID_MIN_SUPPORTED_BUILD=7
APP_ANDROID_LATEST_BUILD=7
PLAY_STORE_URL=https://play.google.com/store/apps/details?id=me.coathematchmaker.app
APP_STORE_URL=https://apps.apple.com/app/idYOUR_APP_ID
APP_UPDATE_MESSAGE=Nova verzija aplikacije je obavezna. Azuriraj COA The Matchmaker.
```

Use the real public App Store URL, not an App Store Connect URL. The example
App Store ID is a placeholder. Raising LATEST offers an optional update; raising
MIN makes older builds show the mandatory update screen. Newer installed builds
are never forced to downgrade. Keep legacy APP_MIN_SUPPORTED_BUILD and
APP_LATEST_BUILD for old clients that do not send platform. Do not raise either
platform's minimum until that build is available to all affected users.

Deploy backend source, then recreate the API with the server's existing env:

```sh
cd ~/coathematchmaker/backend
git pull --ff-only
docker compose up -d --build api
curl 'https://coabackapi.zeleniparadajz.me/api/app-config?platform=ios&build=6'
curl 'https://coabackapi.zeleniparadajz.me/api/app-config?platform=android&build=7'
```

The last valid policy is cached by API URL and platform. During a network outage,
it is evaluated against the current installed build, so a successful upgrade
cannot remain blocked by an old cached decision. A known mandatory requirement
is retained when the network fails. With no cached policy on a first offline
launch, the app retains the existing fail-open behavior; this UI gate is not an
API security boundary.

Native plugin changes require a fresh Android/iOS build; hot reload alone is
insufficient. Keep the existing store numbering until preparing a new release,
then choose unused build numbers for each platform.

References: [package_info_plus](https://pub.dev/packages/package_info_plus/versions/9.0.1),
[url_launcher](https://pub.dev/packages/url_launcher).

## Product changes

### Personal dashboard correction

The dashboard again shows the signed-in player's profile photograph, points,
wins, losses, matches, titles and tournament participation. It uses a fresh
player record matched by account ID, while ranking position keeps the server's
canonical order. Missing or failed profile photos show that player's initials,
never the editorial tennis-court image. The original "Liga danas" statistics
cards and active-tournament count are restored.

The immediately preceding dashboard is also saved at
`.local-backups/personal-dashboard-20260909/before.tar.gz`. The original sealed
checkpoint remains unchanged: its restore guard intentionally flags this later
dashboard correction, so do not overwrite those hashes or force a blanket restore.

- Removed the inbox-to-parent refresh loop; badge polling no longer reloads every screen.
- API requests have timeouts, deduplicate simultaneous identical GETs, and report network errors.
- Main screens have retry and empty states. Background polling pauses with the app.
- Ranking and home use the server's canonical ranking order, including stable ties.
- Home prioritizes the next scheduled match and incoming actions, with a direct player search.
- Five bottom destinations; messages and profile/admin settings are in the app bar.
- Player search supports name, city, club and country; filters include city, club and availability.
- City is an optional new profile field. Deploy the backend before using city editing.
- Photo and compact list modes are remembered locally. Photo cards use top-aligned cover
  previews, with a separate expand control. The full-screen viewer uses contain, so the
  entire original image is visible, with zoom and gallery paging.
- Visual rework based on the user's tennis-app reference: mint background, floating
  translucent navigation, full-bleed photo cards, green/blue/gold accents and a ranking podium.
- Localized match/tournament statuses. Typography is checked at 320px and 150% text size.
- Push notifications are excluded at the user's request.

## Visual asset

The built-in imagegen tool generated `assets/images/tennis_court_editorial.png`.
It is generic editorial tennis artwork, not a photograph of any named tournament
venue or player. Real uploaded tournament and player images take priority.
The previous design iteration is separately saved in
`.local-backups/first-refresh-20260909/before-visual-rework.tar.gz`.

Final generation prompt:

> Use case: photorealistic-natural. Asset type: background photograph for a premium tennis match-finding mobile app, not a UI mockup. Create a luminous authentic editorial sports photograph of a tennis court in bright coastal daylight. View from near the baseline, rich teal-blue acrylic court, white court lines and a tennis net, sunlit mint green surroundings, one unbranded tennis racket and two tennis balls in the lower right foreground. Distant green hedges and pale sky. Horizontal landscape 3:2 composition. Left half spacious uninterrupted blue court, leaving room for white overlay headline and action; net and racket concentrated toward right third. Real sharp texture, elegant sports magazine photography, gentle natural directional shadows, fresh saturated blue/green balanced by bright yellow tennis balls. No people, no text, no logos, no lettering, no UI, no illustration, no vignette, no blur, no orbs. This is generic tennis editorial artwork, not a specific venue.

## Verification

```sh
flutter analyze
flutter test
node --test tool/change_checkpoint.test.mjs
cd backend
npm run typecheck
npm test
```

Tests use synthetic data and do not write production data. Simulator inspection
uses the app's configured backend for read-only navigation.
