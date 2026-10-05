<?php
declare(strict_types=1);

require_once __DIR__ . '/master_catalog.php';
require_once __DIR__ . '/ai_recommendations.php';
require_once __DIR__ . '/nutrition.php';

/** Public browsing only includes products that can be shown and purchased. */
function storefront_search_filters(array $input): array
{
    $perPage = (int) ($input['per_page'] ?? $input['rows'] ?? 24);
    $allowedPerPage = [24, 48];
    $allowedSorts = ['featured', 'name', 'price_asc', 'price_desc', 'newest', 'popular'];
    $sort = (string) ($input['sort'] ?? 'featured');
    $maxPriceInput = $input['max_price'] ?? $input['max_budget'] ?? null;
    $maxPrice = is_numeric($maxPriceInput)
        ? max(0.0, min(1000000.0, (float) $maxPriceInput))
        : null;

    return [
        'q' => mb_substr(trim((string) ($input['q'] ?? '')), 0, 120),
        'category' => mb_substr(trim((string) ($input['category'] ?? '')), 0, 80),
        'fast_delivery' => in_array($input['fast_delivery'] ?? false, [true, 1, '1', 'on'], true),
        'offer' => in_array($input['offer'] ?? false, [true, 1, '1', 'on'], true),
        'available_only' => in_array($input['available_only'] ?? false, [true, 1, '1', 'on'], true),
        'min_price' => is_numeric($input['min_price'] ?? null)
            ? max(0.0, min(1000000.0, (float) $input['min_price']))
            : null,
        'max_price' => $maxPrice,
        'max_budget' => $maxPrice,
        'sort' => in_array($sort, $allowedSorts, true) ? $sort : 'featured',
        'per_page' => in_array($perPage, $allowedPerPage, true) ? $perPage : 24,
        'page' => max(1, min(10000, (int) ($input['page'] ?? 1))),
    ];
}

function storefront_product_scope_sql(string $alias = 'p'): string
{
    return 'SELECT ' . $alias . '.id,' . $alias . '.code,' . $alias . '.name,' . $alias . '.category,'
        . $alias . '.brand,' . $alias . '.presentation,' . $alias . '.description,'
        . $alias . '.price AS price,'
        . $alias . '.price AS sale_price,' . $alias . '.active,' . $alias . '.sale_enabled,'
        . $alias . '.stock,' . $alias . '.min_stock,' . $alias . '.units_per_pack,' . $alias . '.pack_price,'
        . $alias . '.image_url,' . $alias . '.featured,' . $alias . '.entrega_inmediata,' . $alias . '.restricted,'
        . ' n.applicability AS nutrition_applicability,n.energy_kcal_100g,n.serving_size,n.serving_unit,n.energy_kcal_serving,n.source_type,n.confidence'
        . ' FROM products ' . $alias . ' LEFT JOIN product_nutrition n ON n.product_id=' . $alias . '.id WHERE ' . master_product_visibility_sql($alias);
}

/** @return array{sql:string,params:array<string,int|float|string>} */
function storefront_catalog_where(array $filters, string $alias = 'p'): array
{
    $filters = storefront_search_filters($filters);
    $where = [
        master_product_visibility_sql($alias),
        public_product_text_visibility_sql($alias),
    ];
    $params = [];

    if ($filters['q'] !== '') {
        $where[] = "CONCAT_WS(' ', $alias.name, $alias.code, $alias.category, $alias.brand, $alias.presentation, $alias.description) LIKE :q";
        $params['q'] = '%' . $filters['q'] . '%';
    }
    if ($filters['category'] !== '') {
        $where[] = $alias . '.category = :category';
        $params['category'] = $filters['category'];
    }
    if ($filters['min_price'] !== null) {
        $where[] = 'COALESCE(NULLIF(' . $alias . '.price,0),' . $alias . '.suggested_price) >= :min_price';
        $params['min_price'] = $filters['min_price'];
    }
    if ($filters['max_price'] !== null) {
        $where[] = 'COALESCE(NULLIF(' . $alias . '.price,0),' . $alias . '.suggested_price) <= :max_price';
        $params['max_price'] = $filters['max_price'];
    }
    if ($filters['fast_delivery']) {
        $where[] = $alias . '.entrega_inmediata = :fast_delivery';
        $params['fast_delivery'] = 1;
    }
    if ($filters['offer']) {
        $where[] = '(' . $alias . '.featured = 1 OR (' . $alias . '.units_per_pack > 1 AND '
            . $alias . '.pack_price > 0 AND ' . $alias . '.pack_price < (' . $alias . '.price * ' . $alias . '.units_per_pack)))';
    }
    return ['sql' => implode(' AND ', $where), 'params' => $params];
}

/** @param array<string,int|float|string> $params */
function storefront_bind_params(PDOStatement $statement, array $params): void
{
    foreach ($params as $name => $value) {
        $statement->bindValue(':' . $name, $value, is_int($value) ? PDO::PARAM_INT : PDO::PARAM_STR);
    }
}

/** @return list<array<string,mixed>> */
function storefront_exclude_age_restricted(array $products): array
{
    return array_values(array_filter(
        $products,
        static fn (array $product): bool => !is_age_restricted_product($product)
    ));
}

/** @return array{items:list<array<string,mixed>>,total:int,pages:int,page:int,per_page:int,filters:array<string,mixed>} */
function storefront_catalog(PDO $pdo, array $input = []): array
{
    $filters = storefront_search_filters($input);
    $where = storefront_catalog_where($filters, 'p');

    $count = $pdo->prepare('SELECT COUNT(*) FROM products p WHERE ' . $where['sql']);
    storefront_bind_params($count, $where['params']);
    $count->execute();
    $total = (int) $count->fetchColumn();
    $pages = max(1, (int) ceil($total / $filters['per_page']));
    $page = min($filters['page'], $pages);

    $orderBy = [
        'featured' => 'p.featured DESC, p.updated_at DESC, p.id DESC',
        'name' => 'p.name ASC, p.id ASC',
        'price_asc' => 'COALESCE(NULLIF(p.price,0),p.suggested_price) ASC, p.name ASC, p.id ASC',
        'price_desc' => 'COALESCE(NULLIF(p.price,0),p.suggested_price) DESC, p.name ASC, p.id ASC',
        'newest' => 'p.updated_at DESC, p.id DESC',
        'popular' => "(SELECT COALESCE(SUM(i.quantity),0) FROM yape_order_items i INNER JOIN yape_orders o ON o.id=i.order_id WHERE i.item_type='product' AND i.item_id=p.id AND o.status='aprobado') DESC, p.featured DESC, p.id DESC",
    ][$filters['sort']];

    $sql = storefront_product_scope_sql('p')
        . substr($where['sql'], strlen(master_product_visibility_sql('p')))
        . ' ORDER BY ' . $orderBy . ' LIMIT :limit OFFSET :offset';
    $statement = $pdo->prepare($sql);
    storefront_bind_params($statement, $where['params']);
    $statement->bindValue(':limit', $filters['per_page'], PDO::PARAM_INT);
    $statement->bindValue(':offset', ($page - 1) * $filters['per_page'], PDO::PARAM_INT);
    $statement->execute();
    $items = storefront_exclude_age_restricted(attach_product_images($statement->fetchAll()));

    return [
        'items' => $items,
        'total' => $total,
        'pages' => $pages,
        'page' => $page,
        'per_page' => $filters['per_page'],
        'filters' => $filters,
    ];
}

/** @return list<string> */
function storefront_categories(PDO $pdo): array
{
    $rows = $pdo->query(
        'SELECT DISTINCT p.category FROM products p WHERE ' . master_product_visibility_sql('p')
        . ' AND ' . public_product_text_visibility_sql('p')
        . " AND p.category <> '' ORDER BY p.category"
    )->fetchAll(PDO::FETCH_COLUMN);

    return array_values(array_filter(
        array_map('strval', $rows),
        static fn (string $category): bool => !is_age_restricted_product(['name' => '', 'category' => $category])
    ));
}

/** @return array<string,mixed> */
function storefront_product_payload(array $product): array
{
    $image = trim((string) ($product['image_url'] ?? ''));
    $saleCandidate = $product;
    $saleCandidate['price'] = (float) ($product['sale_price'] ?? $product['price'] ?? 0);
    $nutrition = nutrition_normalize([
        'applicability' => $product['nutrition_applicability'] ?? nutrition_default_applicability((string) $product['name'], (string) $product['category']),
        'energy_kcal_100g' => $product['energy_kcal_100g'] ?? null,
        'serving_size' => $product['serving_size'] ?? null,
        'serving_unit' => $product['serving_unit'] ?? null,
        'energy_kcal_serving' => $product['energy_kcal_serving'] ?? null,
        'source_type' => $product['source_type'] ?? null,
        'confidence' => $product['confidence'] ?? null,
    ]);
    $nutritionCalc = nutrition_calculate($nutrition, $nutrition['serving_size'], (string) ($nutrition['serving_unit'] ?? 'g'), 1);
    return [
        'id' => (int) $product['id'],
        'code' => (string) $product['code'],
        'name' => (string) $product['name'],
        'category' => (string) $product['category'],
        'brand' => (string) ($product['brand'] ?? ''),
        'presentation' => (string) ($product['presentation'] ?? ''),
        'description' => (string) (($product['description'] ?? '') ?: 'Conoce este producto de Devioz Store.'),
        'price' => (float) $product['price'],
        'regular_price' => 0.0,
        'discount_pct' => 0.0,
        'stock' => (int) $product['stock'],
        'pack_price' => (float) ($product['pack_price'] ?? 0),
        'units_per_pack' => max(1, (int) ($product['units_per_pack'] ?? 1)),
        'image_url' => $image !== '' ? image_src($image) : '',
        'images' => array_map('image_src', array_values($product['images'] ?? [])),
        'icon' => category_icon((string) $product['category']),
        'featured' => (int) ($product['featured'] ?? 0),
        'fast_delivery' => (int) ($product['entrega_inmediata'] ?? 0) === 1,
        'restricted' => (int) ($product['restricted'] ?? 0) === 1,
        'source' => 'local',
        'purchasable' => sale_eligible_product($saleCandidate),
        'store' => 'Devioz Store',
        'nutrition_status' => $nutritionCalc['status'],
        'kcal_serving' => $nutritionCalc['kcal_serving'],
        'nutrition_basis' => $nutritionCalc['basis'],
    ];
}

function storefront_safe_link(?string $value, string $fallback = '#catalogo'): string
{
    $value = trim((string) $value);
    return preg_match('#^(?:https?://|/|#)#i', $value) === 1 ? $value : $fallback;
}

/** @return array{offers:list<array<string,mixed>>,recommended:list<array<string,mixed>>,bestsellers:list<array<string,mixed>>,categories:list<array<string,mixed>>,banners:list<array<string,mixed>>} */
function storefront_sections(PDO $pdo, int $limit = 12): array
{
    $limit = max(1, min(24, $limit));
    $base = storefront_product_scope_sql('p');
    $recommended = $pdo->query(
        'SELECT p.id,p.code,p.name,p.category,p.brand,p.presentation,p.description,p.price,p.active,p.sale_enabled,p.stock,p.min_stock,p.units_per_pack,p.pack_price,p.image_url,p.featured,p.entrega_inmediata,p.restricted,n.applicability AS nutrition_applicability,n.energy_kcal_100g,n.serving_size,n.serving_unit,n.energy_kcal_serving,n.source_type,n.confidence '
        . 'FROM products p LEFT JOIN store_featured_products f ON f.product_id=p.id AND f.active=1 LEFT JOIN product_nutrition n ON n.product_id=p.id WHERE '
        . master_product_visibility_sql('p')
        . ' AND ' . public_product_text_visibility_sql('p')
        . ' ORDER BY (f.product_id IS NOT NULL) DESC,f.position ASC,p.featured DESC,p.updated_at DESC LIMIT ' . $limit
    )->fetchAll();
    $offers = $pdo->query(
        $base . ' AND ' . public_product_text_visibility_sql('p')
        . ' AND (p.featured=1 OR (p.units_per_pack>1 AND p.pack_price>0 AND p.pack_price<(p.price*p.units_per_pack))) '
        . 'ORDER BY p.featured DESC,p.price ASC LIMIT ' . $limit
    )->fetchAll();
    $bestsellers = $pdo->query(
        $base . ' AND ' . public_product_text_visibility_sql('p')
        . " ORDER BY (SELECT COALESCE(SUM(i.quantity),0) FROM yape_order_items i INNER JOIN yape_orders o ON o.id=i.order_id WHERE i.item_type='product' AND i.item_id=p.id AND o.status='aprobado') DESC, p.featured DESC, p.updated_at DESC LIMIT " . $limit
    )->fetchAll();
    $categories = $pdo->query(
        'SELECT p.category,COUNT(*) total FROM products p WHERE ' . master_product_visibility_sql('p')
        . ' AND ' . public_product_text_visibility_sql('p')
        . " AND p.category <> '' GROUP BY p.category ORDER BY total DESC,p.category LIMIT 14"
    )->fetchAll();
    $banners = [];
    try {
        $banners = $pdo->query(
            'SELECT * FROM store_banners WHERE active=1 AND (starts_at IS NULL OR starts_at<=NOW()) '
            . 'AND (ends_at IS NULL OR ends_at>=NOW()) ORDER BY position,id DESC'
        )->fetchAll();
    } catch (PDOException) {
        $banners = [];
    }

    $categoryRows = array_values(array_filter(
        $categories,
        static fn (array $category): bool => !is_age_restricted_product(['name' => '', 'category' => $category['category'] ?? ''])
    ));

    return [
        'offers' => storefront_exclude_age_restricted(attach_product_images($offers)),
        'recommended' => storefront_exclude_age_restricted(attach_product_images($recommended)),
        'bestsellers' => storefront_exclude_age_restricted(attach_product_images($bestsellers)),
        'categories' => $categoryRows,
        'banners' => $banners,
    ];
}
