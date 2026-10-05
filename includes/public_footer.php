    </main>
    <?php require __DIR__ . '/public_cart.php'; ?>
    <footer class="public-footer">
        <div class="container footer-content">
            <div>
                <a class="brand brand-light devioz-brand" href="<?= url('index.php') ?>">
                    <img class="devioz-logo devioz-logo-footer" src="<?= url('assets/img/logo-devioz-store.png') ?>" alt="">
                    <span><strong>Devioz Store</strong><small>COMPRA FÁCIL</small></span>
                </a>
                <p>Control simple. Decisiones inteligentes.</p>
            </div>
            <p>© <?= date('Y') ?> Devioz Store · Tienda peruana</p>
        </div>
    </footer>
    <button class="ai-shop-trigger" id="aiShopTrigger" type="button" aria-controls="aiShopPanel" aria-expanded="false"><span>✦</span> Asistente IA</button>
    <aside class="ai-shop-panel" id="aiShopPanel" hidden aria-label="Asistente inteligente de compras">
        <header><div><small>DEVIOZ IA</small><strong>¿Qué necesitas comprar?</strong></div><button type="button" id="aiShopClose" aria-label="Cerrar">×</button></header>
        <form id="aiShopForm"><label>Describe tu compra<textarea name="query" rows="2" placeholder="Ej.: snacks y bebidas por S/ 50" required></textarea></label><label>Presupuesto máximo<input name="budget" type="number" min="1" max="10000" step="0.01" placeholder="50.00"></label><button class="btn btn-primary" type="submit">Preparar propuesta</button></form>
        <div id="aiShopResult" class="ai-shop-result" aria-live="polite"></div>
    </aside>
    <script>window.STOCKFLOW_BASE_URL = <?= json_encode(BASE_URL, JSON_UNESCAPED_SLASHES) ?>;</script>
    <script src="<?= url('assets/js/public_cart_state.js?v=' . (string) @filemtime(__DIR__ . '/../assets/js/public_cart_state.js')) ?>" defer></script>
    <script src="<?= url('assets/js/checkout_steps.js?v=' . (string) @filemtime(__DIR__ . '/../assets/js/checkout_steps.js')) ?>" defer></script>
    <script src="<?= url('assets/js/app.js?v=' . (string) @filemtime(__DIR__ . '/../assets/js/app.js')) ?>" defer></script>
</body>
</html>
