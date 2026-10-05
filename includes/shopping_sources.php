<?php
declare(strict_types=1);

require_once __DIR__ . '/master_catalog.php';
require_once __DIR__ . '/ai_recommendations.php';

function shopping_categories(): array {
    return ['Abarrotes','Bebidas','Bebes','Carnes, Aves y Pescados','Comidas y Rostizados','Confiteria','Confitería','Congelados',
        'Cuidado del bebe','Desayuno','Desayunos','Dulces y chicles','Embutidos y Fiambres','Frutas','Frutas y Verduras',
        'Frutas y verduras','Galletas','Higiene Salud y Belleza','Lacteos','Lácteos','Lacteos y Huevos','Lácteos y Huevos',
        'Limpieza','Mascotas','Panaderia y Pasteleria','Panadería y Pastelería','Quesos y Fiambres','Snacks','Verduras'];
}
function shopping_food_safe(string $name, string $category): bool {
    if (!in_array($category, shopping_categories(), true)) return false;
    if (preg_match('/alcohol|cerveza|vino|vodka|whisk|pisco|ron\b|licor|cigar|tabaco|nicotin|vape|cannabis|energizante|energy|volt|red bull|monster/iu',$name)) return false;
    return true;
}
function shopping_sources_ready(PDO $pdo): bool {
    try { $pdo->query('SELECT id FROM shopping_sources LIMIT 1'); $pdo->query('SELECT id FROM shopping_offers LIMIT 1'); return true; }
    catch (PDOException $e) { return false; }
}
function shopping_load_catalog(PDO $pdo, int $source, string $category, array $config, string $request = ''): array {
    if ($source !== 0) {
        throw new InvalidArgumentException('El asistente público solo consulta el catálogo Devioz disponible.');
    }
    $terms = preg_split('/[^\pL\pN]+/u', mb_strtolower($request), -1, PREG_SPLIT_NO_EMPTY) ?: [];
    $ignored = ['conversación','orden','petición','reciente','modifica','anteriores','tengo','quiero','comprar','deseo','para','soles','presupuesto','recomiéndame','recomienda','una','unos','unas','del','las','los','que','por','favor','ahora','también'];
    $terms = array_values(array_unique(array_filter($terms, static fn(string $term): bool => mb_strlen($term) >= 3 && !in_array($term, $ignored, true) && !ctype_digit($term))));
    $sql = 'SELECT p.id,p.code,p.name,p.category,p.description,p.price,p.stock,p.image_url,'
        . 'p.catalog_scope,p.active,p.sale_enabled,p.restricted FROM products p WHERE '
        . master_product_visibility_sql('p') . ' AND ' . public_product_text_visibility_sql('p');
    $args = [];
    if ($category !== '') { $sql .= ' AND p.category=?'; $args[]=$category; }
    if ($terms) {
        $matches = [];
        foreach (array_slice($terms, -4) as $term) {
            $matches[] = '(LOWER(p.name) LIKE ? OR LOWER(p.category) LIKE ? OR LOWER(p.description) LIKE ?)';
            array_push($args, '%' . $term . '%', '%' . $term . '%', '%' . $term . '%');
        }
        $sql .= ' AND (' . implode(' OR ', $matches) . ')';
    }
    $sql .= ' ORDER BY p.featured DESC,p.price,p.id LIMIT 60';
    $statement = $pdo->prepare($sql);
    $statement->execute($args);
    return array_values(array_filter(
        $statement->fetchAll(),
        static fn(array $product): bool => shopping_food_safe((string)$product['name'], (string)$product['category'])
            && !is_age_restricted_product($product)
            && recommendation_candidate_is_sellable($product)
    ));
}

/** @param list<int> $ids */
function shopping_load_catalog_by_ids(PDO $pdo, array $ids, string $category = '', ?int $budgetCents = null): array {
    $ids = array_values(array_unique(array_filter($ids, static fn($id): bool => is_int($id) && $id > 0)));
    if (!$ids) return [];
    $ids = array_slice($ids, 0, 60);
    $placeholders = [];
    $args = [];
    foreach ($ids as $id) { $placeholders[] = '?'; $args[] = $id; }
    $sql = 'SELECT p.id,p.code,p.name,p.category,p.description,p.price,p.stock,p.image_url,'
        . 'p.catalog_scope,p.active,p.sale_enabled,p.restricted FROM products p WHERE '
        . master_product_visibility_sql('p') . ' AND ' . public_product_text_visibility_sql('p')
        . ' AND p.id IN (' . implode(',', $placeholders) . ')';
    if ($category !== '') { $sql .= ' AND p.category=?'; $args[] = $category; }
    if ($budgetCents !== null) { $sql .= ' AND p.price<=?'; $args[] = $budgetCents / 100; }
    $sql .= ' ORDER BY p.featured DESC,p.price,p.id LIMIT 60';
    $statement = $pdo->prepare($sql);
    $statement->execute($args);
    return array_values(array_filter($statement->fetchAll(), static fn(array $product): bool => shopping_food_safe((string)$product['name'], (string)$product['category']) && !is_age_restricted_product($product) && recommendation_candidate_is_sellable($product)));
}
function shopping_validate_import(string $json): array {
    if (strlen($json)>2000000) throw new InvalidArgumentException('El archivo supera 2 MB.');
    try { $rows=json_decode($json,true,32,JSON_THROW_ON_ERROR); }
    catch (JsonException $e) { throw new InvalidArgumentException('El archivo no contiene JSON válido.'); }
    if (!is_array($rows) || !$rows || array_keys($rows)!==range(0,count($rows)-1) || count($rows)>1000) throw new InvalidArgumentException('Envía una lista JSON de 1 a 1000 ofertas.');
    $clean=[]; $seen=[];
    foreach ($rows as $i=>$r) {
        $err='Fila '.($i+1).': ';
        if (!is_array($r)) throw new InvalidArgumentException($err.'oferta inválida.');
        foreach (['external_id'=>100,'name'=>180,'category'=>80,'presentation'=>100,'verified_at'=>20] as $k=>$max) {
            if (!isset($r[$k]) || !is_string($r[$k]) || trim($r[$k])==='' || mb_strlen($r[$k])>$max) throw new InvalidArgumentException($err.'revisa '.$k.'.');
            $r[$k]=trim($r[$k]);
        }
        if (!preg_match('/^[A-Za-z0-9._-]+$/D',$r['external_id']) || isset($seen[strtolower($r['external_id'])])) throw new InvalidArgumentException($err.'ID inválido o duplicado.');
        $seen[strtolower($r['external_id'])]=true;
        if (!shopping_food_safe($r['name'],$r['category'])) throw new InvalidArgumentException($err.'producto o categoría fuera del catálogo permitido.');
        if (!isset($r['price']) || !is_string($r['price'])) throw new InvalidArgumentException($err.'price debe ser texto decimal, por ejemplo "3.50".');
        $price=shopping_cents($r['price']);
        $stock=$r['stock'] ?? null;
        if ($stock!==null && (!is_int($stock) || $stock<0 || $stock>1000000)) throw new InvalidArgumentException($err.'stock debe ser entero o null.');
        if (!isset($r['available']) || !is_bool($r['available'])) throw new InvalidArgumentException($err.'available debe ser true o false.');
        $date=DateTimeImmutable::createFromFormat('!Y-m-d\TH:i:s\Z',$r['verified_at'],new DateTimeZone('UTC'));
        if (!$date || $date->format('Y-m-d\TH:i:s\Z')!==$r['verified_at'] || $date->getTimestamp()>time()) throw new InvalidArgumentException($err.'verified_at debe ser una fecha real UTC, no futura.');
        $gtin=$r['gtin'] ?? null;
        if ($gtin!==null && (!is_string($gtin) || !preg_match('/^(?:\d{8}|\d{12}|\d{13}|\d{14})$/D',$gtin))) throw new InvalidArgumentException($err.'GTIN inválido.');
        $brand=isset($r['brand'])&&is_string($r['brand'])?mb_substr(trim($r['brand']),0,150):'';
        $supermarket=isset($r['supermarket'])&&is_string($r['supermarket'])?mb_substr(trim($r['supermarket']),0,100):'';
        $regularPrice=null;
        if(isset($r['regular_price'])&&$r['regular_price']!==''){
            if(!is_string($r['regular_price']))throw new InvalidArgumentException($err.'regular_price debe ser texto decimal.');
            $regularPrice=number_format(shopping_cents($r['regular_price'])/100,2,'.','');
        }
        $discountPct=isset($r['discount_pct'])&&is_numeric($r['discount_pct'])?max(0,min(100,round((float)$r['discount_pct'],2))):0;
        if($discountPct<=0&&$regularPrice!==null&&(float)$regularPrice>$price/100)$discountPct=round(((float)$regularPrice-$price/100)*100/(float)$regularPrice,2);
        $productUrl=isset($r['product_url'])&&is_string($r['product_url'])?trim($r['product_url']):'';
        $imageUrl=isset($r['image_url'])&&is_string($r['image_url'])?trim($r['image_url']):'';
        foreach(['product_url'=>$productUrl,'image_url'=>$imageUrl] as $field=>$value)if($value!==''&&(strlen($value)>2000||!preg_match('#^https?://#i',$value)))throw new InvalidArgumentException($err.$field.' debe ser una URL HTTP(S).');
        $clean[]=['external_id'=>$r['external_id'],'gtin'=>$gtin,'name'=>$r['name'],'brand'=>$brand?:null,'category'=>$r['category'],'presentation'=>$r['presentation'],
            'price'=>number_format($price/100,2,'.',''),'regular_price'=>$regularPrice,'discount_pct'=>$discountPct,'product_url'=>$productUrl?:null,'image_url'=>$imageUrl?:null,'supermarket'=>$supermarket?:null,
            'stock'=>$stock,'available'=>(int)$r['available'],'verified_at'=>$date->format('Y-m-d H:i:s')];
    }
    return $clean;
}
function shopping_import(PDO $pdo,int $source,array $rows): int {
    $pdo->beginTransaction();
    try {
        $check=$pdo->prepare('SELECT id FROM shopping_sources WHERE id=? AND active=1 FOR UPDATE'); $check->execute([$source]);
        if (!$check->fetchColumn()) throw new InvalidArgumentException('Selecciona una fuente activa.');
        $st=$pdo->prepare('INSERT INTO shopping_offers (source_id,external_id,gtin,name,brand,category,presentation,price,regular_price,discount_pct,product_url,image_url,supermarket,stock,available,verified_at)
            VALUES (:source_id,:external_id,:gtin,:name,:brand,:category,:presentation,:price,:regular_price,:discount_pct,:product_url,:image_url,:supermarket,:stock,:available,:verified_at)
            ON DUPLICATE KEY UPDATE gtin=VALUES(gtin),name=VALUES(name),brand=VALUES(brand),category=VALUES(category),presentation=VALUES(presentation),price=VALUES(price),regular_price=VALUES(regular_price),discount_pct=VALUES(discount_pct),product_url=VALUES(product_url),image_url=VALUES(image_url),supermarket=VALUES(supermarket),stock=VALUES(stock),available=VALUES(available),verified_at=VALUES(verified_at)');
        $existing=$pdo->prepare('SELECT verified_at FROM shopping_offers WHERE source_id=? AND external_id=?');
        foreach ($rows as $r) {
            $existing->execute([$source,$r['external_id']]); $old=$existing->fetchColumn();
            if ($old && $old>$r['verified_at']) throw new InvalidArgumentException('La carga contiene datos más antiguos que los guardados. No se importó ninguna fila.');
            $st->execute(array_merge(['source_id'=>$source],$r));
        }
        $pdo->commit();return count($rows);
    } catch(Throwable $e) { if($pdo->inTransaction())$pdo->rollBack();throw $e; }
}
