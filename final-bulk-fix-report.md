# Final bulk binding fix

## Finding addressed

Fixed the important review finding in `includes/master_catalog.php`: bulk
update SQL placeholders are ordered as `SET` values, selected batch IDs, then
the publication guard parameters. The `execute()` call now binds exactly in
that order, preserving the existing transaction, row-count concurrency check,
activity audit, and publish guard behavior.

## Regression coverage

Added `tests/master_catalog_bulk_binding_test.cjs`, a PHP-free static contract
test that verifies:

- the selected ID placeholders precede the appended publication guard SQL;
- the guard parameterizes `active`, `sale_enabled`, and `price`; and
- execution binds `$values`, `$batch`, then `$publishGuard['params']`.

The test failed against the previous binding order and passed after the fix.

## Verification

- `node --test tests/*.cjs` — 23 passed, 0 failed
- `find assets api -type f -name '*.js' ... node --check` — passed
- `node --check tests/master_catalog_bulk_binding_test.cjs` — passed
- `bash -n INSTALAR_CATALOGO_11604.command CREAR_ADMIN_INICIAL.command` — passed
- `git diff --check` — passed

PHP/MariaDB integration tests were not runnable in this environment because
the PHP and database binaries/extensions are unavailable.
