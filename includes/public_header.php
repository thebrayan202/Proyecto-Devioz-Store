<?php
declare(strict_types=1);

$pageTitle = $pageTitle ?? 'Devioz Store';
$currentPage = basename((string) ($_SERVER['SCRIPT_NAME'] ?? ''));
$headerSearchValue = mb_substr(trim((string) ($_GET['q'] ?? '')), 0, 120);
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="Devioz Store: productos disponibles, ofertas y combos en un solo lugar.">
    <title><?= e($pageTitle) ?> | Devioz Store</title>
    <link rel="icon" href="<?= url('assets/img/favicon.svg') ?>" type="image/svg+xml">
    <link rel="stylesheet" href="<?= url('assets/css/styles.css?v=' . (string) @filemtime(__DIR__ . '/../assets/css/styles.css')) ?>">
</head>
<body class="public-body">
    <a class="skip-link" href="#contenidoPrincipal">Saltar al contenido</a>
    <div class="store-topbar" aria-label="Beneficios de la tienda">
        <div class="container">
            <span><b aria-hidden="true">✓</b> Precios Devioz claros</span>
            <span><b aria-hidden="true">⌖</b> Entrega o recojo</span>
            <span><b aria-hidden="true">✦</b> Asistente de compras</span>
        </div>
    </div>
    <header class="public-header convenience-header">
        <div class="container public-header-main">
            <a class="brand store-brand devioz-brand" href="<?= url('index.php') ?>" aria-label="Devioz Store, ir al inicio">
                <img class="devioz-logo devioz-logo-header" src="<?= url('assets/img/logo-devioz-store.png') ?>" alt="Devioz Store">
                <span><strong>Devioz Store</strong><small>COMPRA SIMPLE · COMPRA LOCAL</small></span>
            </a>

            <button class="mobile-menu-toggle" type="button" data-mobile-menu aria-controls="publicNav" aria-expanded="false">
                <span aria-hidden="true">☰</span><span>Menú</span>
            </button>

            <nav class="public-nav" id="publicNav" data-mobile-menu-panel aria-label="Navegación principal">
                <a class="<?= $currentPage === 'index.php' ? 'active' : '' ?>" href="<?= url('index.php#inicio') ?>">Inicio</a>
                <a class="<?= $currentPage === 'catalogo_completo.php' ? 'active' : '' ?>" href="<?= url('catalogo_completo.php') ?>">Catálogo</a>
                <a href="<?= url('index.php#ofertas') ?>">Ofertas</a>
                <a href="<?= url('index.php#combos') ?>">Combos</a>
                <a class="<?= $currentPage === 'asistente_compras.php' ? 'active' : '' ?>" href="<?= url('asistente_compras.php') ?>">Asistente IA</a>
            </nav>

            <div class="header-actions">
                <a class="order-access-link" href="<?= url('mi_cuenta.php') ?>">
                    <span aria-hidden="true">◎</span><span><small><?= is_customer() ? 'Hola de nuevo' : 'Ingresa o regístrate' ?></small><b>Mi cuenta</b></span>
                </a>
                <button class="shopping-list-toggle" type="button" data-list-open aria-haspopup="dialog">
                    <span aria-hidden="true">🛒</span><span><small>Tu compra</small><b>Mi lista</b></span><em id="listBadge">0</em>
                </button>
            </div>
        </div>

        <div class="container supermarket-tools">
            <a class="category-menu-button" href="<?= url('index.php#categorias') ?>"><span aria-hidden="true">☰</span> Categorías</a>
            <form class="supermarket-search" action="<?= url('catalogo_completo.php') ?>" method="get" role="search">
                <label class="sr-only" for="smartStoreSearch">Buscar productos</label>
                <span aria-hidden="true">⌕</span>
                <input id="smartStoreSearch" name="q" type="search" value="<?= e($headerSearchValue) ?>" placeholder="Busca por producto, marca o categoría" autocomplete="off">
                <button type="submit" id="smartStoreSearchButton">Buscar</button>
            </form>
            <a class="delivery-selector" href="<?= url('mi_cuenta.php') ?>">
                <span aria-hidden="true">⌖</span><span><b>Entrega o recojo</b><small>Elige tu ubicación</small></span>
            </a>
        </div>

        <div class="delivery-promise-row">
            <div class="container">
                <span><b aria-hidden="true">●</b> Catálogo actualizado</span>
                <a href="<?= url('pedido_login.php') ?>">Revisa tu pedido <span aria-hidden="true">→</span></a>
            </div>
        </div>
    </header>
    <main id="contenidoPrincipal">
