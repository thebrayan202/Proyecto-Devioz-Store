<?php
declare(strict_types=1);
require_once __DIR__ . '/shopping_sources.php';
require_once __DIR__ . '/shopping_ai.php';

function shopping_cents(string $value): int {
    $value = str_replace(',', '.', trim($value));
    if (!preg_match('/^\d{1,5}(?:\.\d{1,2})?$/D', $value)) {
        throw new InvalidArgumentException('Escribe un presupuesto válido con hasta dos decimales.');
    }
    $parts = explode('.', $value);
    $cents = (int)$parts[0] * 100 + (int)str_pad($parts[1] ?? '', 2, '0');
    if ($cents < 1 || $cents > 1000000) throw new InvalidArgumentException('El presupuesto debe estar entre S/ 0.01 y S/ 10,000.');
    return $cents;
}

function shopping_allowed(array $product): bool {
    return !isset($product['external_id']) && recommendation_candidate_is_sellable($product)
        && shopping_food_safe((string)$product['name'], (string)$product['category'])
        && in_array($product['category'], shopping_categories(), true);
}

function shopping_plan(array $products, int $budget, int $limit, string $request, string $category, array $config, ?PDO $pdo = null): array {
    if ($budget < 1 || $budget > 1000000 || $limit < 1 || $limit > 20) throw new InvalidArgumentException('Presupuesto o cantidad inválidos.');
    $products = array_slice(array_values(array_filter($products, static fn($p) => shopping_allowed($p)
        && (int)round((float)$p['price']*100) <= $budget
        && ($category === '' || $p['category'] === $category))), 0, 60);
    usort($products, static fn($a, $b) => (float)$a['price'] <=> (float)$b['price'] ?: (int)$a['id'] <=> (int)$b['id']);
    $mode = 'Modo básico: selección por categoría y precio. El texto libre requiere IA.';
    if ($request !== '' && $products) {
        $selection = shopping_ai_select($products, $request, $config);
        $mode = $selection['mode'];
        if ($pdo !== null) {
            if ($selection['ids'] === null) {
                // The model may have timed out or returned invalid JSON. Re-read
                // the same public candidate scope before using the deterministic
                // fallback so no stale/restricted row reaches the proposal.
                $products = shopping_load_catalog($pdo, 0, $category, $config, $request);
            } else {
                $products = shopping_load_catalog_by_ids($pdo, array_map('intval', $selection['ids']), $category, $budget);
            }
        }
        if ($selection['ids'] !== null) {
            $ids = $selection['ids'];
            $products = array_values(array_filter($products, static fn($p)=>in_array((int)$p['id'],$ids,true)));
            usort($products, static fn($a,$b)=>array_search((int)$a['id'],$ids,true)<=>array_search((int)$b['id'],$ids,true));
        }
    }
    $remaining = $budget; $rows = []; $units = 0;
    // Una unidad por producto en cada vuelta para favorecer variedad.
    do {
        $added = false;
        foreach ($products as $product) {
            $id = (int)$product['id']; $price = (int)round((float)$product['price'] * 100);
            $qty = $rows[$id]['quantity'] ?? 0;
            if ($price < 1 || $price > $remaining || $qty >= min($product['stock'] === null ? $limit : (int)$product['stock'], $limit) || $units >= 100 || (!isset($rows[$id]) && count($rows) >= RECOMMENDATION_MAX_LINES)) continue;
            if (!isset($rows[$id])) $rows[$id] = array_merge($product, ['quantity'=>0,'unit_cents'=>$price]);
            $rows[$id]['quantity']++; $remaining -= $price; $units++; $added = true;
        }
    } while ($added && $units < 100);
    return ['items'=>array_values($rows),'total'=>$budget-$remaining,'remaining'=>$remaining,'mode'=>$mode];
}

function shopping_compare_reference(int $reference, int $total): array {
    if($reference<1 || $total<0)throw new InvalidArgumentException('Referencia inválida.');
    return ['reference'=>$reference,'difference'=>$reference-$total,'percent'=>($reference-$total)*100/$reference];
}
