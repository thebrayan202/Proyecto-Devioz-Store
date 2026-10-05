#!/bin/bash
set -euo pipefail

DEFAULT_DB_NAME="devioz_shop_reparada"
MYSQL_CNF=""
fail() { printf '\nERROR: %s\n' "$1" >&2; exit 1; }
cleanup() { [[ -z "$MYSQL_CNF" || ! -f "$MYSQL_CNF" ]] || rm -f -- "$MYSQL_CNF"; }
mysql_option_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    printf '%s' "$value"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

MYSQL_BIN="${MYSQL_BIN_OVERRIDE:-}"
if [[ -n "$MYSQL_BIN" ]]; then
    [[ -x "$MYSQL_BIN" ]] || fail "MYSQL_BIN_OVERRIDE no apunta a un ejecutable."
else
    for candidate in /Applications/XAMPP/xamppfiles/bin/mysql /Applications/XAMPP/bin/mysql /opt/lampp/bin/mysql; do
        if [[ -x "$candidate" ]]; then MYSQL_BIN="$candidate"; break; fi
    done
    [[ -n "$MYSQL_BIN" ]] || { command -v mysql >/dev/null 2>&1 && MYSQL_BIN="$(command -v mysql)"; }
    [[ -n "$MYSQL_BIN" ]] || { command -v mariadb >/dev/null 2>&1 && MYSQL_BIN="$(command -v mariadb)"; }
fi
[[ -n "$MYSQL_BIN" ]] || fail "No se encontro el cliente mysql de XAMPP."

PHP_BIN="${PHP_BIN_OVERRIDE:-}"
if [[ -n "$PHP_BIN" ]]; then
    [[ -x "$PHP_BIN" ]] || fail "PHP_BIN_OVERRIDE no apunta a un ejecutable."
else
    for candidate in /Applications/XAMPP/xamppfiles/bin/php /Applications/XAMPP/bin/php /opt/lampp/bin/php; do
        if [[ -x "$candidate" ]]; then PHP_BIN="$candidate"; break; fi
    done
    [[ -n "$PHP_BIN" ]] || { command -v php >/dev/null 2>&1 && PHP_BIN="$(command -v php)"; }
fi
[[ -n "$PHP_BIN" ]] || fail "No se encontro PHP de XAMPP para generar el hash seguro."

printf '\nDEVIOZ STORE - CREAR ADMINISTRADOR INICIAL\n'
printf '===========================================\n'
printf 'Usa este asistente una sola vez despues de importar el SQL completo.\n'

read -r -p 'Host MySQL [127.0.0.1]: ' DB_HOST; DB_HOST="${DB_HOST:-127.0.0.1}"
read -r -p 'Puerto MySQL [3306]: ' DB_PORT; DB_PORT="${DB_PORT:-3306}"
read -r -p "Base de datos [$DEFAULT_DB_NAME]: " DB_NAME; DB_NAME="${DB_NAME:-$DEFAULT_DB_NAME}"
if [[ "$DB_NAME" != "$DEFAULT_DB_NAME" ]]; then
    read -r -p "Para confirmar la base alternativa, escribe exactamente '$DB_NAME': " DB_CONFIRM
    [[ "$DB_CONFIRM" == "$DB_NAME" ]] || fail "Confirmacion requerida para la base alternativa '$DB_NAME'. No se ejecuto MySQL."
    unset DB_CONFIRM
fi
read -r -p 'Usuario MySQL [root]: ' DB_USER; DB_USER="${DB_USER:-root}"
read -r -s -p 'Contrasena MySQL (Enter si esta vacia): ' DB_PASSWORD; printf '\n'

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
    printf 'port=%s\nprotocol=tcp\n' "$DB_PORT"
} > "$MYSQL_CNF"
unset DB_PASSWORD
mysql_common=("$MYSQL_BIN" "--defaults-extra-file=$MYSQL_CNF" "--database=$DB_NAME")

printf '\n1/3 Verificando el esquema del proyecto...\n'
"${mysql_common[@]}" --batch --skip-column-names --execute='SELECT 1;' >/dev/null || fail "No se pudo conectar a $DB_NAME. Revisa XAMPP y las credenciales."
schema_marker="$("${mysql_common[@]}" --batch --skip-column-names --execute="SELECT DATABASE(), (SELECT COUNT(*) FROM information_schema.tables t WHERE t.table_schema=DATABASE() AND t.table_name IN ('users','categories','products','product_images','inventory_movements','store_settings') AND EXISTS (SELECT 1 FROM store_settings s WHERE s.setting_key='stockflow_schema_marker' AND s.setting_value='catalogo_11604')), (SELECT COUNT(*) FROM information_schema.columns c WHERE c.table_schema=DATABASE() AND c.table_name='products' AND c.column_name IN ('id','code','name','category','price','stock'));" 2>/dev/null)" || fail "No se pudo validar el marcador de esquema StockFlow."
IFS=$'\t' read -r marker_database marker_tables marker_columns <<< "$schema_marker"
if [[ "$marker_database" != "$DB_NAME" || "$marker_tables" != "6" || "$marker_columns" != "6" ]]; then
    fail "La base no contiene el marcador de esquema StockFlow esperado. Importa primero el SQL completo."
fi
admin_count="$("${mysql_common[@]}" --batch --skip-column-names --execute="SELECT COUNT(*) FROM users WHERE role='admin' OR username='admin';")" || fail "No se pudo comprobar si ya existe un administrador."
admin_count="$(printf '%s' "$admin_count" | tr -d '[:space:]')"
[[ "$admin_count" == "0" ]] || fail "El administrador ya existe; el bootstrap inicial fue rechazado."

printf '2/3 Definiendo una contrasena inicial fuerte...\n'
read -r -s -p 'Nueva contrasena del administrador: ' ADMIN_PASSWORD; printf '\n'
read -r -s -p 'Repite la contrasena del administrador: ' ADMIN_PASSWORD_CONFIRM; printf '\n'
[[ "$ADMIN_PASSWORD" == "$ADMIN_PASSWORD_CONFIRM" ]] || fail "Las contrasenas no coinciden."
unset ADMIN_PASSWORD_CONFIRM
if [[ ${#ADMIN_PASSWORD} -lt 12 || "$ADMIN_PASSWORD" != *[[:upper:]]* || "$ADMIN_PASSWORD" != *[[:lower:]]* || "$ADMIN_PASSWORD" != *[[:digit:]]* || "$ADMIN_PASSWORD" != *[![:alnum:]]* ]]; then
    unset ADMIN_PASSWORD
    fail "La contrasena debe tener al menos 12 caracteres, mayuscula, minuscula, numero y simbolo."
fi
ADMIN_HASH="$(printf '%s' "$ADMIN_PASSWORD" | "$PHP_BIN" -r '$password = stream_get_contents(STDIN); if (!is_string($password) || strlen($password) < 12) { exit(1); } $hash = password_hash($password, PASSWORD_DEFAULT); if (!is_string($hash)) { exit(1); } echo $hash;' 2>/dev/null)" || { unset ADMIN_PASSWORD; fail "PHP no pudo generar el hash de la contrasena."; }
unset ADMIN_PASSWORD
[[ "$ADMIN_HASH" =~ ^\$[a-z0-9]+\$ ]] || fail "PHP no devolvio un hash valido."

printf '3/3 Creando el unico administrador inicial...\n'
printf "INSERT INTO users (name, username, password, role) VALUES ('Administrador', 'admin', '%s', 'admin');\n" "$ADMIN_HASH" | "${mysql_common[@]}" >/dev/null || fail "No se pudo crear el administrador inicial."
unset ADMIN_HASH
printf '\nAdministrador inicial creado. Guarda la contrasena en un gestor seguro.\n'
