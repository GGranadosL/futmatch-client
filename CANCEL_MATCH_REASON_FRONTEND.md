# Cancel Match Reason — Frontend Implementation

Repo: `/Volumes/D/code/futmatch-client` (Swift, SwiftUI, SPM modular architecture). Read the repo's own `CLAUDE.md` first (struct-over-class, mandatory UseCase/Repository layering, zero uninjected dependencies, L10n for all strings, CoreData `perform` rules) — this doc only covers what's specific to this feature.

Companion doc for the server side: `CANCEL_MATCH_REASON_BACKEND.md` in the `futmatch` repo. The **API contract** below must stay identical in both docs.

## API contract

```
PATCH /match/admin/cancel/{matchId}
Authorization: Bearer <access JWT>  (role ADMIN or ORGANIZER)

Body:
{
  "reason": "No se completó el número mínimo de jugadores."
}
```

- `reason` is required, non-blank, max 300 chars (backend validates and rejects otherwise — surface its localized error message if the request fails).
- Send the **exact text of the selected preloaded reason**, or the free-typed text when the user picks "Otro". No reason "code" — just the final string.
- Backend already appends the reason to the cancellation push notification sent to every affected player, so no extra client work is needed for that part.

Replaces the current `FMConfirmationAlert` cancel flow in `AdminMatchDetailView.swift` with a bottom sheet.

---

## 1. Preloaded reasons
Four options, shown as a radio list inside the sheet:
1. "No se completó el número mínimo de jugadores." / "The minimum number of players wasn't reached."
2. "Razones climáticas." / "Weather conditions."
3. "Cancha no disponible." / "Field not available."
4. "Otro" / "Other" — reveals a free-text field; the typed text becomes the `reason` sent to the backend.

## 2. New bottom sheet component
`Packages/Features/AdminFeature/Sources/AdminFeature/Views/Components/CancelMatchReasonBottomSheet.swift` (new file):
- Drag handle, title, subtitle.
- 4 selectable rows (circle radio + label), reusing `FMColors`/`FMTypography` tokens (`primary` for selected state, `outlineVariant` for unselected borders, `onSurface`/`onSurfaceVariant` for text).
- "Otro" row expands an `FMTextField` inline instead of navigating away.
- Primary button "Cancelar partido" (`FMColors.error` background, white text) — **disabled** until a reason is chosen (and non-empty if "Otro"), using the same disabled-state pattern as `FMPrimaryButton` (`onSurface` at 12% opacity background / 38% opacity text).
- Secondary text button "Volver" to dismiss without canceling.
- Keep the existing copy about no charges yet (`L10n.CancelMatch.noPayMessage` / `withPayMessage`) somewhere in the sheet.
- Cap the free-text field at 300 chars client-side (mirrors the backend limit) so the request can't be rejected for length.

## 3. Propagate `reason` through the architecture
- `Domain/UseCases/CancelAdminMatchUseCase.swift` — `execute(matchId: String, reason: String) async throws`.
- `Domain/Repositories/AdminMatchRepositoryProtocol.swift` + `Data/Repositories/AdminMatchRepository.swift` — add `reason` param, forward to the service.
- `Services/MatchAdminService.swift` / `MatchAdminEndpoint.swift` — include `reason` in the PATCH body.
- `Data/DTOs/MatchAdminDTOs.swift` — add a request DTO matching the backend's `CancelMatchRequest`: `{ "reason": String }`.
- `ViewModels/AdminMatchDetailViewModel.swift` — `cancelMatch(reason: String) async`. Surface the backend's validation error message (blank/too-long) through the existing `cancelError` published property if the call fails with a 400.
- `Views/AdminMatchDetailView.swift` — replace the `FMConfirmationAlert` block for `showCancelNoPay`/`showCancelWithPay` with `CancelMatchReasonBottomSheet`, keeping the existing paid/no-pay message distinction.

## 4. Localization
Add keys to `Packages/Features/AdminFeature/Sources/AdminFeature/Resources/Localizable.xcstrings` (English + Spanish) for: sheet title, subtitle, the 4 reason labels, "Otro" placeholder. Reference via `L10n.CancelMatch.*` — **no string literals in the view**, per this repo's `CLAUDE.md`.

## 5. Tests
Update `Packages/Features/AdminFeature/Tests/AdminFeatureTests/ViewModels/AdminMatchDetailViewModelTests.swift` and the `CancelAdminMatchUseCase` tests (mock repository) to cover the new `reason` parameter — assert it's forwarded correctly and that empty/blank reasons don't get sent from the sheet's "Cancelar partido" button (the button itself should be disabled, but the use case shouldn't trust the UI alone).

---

## Suggested build order

1. DTOs / service / repository / use case plumbing for `reason` (compiles even before the UI exists — use a placeholder call site).
2. `CancelMatchReasonBottomSheet` UI in isolation (Xcode preview).
3. Wire into `AdminMatchDetailView`, replacing `FMConfirmationAlert`.
4. Localization strings ES/EN.
5. Tests.
6. Manual end-to-end check against the backend (see `CANCEL_MATCH_REASON_BACKEND.md`): cancel a match with each of the 4 reasons (including "Otro") and confirm the reason shows up in the push notification body on the player's device.
