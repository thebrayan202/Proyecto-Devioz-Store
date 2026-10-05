#!/bin/bash
set -euo pipefail

XAMPP_ROOT="/Applications/XAMPP/xamppfiles"
DATABASE_DIR="${XAMPP_ROOT}/var/mysql/devioz_shop"
BACKUP_ROOT="${XAMPP_ROOT}/var/devioz_backups"
BACKUP_DIR="${BACKUP_ROOT}/catalogo_auxiliar_$(date +%Y%m%d_%H%M%S)"

if [ ! -d "${DATABASE_DIR}" ]; then
    echo "No se encontro la base devioz_shop en ${DATABASE_DIR}."
    echo "Verifica que XAMPP este instalado en /Applications/XAMPP."
    read -r -p "Presiona Enter para cerrar..."
    exit 1
fi

echo "Se detendra MySQL para retirar los tablespaces auxiliares bloqueados."
echo "macOS puede solicitar la contrasena de tu usuario."
sudo "${XAMPP_ROOT}/xampp" stopmysql >/dev/null 2>&1 || true

if pgrep -f "${XAMPP_ROOT}/bin/mysqld" >/dev/null 2>&1; then
    echo "MySQL continua ejecutandose. Detenlo desde XAMPP Manager y vuelve a abrir este archivo."
    read -r -p "Presiona Enter para cerrar..."
    exit 1
fi

sudo mkdir -p "${BACKUP_DIR}"
MOVED=0

for TABLE_NAME in shopping_offers shopping_sources shopping_ai_usage; do
    for EXTENSION in ibd frm cfg isl; do
        SOURCE_FILE="${DATABASE_DIR}/${TABLE_NAME}.${EXTENSION}"
        if [ -e "${SOURCE_FILE}" ]; then
            sudo mv "${SOURCE_FILE}" "${BACKUP_DIR}/"
            echo "Respaldo creado: ${TABLE_NAME}.${EXTENSION}"
            MOVED=1
        fi
    done
done

sudo "${XAMPP_ROOT}/xampp" startmysql >/dev/null

if [ "${MOVED}" -eq 0 ]; then
    echo "No se encontraron archivos auxiliares bloqueados. MySQL fue iniciado nuevamente."
else
    echo "Reparacion del tablespace completada. Los archivos anteriores quedaron en:"
    echo "${BACKUP_DIR}"
fi

echo "Ahora importa database/reparar_error_1932_catalogo.sql desde phpMyAdmin."
read -r -p "Presiona Enter para cerrar..."
