# Result consistency and administrator corrections

## Scope

- The result-entry form calculates the winner from sets. It no longer defaults to player 1 or permits an independent winner selection.
- Empty scores, tied sets and an equal number of sets won cannot be submitted. The check compares sets, not total games. It preserves the league's existing support for short sets and match tie-breaks; it is not a full tennis scoring-format validator.
- The backend verifies the winner on submission, confirmation, administrator resolution, creation, updates and before applying ranking statistics.
- Old inconsistent records are not rewritten automatically. The details screen warns about the inconsistency and does not award a visual trophy to the incorrect stored winner.

## Administrator Actions

Open a match's **Upravljanje rezultatom / Manage result**, also available from league settings for disputed matches.

- **Uredi setove / Edit sets** edits the score on this screen for results not yet confirmed. The displayed winner and confirmation availability follow the draft scores, not the previously stored winner. **Potvrdi rezultat / Confirm result** sends the edited sets and calculated winner directly, including for rejected and cancelled matches; reopening is not required first.
- The administrator-confirmation endpoint independently calculates the winner from the supplied sets (or stored sets when none are supplied). A stale client/stored winner does not override the score. The prior result is archived before confirmation and obsolete rejected/cancelled/disputed dates are cleared. Ordinary player confirmation still rejects inconsistent saved data so only an administrator can authorize its correction.

- **Vrati na potvrdu / Return for confirmation**: disputed, rejected or cancelled results with valid scores and an original submitter return to `waiting_confirmation`. Scores, submitter and winner remain unchanged; points do not change.
- **Vrati na unos rezultata / Reopen result entry**: waiting, disputed, rejected and cancelled matches return to `accepted`, with empty scores and no winner/submitter. Existing `acceptedAt` is preserved, so the entry delay does not restart.
- Confirmed matches can also be reopened. Their own wins, losses, matches played and win points are reversed before a new result is entered. Doubles reverse all four players' contributions; friendly matches do not affect ranking counters.
- Reopening requires an explicit confirmation dialog. The prior result, status, administrator, note, date and reversed points are kept in hidden `Match.resultHistory` records.
- Only global administrators can perform these actions. Ordinary players keep their existing submit/confirm/dispute permissions.

## Statistical Integrity

New confirmations store the points awarded at the time in `Match.statsWinPoints`. Subsequent settings changes do not affect how much is reversed. For a legacy competitive match without this field, the administrator must enter the original win points; the current league rate is not assumed to be historical truth.

`Match.statsOperationId`, `Match.resultReset` and private `Player.matchStatOperations` markers make apply/reverse counter changes idempotent on the existing standalone Mongo deployment. A failed reversal can be retried using the same action. The persistent pending reset is retained until all player changes and the match reset complete. Operation markers and result history are excluded from ordinary API responses.

This is not a multi-document transaction: after a database failure there may be a temporary partially updated view until the administrator retries. Do not manually clear pending operation fields or delete operation markers.

While a confirmed-result reset is pending, the match is marked disputed so a new round cannot treat that result as confirmed. Repeating **Reopen result entry** resumes the saved operation.

## Tournament Dependency Guard

Reopening is blocked when the result determines an already-created later knockout round, established knockout seeds, or an awarded tournament winner. The app explains that dependent phases must be reset first. This change does not implement cascading tournament resets or revoke championship awards. It does not silently change later participants or delete later matches.

## Deployment And Rollback

- App version/build remains `1.0.2+7`. No store build, upload or production deployment was performed.
- Deploy the backend before using the new administrator actions in the updated client. Older clients continue using the original API actions, but inconsistent winners are now rejected.
- Source checkpoint: git commit `8dba6e9`; archive `.local-backups/result-consistency-20260909/before.tar.gz`.
- Follow-up checkpoint before fixing the disabled admin-confirm button and adding score editing: `.local-backups/admin-score-edit-20260909/before.tar.gz` (includes the earlier uncommitted correction work).
- Compare/revert only this change's files against that checkpoint. Do not reset unrelated work or overwrite newer edits.
- Code rollback alone does not undo administrator changes already made to match data. Use the recorded histories and a database backup for any data recovery; never delete the Mongo volume.
