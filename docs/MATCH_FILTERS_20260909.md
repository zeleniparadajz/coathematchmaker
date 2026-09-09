# Match filters

## Behaviour

- Matches offers All matches / Only mine. Players initially see their own matches;
  administrators initially see all authorized matches. Doubles partners count as participants.
- Search matches player/team names, tournament names and locations. Search ignores case,
  repeated spaces and Serbian Latin diacritics. All search words must match.
- The filter sheet combines status, tournament (including no tournament), singles/doubles,
  and competitive/friendly. Apply saves the draft; dismissing it keeps the previous choice.
- Filters survive refresh and return from match details. A selected tournament that disappears
  from the refreshed response remains selected and shows an empty result instead of silently
  broadening the filter. Choices are not persisted across app restarts.
- Clear filters keeps All / Only mine and sorting unchanged. The list clear action also clears
  search; the sheet reset changes only the four fields in the sheet, then requires Apply.
- Existing sorting by schedule, newest, status and tournament is available via the sort icon.
- Empty results can clear filters, and pull-to-refresh works even on an empty list.
- The client uses GET /api/matches for both scopes, then filters locally. Server visibility
  rules are unchanged: admins see all; other users do not see unrelated friendly matches or
  inaccessible private tournaments. There is no new public data endpoint.
- GET /api/matches now populates resultSubmittedBy, as the My endpoint already did.
  Result controls remain restricted to participants/admins; a submitter cannot self-confirm.
- No database migration, version increment, release build, push or production deployment.

## Verification

- test/match_filters_test.dart: membership, combined predicates, search, list immutability,
  request selection, reset/cancel/refresh, removed tournament, action visibility and layouts.
- backend/test/matchList.integration.test.ts: visibility and populated result submitter
  using an isolated local MongoDB database.
- Visual captures: .local-backups/match-filters-20260909/*.png (MNE/ENG, widths 390 and 320,
  normal and 1.5x text). Test fixtures only; no production records were modified.

## Restore Point

Before this task, the exact uncommitted result-correction work was saved in
`.local-backups/match-filters-20260909/before.tar.gz`. It contains the pre-filter versions of:

- lib/screens/matches_screen.dart
- lib/models/match.dart
- lib/l10n/english.dart
- backend/src/controllers/matchController.ts
- backend/test/matchResult.integration.test.ts (unchanged by this filters task)

New files in this task: lib/models/match_filters.dart, test/match_filters_test.dart,
backend/test/matchList.integration.test.ts and this document. To undo only filters, compare
the current files against the archive and restore the filter-related edits while preserving
any later work. Do not reset the whole worktree: previous result-correction changes are still
uncommitted and must remain. The archive is local and ignored by Git.
