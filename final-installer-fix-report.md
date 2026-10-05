# Final installer fix report

## Finding addressed

Pre-marker StockFlow installations were rejected because the update installer
only accepted `store_settings.stockflow_schema_marker=catalogo_11604`. The
marker was introduced by this catalog release, so a legitimate older project
database could not reach the non-destructive migration.

## Implemented behavior

- Marker-bearing databases retain the existing six-table/six-column marker
  guard.
- A database without the marker must match a separate StockFlow legacy
  fingerprint: all 12 required project tables and all 36 required
  project-specific columns are checked through `information_schema`.
- The source table must still contain exactly 11,604 rows. A row count alone
  cannot enroll a database.
- An existing, incompatible marker key is rejected rather than overwritten.
- After all checks pass, the operator must type the exact selected database
  name. Only then does the installer run the idempotent, non-destructive
  `INSERT ... ON DUPLICATE KEY UPDATE` for the schema marker, followed by the
  catalog migration.
- Rejected or unconfirmed databases receive no enrollment SQL and no
  migration import. MySQL credentials remain in the existing mode-600
  temporary defaults file and are removed by the existing cleanup trap.

## Coverage

`tests/installer_security_test.cjs` now covers successful legacy enrollment,
missing confirmation, a same-count lookalike schema, and an incompatible
marker, in addition to the existing wrong-database and credential-cleanup
cases.

## Verification

- `node --test tests/*.cjs` — 26 passed, 0 failed
- `bash -n INSTALAR_CATALOGO_11604.command CREAR_ADMIN_INICIAL.command` — passed
- `find assets api -type f -name '*.js' ... node --check` — passed
- `git diff --check` — passed
- `shellcheck` was unavailable in this environment
