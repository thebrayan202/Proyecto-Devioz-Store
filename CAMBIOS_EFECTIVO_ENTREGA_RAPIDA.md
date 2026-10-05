# Ajustes de checkout y entrega rápida

## Pago en efectivo
- No solicita nombre ni teléfono.
- El cliente elige entre **Pago exacto** y **Necesito vuelto**.
- En pago exacto, el sistema usa automáticamente el total del pedido como `monto_paga_con` y calcula vuelto `0.00`.
- Si necesita vuelto, solicita el monto recibido y calcula el vuelto antes de confirmar.
- En base de datos, las ventas en efectivo sin datos personales se guardan como `Cliente mostrador` y teléfono vacío.
- El panel administrativo identifica cuando el pago fue exacto.

## Pago con Yape
- Mantiene nombre, teléfono, captura y flujo de revisión existente.

## Clasificación automática de despacho
Un pedido se clasifica como `entrega_rapida` cuando:
- todos sus productos permiten `entrega_inmediata = 1`;
- contiene como máximo 3 unidades físicas en total;
- contiene como máximo 3 líneas de productos/combos.

Los packs cuentan por sus unidades físicas. Los combos cuentan por la suma de sus componentes.

## Flujo administrativo simplificado
- Pedido pequeño + efectivo: queda directamente **Listo para entregar**.
- Pedido pequeño + Yape: al aprobar el comprobante pasa directamente a **Listo para entregar**.
- En entrega rápida no aparecen los pasos "Iniciar preparación" ni "Marcar como listo".
- Solo queda una acción administrativa: **Confirmar entrega**.
- Los pedidos que no cumplan la regla siguen usando el flujo normal: Recibido → En preparación → Listo → Entregado.
