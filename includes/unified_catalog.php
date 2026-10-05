<?php
declare(strict_types=1);

function external_suggested_price(float $cost, ?float $customPrice, ?float $customMargin, float $globalMargin): ?float
{
    if ($cost <= 0) return null;
    if ($customPrice !== null && $customPrice > 0) return round($customPrice, 2);
    $margin = max(0.0, min(500.0, $customMargin ?? $globalMargin));
    return round($cost * (1 + $margin / 100), 2);
}

function catalog_profitability(?float $cost, ?float $salePrice, ?int $stock, string $sourceType): array
{
    $type = $sourceType === 'internal' ? 'real' : 'estimated';
    if ($cost === null || $cost <= 0 || $salePrice === null || $salePrice <= 0) {
        return ['unit_profit' => null, 'margin' => null, 'potential_profit' => null, 'profit_type' => $type];
    }
    $unit = round($salePrice - $cost, 2);
    return [
        'unit_profit' => $unit,
        'margin' => round($unit * 100 / $salePrice, 2),
        'potential_profit' => $sourceType === 'internal' ? round($unit * max(0, (int) $stock), 2) : null,
        'profit_type' => $type,
    ];
}

function unified_catalog_filters(array $input): array
{
    $rows = (int) ($input['rows'] ?? 25);
    $sort = (string) ($input['sort'] ?? 'name');
    $dir = strtolower((string) ($input['dir'] ?? 'asc'));
    $availability = (string) ($input['availability'] ?? '');
    return [
        'q' => mb_substr(trim((string) ($input['q'] ?? '')), 0, 100),
        'source' => mb_substr(trim((string) ($input['source'] ?? '')), 0, 40),
        'category' => mb_substr(trim((string) ($input['category'] ?? '')), 0, 150),
        'availability' => in_array($availability, ['', 'available', 'unavailable', 'low'], true) ? $availability : '',
        'min_price' => is_numeric($input['min_price'] ?? null) ? max(0.0, (float) $input['min_price']) : null,
        'max_price' => is_numeric($input['max_price'] ?? null) ? max(0.0, (float) $input['max_price']) : null,
        'sort' => in_array($sort, ['name', 'cost', 'sale_price', 'unit_profit', 'margin', 'updated_at'], true) ? $sort : 'name',
        'dir' => in_array($dir, ['asc', 'desc'], true) ? $dir : 'asc',
        'page' => max(1, (int) ($input['page'] ?? 1)),
        'rows' => in_array($rows, [25, 50, 100], true) ? $rows : 25,
    ];
}

function unified_catalog_where(array $filters): array
{
    $where = ['available IN (0,1)'];
    $params = [];
    if ($filters['q'] !== '') {
        $where[] = '(name LIKE :q_name OR code LIKE :q_code OR category LIKE :q_category OR brand LIKE :q_brand)';
        foreach (['q_name', 'q_code', 'q_category', 'q_brand'] as $key) $params[$key] = '%' . $filters['q'] . '%';
    }
    if ($filters['source'] !== '') { $where[] = 'source_name = :source'; $params['source'] = $filters['source']; }
    if ($filters['category'] !== '') { $where[] = 'category = :category'; $params['category'] = $filters['category']; }
    if ($filters['availability'] === 'available') $where[] = 'available = 1';
    if ($filters['availability'] === 'unavailable') $where[] = 'available = 0';
    if ($filters['availability'] === 'low') $where[] = "source_type = 'internal' AND stock <= 5";
    if ($filters['min_price'] !== null) { $where[] = 'cost >= :min_price'; $params['min_price'] = $filters['min_price']; }
    if ($filters['max_price'] !== null) { $where[] = 'cost <= :max_price'; $params['max_price'] = $filters['max_price']; }
    return ['sql' => ' WHERE ' . implode(' AND ', $where), 'params' => $params];
}

function unified_catalog_base_sql(): string
{
    return "SELECT v.*, ROUND(v.sale_price-v.cost,2) unit_profit,
        CASE WHEN v.sale_price>0 AND v.cost IS NOT NULL THEN ROUND((v.sale_price-v.cost)*100/v.sale_price,2) ELSE NULL END margin,
        CASE WHEN v.source_type='internal' THEN ROUND((v.sale_price-v.cost)*GREATEST(COALESCE(v.stock,0),0),2) ELSE NULL END potential_profit
        FROM v_unified_products v";
}

function bind_catalog_params(PDOStatement $statement, array $params): void
{
    foreach ($params as $key => $value) {
        $statement->bindValue(':' . $key, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
    }
}

function fetch_unified_catalog(PDO $pdo, array $filters): array
{
    $where = unified_catalog_where($filters);
    $count = $pdo->prepare('SELECT COUNT(*) FROM v_unified_products' . $where['sql']);
    bind_catalog_params($count, $where['params']);
    $count->execute();
    $total = (int) $count->fetchColumn();
    $pages = max(1, (int) ceil($total / $filters['rows']));
    $page = min($filters['page'], $pages);
    $order = ['name'=>'name','cost'=>'cost','sale_price'=>'sale_price','unit_profit'=>'unit_profit','margin'=>'margin','updated_at'=>'updated_at'][$filters['sort']];
    $sql = 'SELECT * FROM (' . unified_catalog_base_sql() . $where['sql'] . ') catalog_rows ORDER BY ' . $order . ' ' . strtoupper($filters['dir']) . ', source_id ASC LIMIT :limit OFFSET :offset';
    $statement = $pdo->prepare($sql);
    bind_catalog_params($statement, $where['params']);
    $statement->bindValue(':limit', $filters['rows'], PDO::PARAM_INT);
    $statement->bindValue(':offset', ($page - 1) * $filters['rows'], PDO::PARAM_INT);
    $statement->execute();
    return ['items' => $statement->fetchAll(), 'total' => $total, 'pages' => $pages, 'page' => $page];
}

function unified_catalog_options(PDO $pdo): array
{
    return [
        'sources' => $pdo->query('SELECT DISTINCT source_name FROM v_unified_products ORDER BY source_name')->fetchAll(PDO::FETCH_COLUMN),
        'categories' => $pdo->query("SELECT DISTINCT category FROM v_unified_products WHERE category<>'' ORDER BY category")->fetchAll(PDO::FETCH_COLUMN),
    ];
}

function unified_catalog_summary(PDO $pdo): array
{
    $sql = "SELECT COUNT(*) total,
        SUM(source_type='internal') internal_total,
        SUM(source_type='external') external_total,
        COALESCE(SUM(CASE WHEN source_type='internal' THEN stock ELSE 0 END),0) stock_units,
        COALESCE(SUM(CASE WHEN source_type='internal' THEN cost*stock ELSE 0 END),0) inventory_cost,
        COALESCE(SUM(CASE WHEN source_type='internal' THEN (sale_price-cost)*stock ELSE 0 END),0) potential_profit,
        COALESCE(SUM(CASE WHEN source_type='external' AND available=1 THEN sale_price-cost ELSE 0 END),0) estimated_external_unit_profit
        FROM v_unified_products";
    return $pdo->query($sql)->fetch() ?: [];
}

function validate_margin(mixed $value): float
{
    if (!is_numeric($value)) throw new InvalidArgumentException('El margen debe ser numérico.');
    $margin = (float) $value;
    if ($margin < 0 || $margin > 500) throw new InvalidArgumentException('El margen debe estar entre 0 % y 500 %.');
    return round($margin, 2);
}

function validate_money(mixed $value, bool $nullable = false): ?float
{
    if ($nullable && trim((string) $value) === '') return null;
    if (!is_numeric($value)) throw new InvalidArgumentException('El precio debe ser numérico.');
    $money = (float) $value;
    if ($money < 0 || $money > 999999.99) throw new InvalidArgumentException('El precio está fuera del rango permitido.');
    return round($money, 2);
}

function parse_item_key(string $itemKey): array
{
    if (!preg_match('~^(internal|external):([1-9][0-9]*)$~D', $itemKey, $matches)) throw new InvalidArgumentException('Producto no válido.');
    return ['source_type' => $matches[1], 'source_id' => (int) $matches[2]];
}

function unified_catalog_export_headers(): array
{
    return ['Origen','Código','Producto','Marca','Categoría','Costo','Precio de venta','Ganancia unitaria','Margen','Stock','Tipo de ganancia','Actualización'];
}

function save_external_price(PDO $pdo, int $id, ?float $price, ?float $margin): void
{
    if ($id < 1) throw new InvalidArgumentException('Producto externo no válido.');
    $statement = $pdo->prepare('INSERT INTO external_product_pricing(external_product_id,custom_sale_price,custom_margin_pct) VALUES (?,?,?) ON DUPLICATE KEY UPDATE custom_sale_price=VALUES(custom_sale_price),custom_margin_pct=VALUES(custom_margin_pct)');
    $statement->execute([$id, $price, $margin]);
}

function convert_external_to_inventory(PDO $pdo, int $externalId, array $input): int
{
    if ($externalId < 1) throw new InvalidArgumentException('Producto externo no válido.');
    $pdo->beginTransaction();
    try {
        $query = $pdo->prepare('SELECT * FROM productos WHERE id_producto=? FOR UPDATE');
        $query->execute([$externalId]);
        $external = $query->fetch();
        if (!$external) throw new RuntimeException('El producto externo ya no existe.');
        $code = 'EXT-' . $externalId;
        $exists = $pdo->prepare('SELECT id FROM products WHERE code=? LIMIT 1');
        $exists->execute([$code]);
        if ($exists->fetchColumn()) throw new RuntimeException('Este producto ya fue agregado al inventario.');
        $cost = validate_money($input['cost_price'] ?? $external['precio_actual']);
        $price = validate_money($input['price'] ?? null);
        $stock = max(0, min(1000000, (int) ($input['stock'] ?? 0)));
        if ($price === null || $price <= 0) throw new InvalidArgumentException('Indica un precio de venta mayor que cero.');
        $insert = $pdo->prepare('INSERT INTO products(code,name,category,description,cost_price,price,stock,min_stock,image_url,active) VALUES (?,?,?,?,?,?,?,?,?,1)');
        $insert->execute([$code, mb_substr((string)$external['producto'],0,120), mb_substr((string)($external['categoria'] ?: 'General'),0,80), 'Importado desde ' . (string)($external['supermercado'] ?: 'proveedor externo'), $cost, $price, $stock, 5, mb_substr((string)($external['imagen'] ?? ''),0,500)]);
        $id = (int) $pdo->lastInsertId();
        $pdo->commit();
        return $id;
    } catch (Throwable $exception) {
        if ($pdo->inTransaction()) $pdo->rollBack();
        throw $exception;
    }
}
