<?php
declare(strict_types=1);
function receipt_business(): array {
    $defaults=['name'=>'Devioz Store','tagline'=>'Tu tienda, más cerca de ti','legal_name'=>'','ruc'=>'','address'=>'','phone'=>'','website'=>'https://devioz.com'];
    foreach($defaults as $key=>$value)$defaults[$key]=store_setting('receipt_business_'.$key,$value);
    return $defaults;
}
function receipt_barcode(string $value): string {
    if(!preg_match('/^[A-Z0-9-]{1,48}$/D',$value))return '';
    $patterns=["BaBbBb", "BbBaBb", "BbBbBa", "AbAbBc", "AbAcBb", "AcAbBb", "AbBbAc", "AbBcAb", "AcBbAb", "BbAbAc", "BbAcAb", "BcAbAb", "AaBbCb", "AbBaCb", "AbBbCa", "AaCbBb", "AbCaBb", "AbCbBa", "BbCbAa", "BbAaCb", "BbAbCa", "BaCbAb", "BbCaAb", "CaBaCa", "CaAbBb", "CbAaBb", "CbAbBa", "CaBbAb", "CbBaAb", "CbBbAa", "BaBaBc", "BaBcBa", "BcBaBa", "AaAcBc", "AcAaBc", "AcAcBa", "AaBcAc", "AcBaAc", "AcBcAa", "BaAcAc", "BcAaAc", "BcAcAa", "AaBaCc", "AaBcCa", "AcBaCa", "AaCaBc", "AaCcBa", "AcCaBa", "CaCaBa", "BaAcCa", "BcAaCa", "BaCaAc", "BaCcAa", "BaCaCa", "CaAaBc", "CaAcBa", "CcAaBa", "CaBaAc", "CaBcAa", "CcBaAa", "CaDaAa", "BbAdAa", "DcAaAa", "AaAbBd", "AaAdBb", "AbAaBd", "AbAdBa", "AdAaBb", "AdAbBa", "AaBbAd", "AaBdAb", "AbBaAd", "AbBdAa", "AdBaAb", "AdBbAa", "BdAbAa", "BbAaAd", "DaCaAa", "BdAaAb", "AcDaAa", "AaAbDb", "AbAaDb", "AbAbDa", "AaDbAb", "AbDaAb", "AbDbAa", "DaAbAb", "DbAaAb", "DbAbAa", "BaBaDa", "BaDaBa", "DaBaBa", "AaAaDc", "AaAcDa", "AcAaDa", "AaDaAc", "AaDcAa", "DaAaAc", "DaAcAa", "AaCaDa", "AaDaCa", "CaAaDa", "DaAaCa", "BaAdAb", "BaAbAd", "BaAbCb", "BcCaAaB"];
    $codes=[104];$checksum=104;
    for($i=0;$i<strlen($value);$i++){$code=ord($value[$i])-32;$codes[]=$code;$checksum+=$code*($i+1);}
    $codes[]=$checksum%103;$codes[]=106;$x=10;$bars='';
    foreach($codes as $code)foreach(str_split($patterns[$code])as $part){$w=ord(strtolower($part))-96;
        if(ctype_upper($part))$bars.='<rect x="'.$x.'" y="0" width="'.$w.'" height="45"/>';
        $x+=$w;}
    return '<svg xmlns="http://www.w3.org/2000/svg" role="img" aria-label="Código de recibo '.e($value).'" viewBox="0 0 '.($x+10).' 45" preserveAspectRatio="none">'.$bars.'</svg>';
}
function receipt_plain_text(array $business,array $order,array $items): string {
    $lines=[$business['name'],$business['tagline']];
    foreach(['legal_name','address','phone','website']as $key)if($business[$key]!=='')$lines[]=$business[$key];
    if($business['ruc']!=='')$lines[]='RUC: '.$business['ruc'];
    $lines[]='COMPROBANTE DE ENTREGA';$lines[]=receipt_number($order);$lines[]='Pedido: '.$order['order_code'];
    $lines[]='Fecha: '.date('d/m/Y H:i',strtotime($order['delivered_at']?:$order['created_at']));
    $lines[]=str_repeat('-',38);$count=0;
    foreach($items as $item){$count+=(int)$item['quantity'];
        $lines[]=$item['item_name'];$lines[]=(int)$item['quantity'].' x '.money($item['unit_price']).' = '.money($item['subtotal']);
        if($item['presentation']==='paquete')$lines[]='Pack de '.(int)$item['units_per_item'];}
    $lines[]=str_repeat('-',38);
    $subtotal=(float)($order['subtotal_amount']??$order['expected_amount']);
    $delivery=(float)($order['delivery_fee']??0);$discount=(float)($order['discount_amount']??0);
    $lines[]='Subtotal: '.money($subtotal);
    if($delivery>0)$lines[]='Delivery: '.money($delivery);
    if($discount>0)$lines[]='Descuento'.(!empty($order['coupon_code'])?' ('.$order['coupon_code'].')':'').': -'.money($discount);
    $lines[]='TOTAL: '.money($order['expected_amount']);
    if(!empty($order['delivery_address'])){$lines[]='Entrega: '.$order['delivery_address'];if(!empty($order['delivery_reference']))$lines[]='Referencia: '.$order['delivery_reference'];}
    $cash=($order['metodo_pago']??'yape')==='efectivo';$lines[]='Pago: '.payment_label((string)($order['metodo_pago']??'yape'));
    if($cash){$lines[]='Recibido: '.(isset($order['monto_paga_con'])?money($order['monto_paga_con']):'No registrado');$lines[]='Vuelto: '.(isset($order['vuelto'])?money($order['vuelto']):'No registrado');}
    $lines[]='Presentaciones vendidas: '.$count;
    $lines[]='Documento interno. No es boleta ni factura electrónica.';$lines[]='Gracias por tu compra.';
    return implode("\n",$lines)."\n";
}
