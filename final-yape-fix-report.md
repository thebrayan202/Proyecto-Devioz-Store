# Final Yape integrity fix

Implemented the focused snapshot/reservation fix for catalog edits after checkout.

## Behavior

- New orders persist `inventory_snapshot_version = 2`, immutable pack/price/cost facts, manual combo-cap flags, and per-component quantity and financial allocations. The final component absorbs rounding remainder.
- Approval locks and verifies active reservations, movement totals, and (for version 2) component snapshots. It converts the exact reservations and retains the original lines, totals, and Yape movements. Current price, pack, publication, combo price, and combo membership are not read during review.
- Rejection and expiry restore the locked reservation sums grouped by original `product_id`, release those exact rows, restore only explicitly recorded manual combo caps, and remove only provisional Yape movements. They never read `combo_items` and never erase historical order facts.
- A product that is restricted after checkout follows the safe release/rejection path. Price or publication edits alone do not strand an otherwise coherent order.
- Version-0 legacy pending orders and any incoherent reservation/movement/component set fail closed before mutation. Coherent legacy rows are migrated to version 1 without inventing combo composition.
- All review/expiry transitions retain row locks and pending-status guards for idempotence.

## Verification

- `node --test tests/*.cjs`: 32 passed, 0 failed.
- `node --check assets/js/app.js`: passed.
- `bash -n INSTALAR_CATALOGO_11604.command CREAR_ADMIN_INICIAL.command`: passed.
- `git diff --check`: passed.
- PHP/MariaDB integration was not run because this environment does not provide `php`, `mysql`, or `mariadb`; run the new migration and integration coverage against MariaDB 10.4+ before deployment.

## Limitations

Legacy version-0 orders require deliberate administrator reconciliation; no automatic stock or combo reconstruction is attempted. Manual combo-cap restoration is skipped with a warning if the combo was changed to unlimited stock, because changing current catalog configuration would be unsafe.
