# Final legacy Yape backfill fix

## Finding addressed

The existing-install repair scripts created the Yape snapshot table and columns
but omitted the canonical legacy migration step. As a result, coherent pending
legacy orders stayed at version 0 without the migration's reconciliation report.

## Implemented behavior

- `database/reparar_instalacion_existente.sql` and
  `database/reparar_error_1932_catalogo.sql` now contain the exact canonical
  version-1 backfill from `database/upgrade_yape_order_snapshots.sql`.
- The update is guarded by pending status, version 0, complete line snapshots,
  active reservations, and matching Yape movement totals. Re-running it cannot
  reapply already migrated rows.
- Each repair script emits the canonical unresolved version-0 pending-order
  report for administrator reconciliation before review or expiry mutations.
- Node and PHP parity tests now require the canonical semantic block in every
  existing-install artifact.

## Verification

- `node --test tests/*.cjs`: 33 passed, 0 failed.
- `bash -n *.command`: passed.
- Canonical SQL parity/count check: passed.
- `git diff --check`: passed.
- `php tests/deliverables_test.php`: not run; PHP is unavailable in this
  environment (`php: command not found`).
- MariaDB execution/integration was not run; execute the repair scripts against
  MariaDB 10.4+ before deployment.
