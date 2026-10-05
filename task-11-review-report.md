# Task 11 review — CHANGES REQUESTED

Reviewed commit `b1f53ee997444e6b049e29cbb2c443029efd4217` (fresh SQL, macOS installer, documentation, and delivery test). No task-11 brief, implementation report, or `task-11-review.diff` was present in this worktree, so this review used the committed diff from `HEAD^..HEAD`.

## Findings

### P1 — Fresh install ships a known administrative credential

`database/devioz_shop_11604_completa.sql:12297-12300` creates `users.admin` with a publicly known bcrypt credential. `README.md:89-90` publishes that credential, and there is no forced password-change path in `login.php:41-52`. This is an embedded, universally known administrator credential in the new install artifact; it violates the no-embedded-secrets/release-safe requirement for any reachable deployment.

Require an installer-supplied initial password (or a one-time setup flow) and force its replacement before administrative use. Do not ship or document a reusable default.

### P2 — Update installer can mutate an unintended database

`INSTALAR_CATALOGO_11604.command:66-70` accepts any syntactically valid database name, and `:92-103` then runs the migration after only checking that its `productos` table has 11,604 rows. A different database with that table/count passes preflight and receives schema changes, legacy snapshot tables, and master-product inserts. The update SQL contains no `DROP DATABASE`, so it does not destroy the target, but the installer does not provide the required guard against operating on the wrong database.

Require `devioz_shop_reparada` (or an explicit, typed acknowledgement for an override) and preflight a project-specific schema marker before importing.

## Verified checks

- Targeted Node parsing of the 4.20 MB SQL found exactly **11,604** `productos` source rows; IDs are unique and contiguous from 1 through 11,604.
- The full file has 38 table definitions with no duplicate table name, all 18 foreign-key targets are defined, each of the six embedded sections appears once, and it contains no `SOURCE`/`\\.` nested imports. `FOREIGN_KEY_CHECKS` is restored.
- `bash -n INSTALAR_CATALOGO_11604.command` and `git diff --check HEAD^ HEAD` passed.
- A fake MySQL client exercised an installer success path from a directory with spaces (exit 0, all postflight values accepted), an import failure path (exit 1), and a wrong-count preflight path (exit 1; only the connection/count calls occurred, no import). In all cases the temporary defaults file was created mode-restricted, removed on exit, and the supplied password did not reach logs/arguments.
- All six Node `.cjs` tests passed. `tests/deliverables_test.php` could not run because this review environment has no PHP executable; its static assertions do meaningfully cover required files, the row/unique-ID count, table-definition uniqueness, section counts, and check-query presence, but do not cover the 10.4 parser compatibility, installer behavior, wrong-database protection, docs, or credentials.
- No live API keys/tokens were found. Empty token settings are present, but the public default admin password above remains a release-blocking credential issue.

## Runtime limitation

No MariaDB/MySQL server or client is installed in this review environment, so a clean fresh import and MariaDB 10.4 parser check could not be run. Static review found one self-contained script, one definition of each table, plausible FK ordering, and no nested `SOURCE` imports; add a clean MariaDB 10.4 import to validation to prove these runtime properties.
