# Task 11 review fixes — round 2

## Outcome

- Removed the stale documented administrator credential from `README.md`.
- Updated `DEPLOYMENT.md` so a fresh deployment runs `CREAR_ADMIN_INICIAL.command` before the first administrator login, requires a strong operator-supplied password, and documents the exact acknowledgement needed for a non-default database name.
- Added `tests/documentation_security_test.cjs`, which scans every tracked Markdown/text document (including `DEPLOYMENT.md`) for the known public hash and reusable default-credential forms, and asserts the fresh deployment flow includes the one-time bootstrap before login.

## Verification

- `node --test tests/*.cjs` — 2 passed in this baseline worktree.
- `bash -n INSTALAR_REPARACION_DB.command REPARAR_TABLESPACE_XAMPP_MAC.command` — passed.
- `git diff --check` — passed.
- Tracked Markdown/text scan contains no known public hash or reusable default-credential pattern.

This baseline worktree does not contain the prior catalog installer/bootstrap commit; the documentation and regression test are written to compose with that change when integrated.
