# Consigna 5: Verificación PostgreSQL vs MongoDB

**Trabajo Práctico N.º 7 — Migración a MongoDB (Food Store)**  
**Responsable:** Belén Calvo

Consultas: `consultas_mongodb.js` (Consigna 4) y `consultas_postgresql.sql` (Consigna 5), ambas limitadas a los 8 pedidos migrados (1, 2, 3, 4, 5, 45018, 59428, 74364). Salidas completas en `evidencias/`.

## Tabla de verificación

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | IDs | Coinciden los IDs |
|---|:---:|:---:|---|:---:|
| Estado seleccionado (`forma_pago = EFECTIVO`) | 3 | 3 | 1, 5, 45018 | Sí |
| Producto seleccionado (`id_producto = 1`, Pan de campo 1kg) | 3 | 3 | 1, 59428, 74364 | Sí |
| *Control adicional:* todos los pedidos (a) | 8 | 8 | 1, 2, 3, 4, 5, 45018, 59428, 74364 | Sí |
| *Control adicional:* total > $10.000, desc. (d) | 3 | 3 | 2, 4, 3 (en ese orden) | Sí |

Además de los IDs coinciden los importes: los totales de b) y d) y los precios históricos de c) (2200.00 en el pedido 1; 2500.00 en 59428 y 74364) son idénticos en ambos motores. La auditoría de MongoDB (total distinto de la suma de líneas) devuelve 0 documentos.

## Diferencias detectadas

1. **Precisión de las fechas.** En los pedidos de la carga masiva (45018, 59428, 74364), PostgreSQL muestra microsegundos (`2025-05-23 06:26:12.027438+00`) y MongoDB milisegundos (`2025-05-23T06:26:12.027Z`). `TIMESTAMPTZ` guarda precisión de microsegundos y el tipo `Date` de BSON de milisegundos, por lo que la migración trunca los últimos tres dígitos. No afecta IDs, cantidades ni importes, ni el resultado de ninguna consulta. Se acepta como limitación del tipo de dato; si hiciera falta la precisión completa, podría guardarse además la fecha original como texto.
2. **Filtro de borrado lógico.** No se aplicó `eliminado = false` en ningún motor: las tablas de origen (`pedido`, `detalle_pedido`, `cliente`, `producto`) no tienen esa columna en `bd2_tp3`.

No hubo que corregir el modelo ni las consultas: los resultados coinciden en ambos motores.

## Observación sobre las consultas

- **b)** En PostgreSQL el total se calcula con `SUM(cantidad * precio_unitario)` y `GROUP BY` (1 JOIN). En MongoDB se lee el campo `total` del documento.
- **c)** En PostgreSQL hacen falta 2 JOIN entre 3 tablas (`pedido`, `detalle_pedido`, `producto`). En MongoDB alcanza con un `find` sobre `lineas.id_producto`, porque las líneas están embebidas en el pedido.
