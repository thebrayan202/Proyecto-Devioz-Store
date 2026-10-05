const fs = require('fs');
const assert = require('assert');

const rootHtaccess = fs.readFileSync('.htaccess', 'utf8');
assert(rootHtaccess.includes('Require all granted'));
assert(fs.existsSync('admin/.htaccess'));
assert(fs.readFileSync('admin/.htaccess', 'utf8').includes('Require all granted'));
assert(fs.existsSync('INSTALAR_PERMISOS_XAMPP.command'));
console.log('xampp_access_test OK');
