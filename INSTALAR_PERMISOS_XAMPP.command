#!/bin/bash
set -e

APP_DIR="/Applications/XAMPP/xamppfiles/htdocs/stockflow"

if [ ! -d "$APP_DIR" ]; then
  echo "No encontre la carpeta: $APP_DIR"
  echo "Copia o descomprime el proyecto como stockflow dentro de htdocs, sin espacios al final."
  read -n 1 -s -r -p "Presiona una tecla para cerrar..."
  exit 1
fi

echo "Corrigiendo permisos de StockFlow para XAMPP..."
find "$APP_DIR" -type d -exec chmod 755 {} +
find "$APP_DIR" -type f -exec chmod 644 {} +
find "$APP_DIR" -name '*.command' -type f -exec chmod 755 {} +

echo ""
echo "Listo. Abre primero:"
echo "http://localhost/stockflow/login.php"
echo ""
read -n 1 -s -r -p "Presiona una tecla para cerrar..."
