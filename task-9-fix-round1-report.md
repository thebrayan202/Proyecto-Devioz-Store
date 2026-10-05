# Task 9 review fix round 1

## Addressed findings

- Model quantities are normalized before any browser/cart expansion. `validate_model_recommendations()` caps each line and the complete recommendation at 99 units, while the browser now submits normalized cart lines directly instead of synthesizing one DOM click per unit.
- The recommendation API reloads every selected ID from the authoritative master/public-visible catalog after the model response and before payload/token creation. Confirmation finalization performs another fresh reload and checks publication, restriction, stock, price, budget, and quantity.
- The legacy assistant now creates the same expiring, session-bound confirmation token as the recommendation endpoint. Both its chat and saved-view paths carry the token to the browser; cart reconciliation must succeed before the one-time finalization call.
- Confirmation records store a canonical proposal and session HMAC digest. Altered payloads, expired tokens, replayed tokens, mismatched reconciliation, and stale inventory are rejected. `confirmed_additions` is written only after the authoritative reconciliation and final database validation succeed.
- `shopping_sources.php` is retained because the legacy assistant must refresh model-selected IDs against the same master/public catalog scope before producing its proposal.

## Verification

- `node --check assets/js/app.js` — passed.
- `node --check assets/js/shopping_chat.js` — passed.
- `node --test tests/ai_recommendations_boundaries_test.cjs` — 6 passed.
- Full `node --test tests/*.cjs` — run as part of the handoff checks.
- `git diff --check` — passed.
- PHP/MySQL checks were unavailable because this environment has no PHP runtime.
