<?php
declare(strict_types=1);

require_once __DIR__ . '/master_catalog.php';

const RECOMMENDATION_MAX_QUANTITY = 99;
const RECOMMENDATION_MAX_TOTAL_QUANTITY = 99;
const RECOMMENDATION_MAX_LINES = 12;

function recommendation_request(array $input): array
{
    $budget=is_numeric($input['budget']??null)?max(0.0,min(10000.0,(float)$input['budget'])):null;
    return ['query'=>mb_substr(trim((string)($input['query']??'')),0,240),'budget'=>$budget,'category'=>mb_substr(trim((string)($input['category']??'')),0,80),'limit'=>max(1,min(12,(int)($input['limit']??6)))];
}

function ai_normalize(string $value): string
{
    $value=mb_strtolower($value,'UTF-8');
    return strtr($value,['á'=>'a','é'=>'e','í'=>'i','ó'=>'o','ú'=>'u','ü'=>'u','ñ'=>'n']);
}

function is_age_restricted_product(array $product): bool
{
    $text=ai_normalize(implode(' ',[(string)($product['name']??''),(string)($product['category']??''),(string)($product['description']??'')]));
    return preg_match('/\b(cerveza(?:s)?|vino(?:s)?|licor(?:es)?|alcohol(?:ica|ico|icas|icos)?|whisk(?:y|ey)|vodka|ron|pisco|tequila|ginebra|gin|brandy|champagne|sidra|espumante|tabaco|cigarro|nicotina|vapeador|cannabis|marihuana)\b|bebida\s+energizante|energy\s+drink/u',$text)===1;
}

/**
 * Conservative SQL companion to is_age_restricted_product(). Public queries
 * use it before COUNT/LIMIT; the PHP predicate remains a second defense.
 *
 * @param list<string> $expressions trusted SQL column expressions
 */
function public_text_visibility_sql(array $expressions): string
{
    $text = "LOWER(CONCAT_WS(' ', " . implode(', ', $expressions) . '))';
    $restricted = '(^|[^[:alnum:]])(cervezas?|vinos?|licor(es)?|alcohol(ica|ico|icas|icos)?|whisk(y|ey)|vodka|ron|pisco|tequila|ginebra|gin|brandy|champagne|sidra|espumante|tabaco|cigarro|nicotina|vapeador|cannabis|marihuana)([^[:alnum:]]|$)|bebida[[:space:]]+energizante|energy[[:space:]]+drink';
    return $text . " NOT REGEXP '" . $restricted . "'";
}

function public_product_text_visibility_sql(string $alias = 'p'): string
{
    return public_text_visibility_sql([
        "COALESCE($alias.name, '')",
        "COALESCE($alias.category, '')",
        "COALESCE($alias.description, '')",
    ]);
}

function public_combo_text_visibility_sql(string $alias = 'c'): string
{
    return public_text_visibility_sql([
        "COALESCE($alias.name, '')",
        "COALESCE($alias.description, '')",
    ]);
}

function recommendation_candidate_is_sellable(array $product): bool
{
    return ($product['catalog_scope'] ?? 'master') === 'master'
        && sale_eligible_product($product)
        && !is_age_restricted_product($product);
}

function recommendation_money_cents(mixed $value): int
{
    return is_numeric($value) ? max(0, (int)round((float)$value * 100)) : 0;
}

/** @return list<array{id:int,qty:int,price_cents:int}> */
function recommendation_confirmation_items(mixed $items): array
{
    if (!is_array($items)) return [];
    $normalized = [];
    foreach ($items as $item) {
        if (!is_array($item)) return [];
        $id = $item['id'] ?? null;
        $quantity = $item['qty'] ?? ($item['quantity'] ?? null);
        $price = $item['price'] ?? null;
        if (!is_int($id) || $id < 1 || !is_int($quantity) || $quantity < 1 || $quantity > RECOMMENDATION_MAX_QUANTITY) {
            return [];
        }
        if ($price === null && isset($item['unit_cents']) && is_numeric($item['unit_cents'])) {
            $price = (float)$item['unit_cents'] / 100;
        }
        $priceCents = recommendation_money_cents($price);
        if ($priceCents < 1 || isset($normalized[$id])) return [];
        $normalized[$id] = ['id' => $id, 'qty' => $quantity, 'price_cents' => $priceCents];
    }
    return array_values($normalized);
}

/** @return list<array{id:int,qty:int}> */
function recommendation_reconciled_items(mixed $items): array
{
    if (!is_array($items)) return [];
    $normalized = [];
    foreach ($items as $item) {
        if (!is_array($item)) return [];
        $id = $item['id'] ?? null;
        $quantity = $item['quantity'] ?? ($item['qty'] ?? null);
        $type = (string)($item['type'] ?? 'product');
        if ($type !== 'product' || !is_int($id) || $id < 1 || !is_int($quantity) || $quantity < 1 || $quantity > RECOMMENDATION_MAX_QUANTITY || isset($normalized[$id])) return [];
        $normalized[$id] = ['id' => $id, 'qty' => $quantity];
    }
    return array_values($normalized);
}

function recommendation_confirmation_digest(array $items): string
{
    if (!isset($_SESSION['ai_recommendation_confirmation_secret']) || !is_string($_SESSION['ai_recommendation_confirmation_secret'])) {
        $_SESSION['ai_recommendation_confirmation_secret'] = bin2hex(random_bytes(32));
    }
    return hash_hmac('sha256', (string)json_encode($items, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES), $_SESSION['ai_recommendation_confirmation_secret']);
}

function rule_based_recommendations(array $candidates,array $request): array
{
    $budget=$request['budget']??null;
    $budgetCents=$budget===null?null:recommendation_money_cents($budget);
    $category=ai_normalize((string)($request['category']??''));
    $query=ai_normalize((string)($request['query']??''));
    $limit=max(1,min(12,(int)($request['limit']??6)));
    $rows=array_values(array_filter($candidates,static function(array $product)use($budgetCents,$category):bool{
        $priceCents=recommendation_money_cents($product['price']??null);
        return recommendation_candidate_is_sellable($product)
            && ($budgetCents===null||$priceCents<=$budgetCents)
            && ($category===''||str_contains(ai_normalize((string)($product['category']??'')),$category));
    }));
    usort($rows,static function(array $a,array $b)use($query):int{
        $aText=ai_normalize(($a['name']??'').' '.($a['category']??''));
        $bText=ai_normalize(($b['name']??'').' '.($b['category']??''));
        $aScore=$query!==''&&str_contains($aText,$query)?1:0;
        $bScore=$query!==''&&str_contains($bText,$query)?1:0;
        return $bScore<=>$aScore ?: recommendation_money_cents($a['price'])<=>recommendation_money_cents($b['price']) ?: (int)$a['id']<=>(int)$b['id'];
    });
    if($budgetCents===null) return array_slice($rows,0,$limit);
    $selected=[];$remaining=$budgetCents;
    foreach($rows as $row){
        $priceCents=recommendation_money_cents($row['price']);
        if($priceCents<=$remaining){$selected[]=$row;$remaining-=$priceCents;if(count($selected)>=$limit)break;}
    }
    return $selected;
}

function validate_model_recommendations(array $modelOutput,array $candidateMap,?float $budget,int $limit=12,int $maxTotalQuantity=RECOMMENDATION_MAX_TOTAL_QUANTITY): array
{
    $valid=[];$used=[];$remaining=$budget===null?null:recommendation_money_cents($budget);
    $limit=max(1,min(RECOMMENDATION_MAX_LINES,$limit));
    $maxTotalQuantity=max(1,min(100,$maxTotalQuantity));
    $totalQuantity=0;
    foreach($modelOutput as $row){
        if(!is_array($row)||!is_int($row['id']??null)||!is_int($row['qty']??null)||$row['id']<1||$row['qty']<1)continue;
        $id=$row['id'];
        if(!isset($candidateMap[$id])||!is_array($candidateMap[$id]))continue;
        $product=$candidateMap[$id];
        if(!recommendation_candidate_is_sellable($product))continue;
        if(!isset($valid[$id])&&count($valid)>=$limit)continue;
        $priceCents=recommendation_money_cents($product['price']??null);
        $available=max(0,(int)$product['stock']-(int)($used[$id]??0));
        if($priceCents<1||$available<1)continue;
        $qty=min($available,$row['qty'],RECOMMENDATION_MAX_QUANTITY,$maxTotalQuantity-$totalQuantity);
        if($remaining!==null)$qty=min($qty,intdiv($remaining,$priceCents));
        if($qty<1) continue;
        $used[$id]=($used[$id]??0)+$qty;
        $valid[$id]=['id'=>$id,'qty'=>$used[$id]];
        $totalQuantity+=$qty;
        if($remaining!==null)$remaining-=$priceCents*$qty;
    }
    return array_values($valid);
}

function recommendation_candidates(PDO $pdo,array $request): array
{
    $where=[master_product_visibility_sql('p'),public_product_text_visibility_sql('p')]; $params=[];
    if($request['category']!==''){$where[]='p.category=:category';$params['category']=$request['category'];}
    if($request['budget']!==null){$where[]='p.price<=:budget';$params['budget']=$request['budget'];}
    $sql='SELECT p.id,p.code,p.name,p.category,p.description,p.price,p.stock,p.image_url,p.entrega_inmediata,'
        .'p.catalog_scope,p.active,p.sale_enabled,p.restricted FROM products p WHERE '.implode(' AND ',$where)
        .' ORDER BY p.featured DESC,p.price ASC,p.id ASC LIMIT 60';
    $statement=$pdo->prepare($sql);$statement->execute($params);
    return array_values(array_filter($statement->fetchAll(),static fn(array $product):bool=>sale_eligible_product($product)&&!is_age_restricted_product($product)));
}

/** @param list<int> $ids */
function recommendation_candidates_for_ids(PDO $pdo,array $request,array $ids): array
{
    $ids=array_values(array_unique(array_filter($ids,static fn($id):bool=>is_int($id)&&$id>0)));
    if($ids===[])return [];
    $ids=array_slice($ids,0,RECOMMENDATION_MAX_LINES);
    $where=[master_product_visibility_sql('p'),public_product_text_visibility_sql('p')];$params=[];$placeholders=[];
    foreach($ids as $index=>$id){$key='id'.$index;$placeholders[]=':'.$key;$params[$key]=$id;}
    $where[]='p.id IN ('.implode(',',$placeholders).')';
    if(($request['category']??'')!==''){$where[]='p.category=:category';$params['category']=$request['category'];}
    if(($request['budget']??null)!==null){$where[]='p.price<=:budget';$params['budget']=$request['budget'];}
    $sql='SELECT p.id,p.code,p.name,p.category,p.description,p.price,p.stock,p.image_url,p.entrega_inmediata,'
        .'p.catalog_scope,p.active,p.sale_enabled,p.restricted FROM products p WHERE '.implode(' AND ',$where)
        .' ORDER BY p.featured DESC,p.price ASC,p.id ASC LIMIT 60';
    $statement=$pdo->prepare($sql);$statement->execute($params);
    return array_values(array_filter($statement->fetchAll(),static fn(array $product):bool=>sale_eligible_product($product)&&!is_age_restricted_product($product)));
}

function recommendation_prompt_catalog(array $candidates): array
{
    return array_map(static fn(array $product):array=>[
        'id'=>(int)$product['id'],
        'name'=>(string)$product['name'],
        'category'=>(string)$product['category'],
        'price'=>(float)$product['price'],
        'stock'=>(int)$product['stock'],
    ],$candidates);
}

function ollama_recommendations(array $candidates,array $request,array $config): ?array
{
    if(!function_exists('curl_init')||($config['provider']??'')!=='ollama'||($config['model']??'')==='') return null;
    $base=rtrim((string)($config['ollama_url']??'http://127.0.0.1:11434'),'/');
    if(!in_array($base,['http://127.0.0.1:11434','http://localhost:11434'],true)) return null;
    $catalog=recommendation_prompt_catalog($candidates);
    $body=['model'=>$config['model'],'stream'=>false,'format'=>'json','think'=>false,'options'=>['temperature'=>0,'num_predict'=>500,'num_ctx'=>4096],'messages'=>[
        ['role'=>'system','content'=>'Elige solo IDs del catálogo. Excluye productos restringidos por edad. Respeta presupuesto y stock. Devuelve JSON {"items":[{"id":1,"qty":1}]} sin texto adicional.'],
        ['role'=>'user','content'=>json_encode(['request'=>$request,'catalog'=>$catalog],JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES)],
    ]];
    $raw='';$ch=curl_init($base.'/api/chat');
    curl_setopt_array($ch,[CURLOPT_POST=>true,CURLOPT_HTTPHEADER=>['Content-Type: application/json'],CURLOPT_POSTFIELDS=>json_encode($body,JSON_UNESCAPED_UNICODE|JSON_UNESCAPED_SLASHES),CURLOPT_CONNECTTIMEOUT=>4,CURLOPT_TIMEOUT=>12,CURLOPT_FOLLOWLOCATION=>false,CURLOPT_WRITEFUNCTION=>static function($ch,$chunk)use(&$raw){if(strlen($raw)+strlen($chunk)>131072)return 0;$raw.=$chunk;return strlen($chunk);}]);
    $ok=curl_exec($ch);$status=(int)curl_getinfo($ch,CURLINFO_HTTP_CODE);curl_close($ch);
    if($ok===false||$status!==200)return null;
    $outer=json_decode($raw,true);$answer=json_decode((string)($outer['message']['content']??''),true);
    if(!is_array($answer)||!is_array($answer['items']??null)||count($answer['items'])>60)return null;
    if($answer['items']!==[]&&array_keys($answer['items'])!==range(0,count($answer['items'])-1))return null;
    $map=[];foreach($candidates as $candidate)$map[(int)$candidate['id']]=$candidate;
    $validated=validate_model_recommendations($answer['items'],$map,$request['budget'],(int)($request['limit']??6));
    return $answer['items']!==[]&&$validated===[]?null:$validated;
}

function recommendation_payload(array $candidates,array $selections,?float $budget=null,int $limit=12): array
{
    $map=[];foreach($candidates as $candidate)$map[(int)$candidate['id']]=$candidate;
    $selections=validate_model_recommendations($selections,$map,$budget,$limit);
    $items=[];$total=0.0;
    foreach($selections as $selection){
        if(!is_array($selection)||!is_int($selection['id']??null)||!is_int($selection['qty']??null))continue;
        $id=$selection['id'];$qty=$selection['qty'];
        if(!isset($map[$id])||!recommendation_candidate_is_sellable($map[$id])||!sale_eligible_product($map[$id],$qty))continue;
        $product=$map[$id];$subtotal=round((float)$product['price']*$qty,2);$total+=$subtotal;
        $items[]=['id'=>$id,'code'=>$product['code'],'name'=>$product['name'],'category'=>$product['category'],'price'=>(float)$product['price'],'stock'=>(int)$product['stock'],'image_url'=>$product['image_url']??'','quantity'=>$qty,'subtotal'=>$subtotal];
    }
    return ['items'=>$items,'total'=>round($total,2)];
}

function recommendation_confirmation_create(array $items,array $request=[]): ?string
{
    $canonical=recommendation_confirmation_items($items);
    if($canonical===[]||count($canonical)>RECOMMENDATION_MAX_LINES)return null;
    $now=time();$stored=$_SESSION['ai_recommendation_confirmations']??[];
    if(!is_array($stored))$stored=[];
    $stored=array_filter($stored,static fn($entry):bool=>is_array($entry)&&(int)($entry['expires']??0)>=$now);
    while(count($stored)>=10)array_shift($stored);
    $token=bin2hex(random_bytes(24));
    $stored[$token]=[
        'expires'=>$now+600,
        'digest'=>recommendation_confirmation_digest($canonical),
        'items'=>$canonical,
        'request'=>[
            'budget'=>isset($request['budget'])&&is_numeric($request['budget'])?(float)$request['budget']:null,
            'category'=>mb_substr(trim((string)($request['category']??'')),0,80),
            'line_limit'=>max(1,min(RECOMMENDATION_MAX_LINES,(int)($request['line_limit']??$request['limit']??count($canonical)))),
            'quantity_limit'=>max(1,min(RECOMMENDATION_MAX_QUANTITY,(int)($request['quantity_limit']??RECOMMENDATION_MAX_QUANTITY))),
            'total_quantity_limit'=>max(1,min(100,(int)($request['total_quantity_limit']??RECOMMENDATION_MAX_TOTAL_QUANTITY))),
        ],
    ];
    $_SESSION['ai_recommendation_confirmations']=$stored;
    return $token;
}

function recommendation_confirmation_record(string $token): ?array
{
    if(!preg_match('/^[a-f0-9]{48}$/D',$token))return null;
    $stored=$_SESSION['ai_recommendation_confirmations']??[];
    if(!is_array($stored)||!isset($stored[$token])||!is_array($stored[$token]))return null;
    return (int)($stored[$token]['expires']??0)>=time()?$stored[$token]:null;
}

function recommendation_confirmation_matches(string $token,mixed $items): bool
{
    $record=recommendation_confirmation_record($token);
    $canonical=recommendation_confirmation_items($items);
    return $record!==null&&$canonical!==[]&&hash_equals((string)($record['digest']??''),recommendation_confirmation_digest($canonical));
}

function recommendation_confirmation_consume(string $token,?array $items=null): bool
{
    if(!is_array($items)||!recommendation_confirmation_matches($token,$items))return false;
    $stored=$_SESSION['ai_recommendation_confirmations']??[];
    if(!is_array($stored)||!isset($stored[$token]))return false;
    unset($stored[$token]);
    $_SESSION['ai_recommendation_confirmations']=$stored;
    return true;
}
