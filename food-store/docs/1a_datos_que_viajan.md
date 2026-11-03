# 1.a · Qué datos viajan a la tablet

| Dato en PostgreSQL (`bd2_tp8`) | ¿Viaja? | Cómo llega a la tablet | Por qué |
|---|---|---|---|
| `producto.id_producto` | Sí | `producto_id` | Identifica el producto igual que en el servidor, para comparar en el semáforo |
| `producto.nombre` | Sí | `nombre` | El vendedor tiene que ver qué vende |
| `producto.precio` (NUMERIC) | Sí, convertido | `precio_centavos` (INTEGER) | Para mostrar el catálogo y detectar cambios de precio; en centavos las cuentas son exactas |
| `producto.stock` | Sí, como copia | `stock_visto` | Solo orientativo: el stock real lo decide el servidor |
| `producto.activo` y `categoria.activo` | Sí, convertidos | `eliminado` (lápida) y `disponible` | La baja viaja como dato: el producto sale del catálogo pero la fila queda. Cuenta la baja del producto **o** de su categoría |
| — | Se agrega | `capturado_en` | Fecha de la copia con la hora del servidor (`now()`): dice cuán vieja es la lista |
| Id del usuario (vendedor) | Solo el id | `usuario_id_servidor` | Identifica quién arma el borrador; nombre, mail y contraseña no viajan |
| Forma de pago | Solo la forma | `forma_pago` | EFECTIVO, TARJETA o TRANSFERENCIA; los datos de la tarjeta no viajan |
| `producto.descripcion`, `id_categoria`, `created_at`, imágenes, atributos extra | No | — | No hacen falta para vender; la tablet tiene poco espacio |
| `cliente` (nombre, apellido, email, teléfono) | No | — | Datos personales: no hacen falta para vender y la tablet se puede perder |
| `pedido` y `detalle_pedido` (pedidos confirmados, historial de ventas) | No | — | Solo el servidor confirma, numera ventas y arma el historial |

A la tablet viaja solo lo necesario para mostrar el catálogo y armar borradores sin señal. Los datos personales no viajan porque la Ley 25.326 pide que los datos sean "adecuados, pertinentes y no excesivos" (art. 4) y que se cuide su seguridad (art. 9): en un dispositivo que se puede perder y que no tiene usuarios ni permisos, guardar poco es la principal medida de seguridad. **La fuente de verdad es PostgreSQL**: precio, stock y ventas los decide el servidor, y lo que guarda la tablet es una copia con fecha que puede estar vieja.
