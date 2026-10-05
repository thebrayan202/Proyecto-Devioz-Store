# Task 9 review fix round 2

## Addressed findings

- Corrected the legacy planner's `array_slice()` call to pass offset `0` and length `60`.
- Refreshed the authoritative master/public catalog after every legacy AI attempt. Model-selected IDs use an authoritative ID reload; timeout, invalid response, unavailable-provider, and other `ids = null` paths reload the same candidate query before deterministic planning, preserving sale/restriction/stock filters.
- Limited legacy plans to 12 lines while retaining the user-facing per-product quantity limit as a separate token field. Confirmation records now distinguish `line_limit`, `quantity_limit`, and total quantity limit during final validation.
- Legacy assistant and chat flows require a nonempty, correctly shaped confirmation token and at most 12 lines before staging a proposal. They no longer write directly to the main cart storage key.
- Cart reconciliation for staged proposals runs without persistence; the proposal is committed to the cart storage only after the proposal-bound finalization succeeds. Invalid, stale, mismatched, or rejected proposals restore the prior in-memory cart and cannot replace the user's cart.

## Verification

- `node --check assets/js/app.js` — passed.
- `node --check assets/js/shopping_chat.js` — passed.
- `node --test tests/*.cjs` — 9 Task 9 boundary assertions plus all existing Node tests passed.
- `git diff --check` — passed.
- PHP/MySQL checks were unavailable because this environment has no PHP runtime.
