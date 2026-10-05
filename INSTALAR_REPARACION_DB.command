#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
XAMPP="/Applications/XAMPP/xamppfiles"
MYSQL="$XAMPP/bin/mysql"
MYSQLADMIN="$XAMPP/bin/mysqladmin"
SQL_FILE="$ROOT_DIR/database/devioz_shop_reparada.sql"
UPGRADE_FILE="$ROOT_DIR/database/upgrade_catalogo_unificado_profesional.sql"
DB_NAME="devioz_shop_reparada"

printf '\nDEVIOZ STORE - REPARACION DE BASE DE DATOS\n'
printf '=========================================\n\n'

if [ ! -x "$MYSQL" ] || [ ! -x "$MYSQLADMIN" ]; then
  echo "ERROR: No se encontró MySQL de XAMPP en $XAMPP"
  echo "Abre XAMPP y verifica que esté instalado en /Applications/XAMPP."
  read -r -p "Presiona Enter para cerrar..." _
  exit 1
fi

if [ ! -f "$SQL_FILE" ] || [ ! -f "$UPGRADE_FILE" ]; then
  echo "ERROR: Falta la base reparada o la migración profesional."
  read -r -p "Presiona Enter para cerrar..." _
  exit 1
fi

if ! "$MYSQLADMIN" --socket="$XAMPP/var/mysql/mysql.sock" -u root ping >/dev/null 2>&1; then
  echo "ERROR: MySQL no está respondiendo."
  echo "Inicia MySQL desde XAMPP y vuelve a ejecutar este archivo."
  read -r -p "Presiona Enter para cerrar..." _
  exit 1
fi

echo "1/4 Creando una base limpia: $DB_NAME"
"$MYSQL" --socket="$XAMPP/var/mysql/mysql.sock" -u root < "$SQL_FILE"

echo "2/4 Activando catálogo unificado, contenido e IA..."
"$MYSQL" --socket="$XAMPP/var/mysql/mysql.sock" -u root "$DB_NAME" < "$UPGRADE_FILE"

echo "3/4 Verificando tablas principales..."
VERIFY="$($MYSQL --socket="$XAMPP/var/mysql/mysql.sock" -u root -N -e "USE $DB_NAME; SHOW TABLES WHERE Tables_in_${DB_NAME} IN ('products','shopping_sources','users');")"
for TABLE in products shopping_sources users; do
  if ! printf '%s\n' "$VERIFY" | grep -qx "$TABLE"; then
    echo "ERROR: No se creó la tabla $TABLE."
    read -r -p "Presiona Enter para cerrar..." _
    exit 1
  fi
done

echo "4/4 Verificando consulta del catálogo profesional..."
"$MYSQL" --socket="$XAMPP/var/mysql/mysql.sock" -u root -N -e "USE $DB_NAME; SELECT CONCAT('productos_unificados=', COUNT(*)) FROM v_unified_products;"

echo
echo "REPARACION COMPLETADA."
echo "La base antigua devioz_shop se dejó intacta."
echo "Abre: http://localhost/stockflow/"
echo
read -r -p "Presiona Enter para cerrar..." _
