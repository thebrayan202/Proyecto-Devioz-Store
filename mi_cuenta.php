<?php
declare(strict_types=1);
require_once __DIR__.'/includes/functions.php';
require_once __DIR__.'/includes/master_catalog.php';
require_once __DIR__.'/includes/ai_recommendations.php';
$pageTitle='Mi cuenta';$error='';$authAction=(string)($_POST['action']??'login');

if($_SERVER['REQUEST_METHOD']==='POST'){
    verify_csrf();$action=(string)($_POST['action']??'');
    try{
        if($action==='register'){
            $name=mb_substr(trim((string)($_POST['name']??'')),0,120);$email=mb_strtolower(trim((string)($_POST['email']??'')));$phone=preg_replace('/[^0-9+]/','',(string)($_POST['phone']??''));$password=(string)($_POST['password']??'');
            if(mb_strlen($name)<3||mb_strlen($name)>120)throw new RuntimeException('Escribe tu nombre completo (mínimo 3 caracteres).');
            if(!filter_var($email,FILTER_VALIDATE_EMAIL)||strlen($email)>190)throw new RuntimeException('Escribe un correo válido.');
            if($phone!==''&&(strlen(preg_replace('/\D/','',$phone))<7||strlen(preg_replace('/\D/','',$phone))>15))throw new RuntimeException('El celular debe tener entre 7 y 15 dígitos.');
            if(strlen($password)<8||strlen($password)>72)throw new RuntimeException('La contraseña debe tener entre 8 y 72 caracteres.');
            if(!hash_equals($password,(string)($_POST['password_confirm']??'')))throw new RuntimeException('Las contraseñas no coinciden.');
            $statement=db()->prepare('INSERT INTO customers(name,email,phone,password) VALUES(?,?,?,?)');$statement->execute([$name,$email,mb_substr($phone,0,20),password_hash($password,PASSWORD_DEFAULT)]);
            $_SESSION['customer_id']=(int)db()->lastInsertId();$_SESSION['customer_name']=$name;session_regenerate_id(true);flash('success','Tu cuenta fue creada.');redirect('mi_cuenta.php');
        }
        if($action==='login'){
            $email=mb_strtolower(trim((string)($_POST['email']??'')));$password=(string)($_POST['password']??'');
            $statement=db()->prepare('SELECT id,name,password FROM customers WHERE email=? AND active=1 LIMIT 1');$statement->execute([$email]);$customer=$statement->fetch();
            if(!$customer||!password_verify($password,(string)$customer['password']))throw new RuntimeException('El correo o la contraseña no son correctos.');
            if(password_needs_rehash((string)$customer['password'],PASSWORD_DEFAULT))db()->prepare('UPDATE customers SET password=? WHERE id=?')->execute([password_hash($password,PASSWORD_DEFAULT),(int)$customer['id']]);
            $_SESSION['customer_id']=(int)$customer['id'];$_SESSION['customer_name']=(string)$customer['name'];session_regenerate_id(true);flash('success','Sesión iniciada correctamente.');redirect('mi_cuenta.php');
        }
        require_customer();
        if($action==='address_add'){
            $label=mb_substr(trim((string)($_POST['label']??'Casa')),0,60);$district=mb_substr(trim((string)($_POST['district']??'')),0,100);$address=mb_substr(trim((string)($_POST['address']??'')),0,255);$reference=mb_substr(trim((string)($_POST['reference']??'')),0,255);
            if($district===''||mb_strlen($address)<5)throw new RuntimeException('Completa el distrito y la dirección.');
            $statement=db()->prepare('INSERT INTO customer_addresses(customer_id,label,district,address,reference,is_default) VALUES(?,?,?,?,?,?)');$statement->execute([customer_id(),$label?:'Casa',$district,$address,$reference,(int)($_POST['is_default']??0)]);flash('success','Dirección guardada.');redirect('mi_cuenta.php');
        }
        if($action==='address_delete'){
            db()->prepare('DELETE FROM customer_addresses WHERE id=? AND customer_id=?')->execute([(int)($_POST['id']??0),customer_id()]);flash('success','Dirección eliminada.');redirect('mi_cuenta.php');
        }
    }catch(PDOException $exception){$error=$exception->getCode()==='23000'?'Ese correo ya está registrado.':'No se pudo guardar la información.';}
    catch(RuntimeException $exception){$error=$exception->getMessage();}
}

$flashMessage=pull_flash();$profile=customer_profile();$addresses=[];$orders=[];$favoriteOffers=[];$favoriteProducts=[];
$authView=$authAction==='register'||($_SERVER['REQUEST_METHOD']!=='POST'&&($_GET['view']??'')==='register')?'register':'login';
if($profile){
    $statement=db()->prepare('SELECT * FROM customer_addresses WHERE customer_id=? ORDER BY is_default DESC,id DESC');$statement->execute([customer_id()]);$addresses=$statement->fetchAll();
    $statement=db()->prepare('SELECT id,order_code,expected_amount,status,fulfillment_status,created_at FROM yape_orders WHERE customer_id=? ORDER BY id DESC LIMIT 20');$statement->execute([customer_id()]);$orders=$statement->fetchAll();
    $statement=db()->prepare("SELECT p.id,p.name,p.category,p.description,p.price,p.image_url FROM customer_favorites f INNER JOIN products p ON p.id=f.item_id WHERE f.customer_id=? AND f.item_type='product' AND ".master_product_visibility_sql('p').' AND '.public_product_text_visibility_sql('p')." ORDER BY f.id DESC");$statement->execute([customer_id()]);$favoriteProducts=array_values(array_filter($statement->fetchAll(),static fn(array $product):bool=>!is_age_restricted_product($product)));
}
require __DIR__.'/includes/public_header.php';
?>
<?php if($profile): ?><section class="suite-hero"><div class="container"><span>CLIENTES DEVIOZ</span><h1>Hola, <?= e($profile['name']) ?></h1><p>Guarda favoritos y direcciones, y revisa tus pedidos desde un solo lugar.</p></div></section><?php endif; ?>
<section class="suite-section"><div class="container">
<?php if($flashMessage): ?><div class="alert alert-<?= e($flashMessage['type']) ?>"><?= e($flashMessage['message']) ?></div><?php endif ?>
<?php if($error): ?><div class="alert alert-danger"><?= e($error) ?></div><?php endif ?>
<?php if(!$profile): ?>
<div class="account-access">
  <nav class="account-access-tabs" aria-label="Acceso a tu cuenta">
    <a href="<?= url('mi_cuenta.php?view=login') ?>" class="<?= $authView==='login'?'is-current':'' ?>" <?= $authView==='login'?'aria-current="page"':'' ?>>Iniciar sesión</a>
    <a href="<?= url('mi_cuenta.php?view=register') ?>" class="<?= $authView==='register'?'is-current':'' ?>" <?= $authView==='register'?'aria-current="page"':'' ?>>Crear cuenta</a>
  </nav>
  <div class="account-access-layout">
    <div class="account-access-intro"><span>DEVIOZ STORE</span><h1><?= $authView==='register'?'Crea tu cuenta':'Qué bueno verte de nuevo' ?></h1><p><?= $authView==='register'?'Guarda tus datos y consulta tus pedidos en un solo lugar.':'Ingresa para revisar tus pedidos, direcciones y favoritos.' ?></p><div class="account-access-benefits"><span>✓ Tus pedidos en un solo lugar</span><span>✓ Direcciones guardadas</span><span>✓ Favoritos a mano</span></div></div>
    <?php if($authView==='login'): ?>
    <form class="suite-card account-access-form" method="post" action="<?= url('mi_cuenta.php?view=login') ?>" id="ingresar"><span class="account-access-eyebrow">MI CUENTA</span><h2>Iniciar sesión</h2><p>Escribe los datos de tu cuenta.</p><?= csrf_field() ?><input type="hidden" name="action" value="login"><label>Correo electrónico<input type="email" name="email" maxlength="190" value="<?= e($authAction==='login'?(string)($_POST['email']??''):'') ?>" placeholder="nombre@correo.com" required autocomplete="email"></label><label>Contraseña<input type="password" name="password" required autocomplete="current-password" data-password-field></label><label class="check-line"><input type="checkbox" data-show-password> Mostrar contraseña</label><button class="btn btn-primary" type="submit">Ingresar a mi cuenta</button><p class="account-access-switch">¿Aún no tienes cuenta? <a href="<?= url('mi_cuenta.php?view=register') ?>">Crear cuenta</a></p></form>
    <?php else: ?>
    <form class="suite-card account-access-form" method="post" action="<?= url('mi_cuenta.php?view=register') ?>" id="crear-cuenta"><span class="account-access-eyebrow">EMPIEZA AQUÍ</span><h2>Crear cuenta</h2><p>Completa tus datos para registrarte.</p><?= csrf_field() ?><input type="hidden" name="action" value="register"><label>Nombre completo<input name="name" maxlength="120" minlength="3" value="<?= e($authAction==='register'?(string)($_POST['name']??''):'') ?>" required autocomplete="name"></label><label>Correo electrónico<input type="email" name="email" maxlength="190" value="<?= e($authAction==='register'?(string)($_POST['email']??''):'') ?>" placeholder="nombre@correo.com" required autocomplete="email"></label><label>Celular (opcional)<input name="phone" maxlength="20" inputmode="tel" autocomplete="tel" value="<?= e($authAction==='register'?(string)($_POST['phone']??''):'') ?>"></label><label>Contraseña<input type="password" name="password" minlength="8" maxlength="72" required autocomplete="new-password" data-password-field><small>Usa entre 8 y 72 caracteres.</small></label><label>Confirmar contraseña<input type="password" name="password_confirm" minlength="8" maxlength="72" required autocomplete="new-password" data-password-field></label><label class="check-line"><input type="checkbox" data-show-password> Mostrar contraseñas</label><button class="btn btn-primary" type="submit">Crear mi cuenta</button><p class="account-access-switch">¿Ya tienes cuenta? <a href="<?= url('mi_cuenta.php?view=login') ?>">Iniciar sesión</a></p></form>
    <?php endif; ?>
  </div>
</div>
<script>document.querySelectorAll('[data-show-password]').forEach(toggle=>toggle.addEventListener('change',()=>toggle.closest('form').querySelectorAll('[data-password-field]').forEach(field=>field.type=toggle.checked?'text':'password')));</script>
<?php else: ?>
<div class="account-toolbar"><div><strong><?= e($profile['email']) ?></strong><span><?= e($profile['phone'] ?: 'Celular no registrado') ?></span></div><a class="btn btn-secondary" href="<?= url('cliente_salir.php') ?>">Cerrar sesión</a></div>
<div class="account-dashboard">
<section class="suite-card"><h2>Mis pedidos</h2><?php if($orders): ?><div class="account-list"><?php foreach($orders as $order): ?><a href="<?= url('mi_pedido.php?id='.(int)$order['id']) ?>"><div><strong><?= e($order['order_code']) ?></strong><small><?= e(date('d/m/Y H:i',strtotime($order['created_at']))) ?></small></div><span><?= money($order['expected_amount']) ?> · <?= e(str_replace('_',' ',$order['fulfillment_status'])) ?></span></a><?php endforeach ?></div><?php else: ?><p>Aún no tienes pedidos asociados a tu cuenta.</p><?php endif ?></section>
<section class="suite-card"><h2>Mis direcciones</h2><form method="post" class="compact-form"><?= csrf_field() ?><input type="hidden" name="action" value="address_add"><input name="label" placeholder="Nombre: Casa" maxlength="60"><input name="district" placeholder="Distrito" required><input name="address" placeholder="Dirección completa" required><input name="reference" placeholder="Referencia"><label class="check-line"><input type="checkbox" name="is_default" value="1"> Dirección principal</label><button class="btn btn-primary">Guardar dirección</button></form><?php foreach($addresses as $address): ?><div class="address-row"><div><strong><?= e($address['label']) ?><?= $address['is_default']?' · Principal':'' ?></strong><span><?= e($address['address'].', '.$address['district']) ?></span><small><?= e($address['reference']) ?></small></div><form method="post"><?= csrf_field() ?><input type="hidden" name="action" value="address_delete"><input type="hidden" name="id" value="<?= (int)$address['id'] ?>"><button>Eliminar</button></form></div><?php endforeach ?></section>
</div>
<section class="suite-card"><h2>Mis favoritos</h2><div class="favorite-grid"><?php foreach(array_merge($favoriteProducts,$favoriteOffers) as $favorite): $name=$favorite['name']??$favorite['producto'];$price=$favorite['price']??$favorite['precio_actual'];$image=$favorite['image_url']??$favorite['imagen']??''; ?><article><?php if($image): ?><img src="<?= e(image_src($image)) ?>" alt=""><?php endif ?><div><strong><?= e($name) ?></strong><span><?= money($price) ?></span></div></article><?php endforeach ?></div><?php if(!$favoriteProducts&&!$favoriteOffers): ?><p>Guarda productos desde el catálogo completo para encontrarlos aquí.</p><?php endif ?></section>
<?php endif ?>
</div></section>
<?php require __DIR__.'/includes/public_footer.php'; ?>
