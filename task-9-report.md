# Task 9 report — IA limitada al inventario vendible

## Implemented

- Recommendation and legacy assistant candidate queries now use the master/public visibility scope and a hard `LIMIT 60`.
- Server-side recommendation validation rejects unknown IDs, malformed quantities, unavailable stock, restricted/inactive/non-saleable products, non-master candidates, invalid prices, and selections over budget.
- Ollama prompts use explicit public-field allowlists only; internal costs, credentials, SQL, and visibility fields are not sent to the model.
- Ollama timeout/invalid responses fall back deterministically to rule-based ranking over the same candidate set.
- Recommendation proposals receive one-time, expiring confirmation tokens. The browser asks for confirmation before invoking the cart-add path, and `confirmed_additions` increments only after the token guard succeeds.
- `ai_usage_daily.searches` and either `ollama_answers` or `rule_fallbacks` are incremented for recommendation requests.
- `includes/shopping_sources.php` remains included because the legacy assistant loads master visibility fields needed for the shared sellability predicate.

## Verification

- `node --test tests/ai_recommendations_boundaries_test.cjs` — 4/4 passed.
- All `tests/*.cjs` — passed (including master-operation, cart-allocation, cart-state, and receipt interaction checks).
- `node --check assets/js/app.js` — passed.
- `node --check assets/js/shopping_chat.js` — passed.
- `git diff --check` — passed.
- PHP tests and `php -l` were not runnable because the environment has no PHP binary (`php: command not found`).
