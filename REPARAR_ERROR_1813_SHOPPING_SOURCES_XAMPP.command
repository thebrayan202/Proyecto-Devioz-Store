#!/bin/bash
set -e

DB_DIR="/Applications/XAMPP/xamppfiles/var/mysql/devioz_shop"

echo "Reparacion opcional para MySQL #1813 en shopping_sources/shopping_offers."
echo "Esto elimina restos fisicos .ibd/.frm de tablas externas opcionales."
echo ""

if [ ! -d "$DB_DIR" ]; then
  echo "No encontre la carpeta de datos: $DB_DIR"
  read -n 1 -s -r -p "Presiona una tecla para cerrar..."
  exit 1
fi

echo "Deten MySQL desde el panel de XAMPP antes de continuar."
read -n 1 -s -r -p "Cuando MySQL este detenido, presiona una tecla..."
echo ""

sudo rm -f "$DB_DIR/shopping_sources.ibd" "$DB_DIR/shopping_sources.frm" "$DB_DIR/shopping_sources.cfg"
sudo rm -f "$DB_DIR/shopping_offers.ibd" "$DB_DIR/shopping_offers.frm" "$DB_DIR/shopping_offers.cfg"
sudo rm -f "$DB_DIR/shopping_ai_usage.ibd" "$DB_DIR/shopping_ai_usage.frm" "$DB_DIR/shopping_ai_usage.cfg"

echo "Listo. Inicia MySQL otra vez desde XAMPP."
echo "Luego, si necesitas el catalogo externo, importa database/upgrade_shopping_sources.sql."
read -n 1 -s -r -p "Presiona una tecla para cerrar..."
