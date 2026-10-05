#!/bin/bash
set -euo pipefail

EXPECTED_COUNT=11604
DEFAULT_DB_NAME="devioz_shop_reparada"
# This fingerprint describes the pre-marker StockFlow schema needed by the
# migration.  It is deliberately independent from the source-row count.
LEGACY_TABLE_COUNT=12
LEGACY_COLUMN_COUNT=36
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)"
UPDATE_SQL="$SCRIPT_DIR/database/upgrade_catalogo_maestro_11604.sql"
MYSQL_CNF=""

fail() {
    printf '\nERROR: %s\n' "$1" >&2
    exit 1
}

cleanup() {
    if [[ -n "$MYSQL_CNF" && -f "$MYSQL_CNF" ]]; then
        rm -f -- "$MYSQL_CNF"
    fi
}

mysql_option_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}

trap cleanup EXIT
trap 'exit 130' HUP INT TERM

[[ -s "$UPDATE_SQL" ]] || fail "No se encontro la migracion: $UPDATE_SQL"

MYSQL_BIN=""
if [[ -n "${MYSQL_BIN_OVERRIDE:-}" ]]; then
    [[ -x "$MYSQL_BIN_OVERRIDE" ]] || fail "MYSQL_BIN_OVERRIDE no apunta a un ejecutable."
    MYSQL_BIN="$MYSQL_BIN_OVERRIDE"
else
    candidates=(
        "/Applications/XAMPP/xamppfiles/bin/mysql"
        "/Applications/XAMPP/bin/mysql"
        "/opt/lampp/bin/mysql"
    )
    for candidate in "${candidates[@]}"; do
        if [[ -x "$candidate" ]]; then
            MYSQL_BIN="$candidate"
            break
        fi
    done
    if [[ -z "$MYSQL_BIN" ]]; then
        if command -v mysql >/dev/null 2>&1; then
            MYSQL_BIN="$(command -v mysql)"
        elif command -v mariadb >/dev/null 2>&1; then
            MYSQL_BIN="$(command -v mariadb)"
        fi
    fi
fi

[[ -n "$MYSQL_BIN" ]] || fail "No se encontro el cliente mysql de XAMPP. Verifica /Applications/XAMPP/xamppfiles/bin/mysql."

printf '\nDEVIOZ STORE - ACTUALIZACION DEL CATALOGO 11,604\n'
printf '================================================\n'
printf 'Cliente MySQL: %s\n\n' "$MYSQL_BIN"
printf 'Antes de continuar, exporta una copia de seguridad desde phpMyAdmin.\n'
printf 'Este instalador actualiza una base existente; no use el SQL completo de instalacion nueva.\n\n'

read -r -p 'Host MySQL [127.0.0.1]: ' DB_HOST
DB_HOST="${DB_HOST:-127.0.0.1}"
read -r -p 'Puerto MySQL [3306]: ' DB_PORT
DB_PORT="${DB_PORT:-3306}"
read -r -p "Base de datos [$DEFAULT_DB_NAME]: " DB_NAME
DB_NAME="${DB_NAME:-$DEFAULT_DB_NAME}"
if [[ "$DB_NAME" != "$DEFAULT_DB_NAME" ]]; then
    read -r -p "Para confirmar la base alternativa, escribe exactamente '$DB_NAME': " DB_CONFIRM
    [[ "$DB_CONFIRM" == "$DB_NAME" ]] || fail "Confirmacion requerida para la base alternativa '$DB_NAME'. No se ejecuto MySQL."
    unset DB_CONFIRM
fi
read -r -p 'Usuario MySQL [root]: ' DB_USER
DB_USER="${DB_USER:-root}"
read -r -s -p 'Contrasena MySQL (Enter si esta vacia): ' DB_PASSWORD
printf '\n'

[[ "$DB_PORT" =~ ^[0-9]{1,5}$ ]] || fail "El puerto debe ser numerico."
(( DB_PORT >= 1 && DB_PORT <= 65535 )) || fail "El puerto debe estar entre 1 y 65535."
[[ "$DB_NAME" =~ ^[A-Za-z0-9_]+$ ]] || fail "El nombre de la base solo puede contener letras, numeros y guion bajo."
[[ -n "$DB_USER" ]] || fail "El usuario MySQL no puede estar vacio."

MYSQL_CNF="$(mktemp "${TMPDIR:-/tmp}/devioz-mysql.XXXXXX")" || fail "No se pudo crear el archivo temporal seguro."
chmod 600 "$MYSQL_CNF"
{
    printf '[client]\n'
    printf 'user="%s"\n' "$(mysql_option_escape "$DB_USER")"
    printf 'password="%s"\n' "$(mysql_option_escape "$DB_PASSWORD")"
    printf 'host="%s"\n' "$(mysql_option_escape "$DB_HOST")"
    printf 'port=%s\n' "$DB_PORT"
    printf 'protocol=tcp\n'
} > "$MYSQL_CNF"
unset DB_PASSWORD

mysql_common=("$MYSQL_BIN" "--defaults-extra-file=$MYSQL_CNF" "--database=$DB_NAME")

printf '\n1/4 Verificando conexion y tabla fuente...\n'
"${mysql_common[@]}" --batch --skip-column-names --execute='SELECT 1;' >/dev/null || fail "No se pudo conectar a $DB_NAME. Revisa XAMPP y las credenciales."

schema_marker="$("${mysql_common[@]}" --batch --skip-column-names --execute="SELECT DATABASE(), (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema=DATABASE() AND t.table_name IN ('users','categories','products','product_images','inventory_movements','store_settings') AND EXISTS (SELECT 1 FROM store_settings s WHERE s.setting_key='stockflow_schema_marker' AND s.setting_value='catalogo_11604')), (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name='products' AND c.column_name IN ('id','code','name','category','price','stock'));" 2>/dev/null)" || fail "No se pudo validar el marcador de esquema StockFlow."
IFS=$'\t' read -r marker_database marker_tables marker_columns <<< "$schema_marker"
needs_enrollment=0
if [[ "$marker_database" == "$DB_NAME" && "$marker_tables" == "6" && "$marker_columns" == "6" ]]; then
    printf 'Marcador StockFlow validado.\n'
else
    legacy_schema="$("${mysql_common[@]}" --batch --skip-column-names --execute="SELECT DATABASE(), (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema=DATABASE() AND t.table_name IN ('users','categories','products','product_images','inventory_movements','store_settings','yape_orders','yape_order_items','combos','combo_items','stock_reservations','store_featured_products')) AS stockflow_legacy_tables, (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND ((c.table_name='products' AND c.column_name IN ('id','code','name','category','price','stock','units_per_pack','pack_price','entrega_inmediata','active','created_at')) OR (c.table_name='inventory_movements' AND c.column_name IN ('product_id','movement_type','quantity','units_changed')) OR (c.table_name='combos' AND c.column_name IN ('id','name','price')) OR (c.table_name='combo_items' AND c.column_name IN ('combo_id','product_id','quantity')) OR (c.table_name='store_settings' AND c.column_name IN ('setting_key','setting_value')) OR (c.table_name='yape_orders' AND c.column_name IN ('id','order_code','expected_amount','declared_amount','status')) OR (c.table_name='stock_reservations' AND c.column_name IN ('order_id','product_id','quantity','status','expires_at')) OR (c.table_name='store_featured_products' AND c.column_name IN ('product_id','position','active')))) AS stockflow_legacy_columns, (SELECT COUNT(*) FROM store_settings WHERE setting_key='stockflow_schema_marker') AS stockflow_marker_keys;" 2>/dev/null)" || fail "No se pudo validar la huella legacy de esquema StockFlow."
    IFS=$'\t' read -r legacy_database legacy_tables legacy_columns marker_keys <<< "$legacy_schema"
    if [[ "$legacy_database" != "$DB_NAME" || "$marker_keys" != "0" ]]; then
        fail "La base contiene un marcador StockFlow incompatible; no se importo la migracion."
    fi
    if [[ "$legacy_tables" != "$LEGACY_TABLE_COUNT" || "$legacy_columns" != "$LEGACY_COLUMN_COUNT" ]]; then
        fail "La base no coincide con la huella legacy del esquema StockFlow esperada; no se importo la migracion."
    fi
    needs_enrollment=1
    printf 'Huella legacy StockFlow validada; se requiere inscripcion explicita antes de migrar.\n'
fi

source_count="$("${mysql_common[@]}" --batch --skip-column-names --execute='SELECT COUNT(*) FROM productos;')" || fail "No se pudo contar la tabla productos."
source_count="$(printf '%s' "$source_count" | tr -d '[:space:]')"
if [[ "$source_count" != "$EXPECTED_COUNT" ]]; then
    fail "La tabla productos contiene $source_count filas; se esperaban $EXPECTED_COUNT. Detente e inspecciona catalog_migration_issues antes de reintentar."
fi

if [[ "$needs_enrollment" == "1" ]]; then
    read -r -p "La base '$DB_NAME' coincide con la huella legacy y contiene $EXPECTED_COUNT filas. Para inscribirla, escribe exactamente '$DB_NAME': " ENROLL_CONFIRM
    [[ "$ENROLL_CONFIRM" == "$DB_NAME" ]] || fail "Confirmacion requerida para inscribir '$DB_NAME'. No se modifico la base."
    unset ENROLL_CONFIRM
    "${mysql_common[@]}" --batch --skip-column-names --execute="INSERT INTO store_settings (setting_key,setting_value) VALUES ('stockflow_schema_marker','catalogo_11604') ON DUPLICATE KEY UPDATE setting_value=VALUES(setting_value);" >/dev/null || fail "No se pudo inscribir el marcador StockFlow; no se importo la migracion."
    printf 'Marcador StockFlow inscrito tras confirmacion explicita.\n'
fi

printf '2/4 Importando la migracion no destructiva...\n'
if ! "${mysql_common[@]}" < "$UPDATE_SQL"; then
    fail "La migracion se detuvo. No actives productos; revisa catalog_migration_issues y el ultimo registro de catalog_migrations."
fi

printf '3/4 Ejecutando las consultas de verificacion...\n'
"${mysql_common[@]}" --table --execute='SELECT COUNT(*) AS source_rows FROM productos; SELECT COUNT(*) AS operational_rows FROM products WHERE source_product_id IS NOT NULL; SELECT status,source_count,imported_count FROM catalog_migrations ORDER BY id DESC LIMIT 1;' || fail "No se pudieron ejecutar las consultas de verificacion."

verification="$("${mysql_common[@]}" --batch --skip-column-names --execute="SELECT (SELECT COUNT(*) FROM productos),(SELECT COUNT(*) FROM products WHERE source_product_id IS NOT NULL),COALESCE((SELECT status FROM catalog_migrations ORDER BY id DESC LIMIT 1),'missing'),COALESCE((SELECT source_count FROM catalog_migrations ORDER BY id DESC LIMIT 1),0),COALESCE((SELECT imported_count FROM catalog_migrations ORDER BY id DESC LIMIT 1),0),(SELECT COUNT(*) FROM catalog_migration_issues WHERE migration_key='catalogo_maestro_11604');")" || fail "No se pudo validar el resultado final."
IFS=$'\t' read -r final_source final_operational migration_status recorded_source recorded_imported issue_count <<< "$verification"

if [[ "$final_source" != "$EXPECTED_COUNT" || "$final_operational" != "$EXPECTED_COUNT" || "$migration_status" != "completed" || "$recorded_source" != "$EXPECTED_COUNT" || "$recorded_imported" != "$EXPECTED_COUNT" || "$issue_count" != "0" ]]; then
    fail "La verificacion no coincide (fuente=$final_source, operativos=$final_operational, estado=$migration_status, incidencias=$issue_count). Detente e inspecciona catalog_migration_issues."
fi

printf '4/4 Verificacion completada.\n'
printf '\nCATALOGO INSTALADO: fuente=%s, operativos=%s, estado=%s.\n' "$final_source" "$final_operational" "$migration_status"
printf 'Los productos maestros permanecen desactivados hasta que revises precio, stock, restricciones y venta desde el panel.\n'

if [[ -t 0 ]]; then
    read -r -p 'Presiona Enter para cerrar...' _
fi
