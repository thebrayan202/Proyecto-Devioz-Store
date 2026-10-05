# Task 11 review fixes — round 1

## Outcome

Implemented the requested P1/P2 fixes from `task-11-review-report.md`.

- Removed the embedded administrative user/password row and known public hash from all four shipped StockFlow SQL artifacts.
- Added `CREAR_ADMIN_INICIAL.command`, an executable XAMPP bootstrap that prompts for MySQL credentials and a strong initial administrator password without placing secrets in command arguments, logs, repository files, or persistent config. The password is sent through PHP stdin to `password_hash`; the temporary MySQL defaults file is mode 600 and deleted on exit. The bootstrap validates the project marker, refuses an existing administrator, and does not provide a reusable default.
- Added the `stockflow_schema_marker=catalogo_11604` row to the shipped schema artifacts.
- Hardened `INSTALAR_CATALOGO_11604.command`: `devioz_shop_reparada` is the default, alternate database names require an exact typed acknowledgement before MySQL is invoked, and preflight requires the project marker plus six expected StockFlow tables and six expected `products` columns before the source row-count check or migration import.
- Updated README, database notes, and the XAMPP catalog instructions to document the bootstrap and database guardrails without publishing credentials.
- Preserved the review report and untracked `tests/installer_security_test.cjs` supplied before this fix.

## Verification

- `bash -n INSTALAR_CATALOGO_11604.command`
- `bash -n CREAR_ADMIN_INICIAL.command`
- `node --test tests/*.cjs` — 21 passed
- `git diff --check` — passed
- Static search found no known public admin hash or documented default password in the worktree's SQL/docs.

PHP and MySQL/MariaDB are unavailable in this environment, so live import and runtime hashing against XAMPP were not run. The Node harness uses fake clients to cover success, wrong-database acknowledgement, missing-marker rejection, import failure behavior, password redaction, temporary-file cleanup, generated hash insertion, and duplicate-administrator refusal.
