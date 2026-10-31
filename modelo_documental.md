# Trabajo Práctico N.º 7 — Migración a MongoDB (Food Store)

## Consigna 1: Modelo documental y selección de datos

---

## 1. Tablas y claves que intervienen en PostgreSQL (`bd2_tp3`)

En el esquema relacional de **Food Store** (`food-store/schema.sql`), la reconstrucción completa de un pedido con su cliente y el detalle de los productos vendidos involucra cuatro tablas:

| Tabla | Clave Primaria (PK) | Claves Foráneas (FK) | Restricciones de Unicidad y Dominio Relevantes | Columnas que intervienen en la migración |
| :--- | :--- | :--- | :--- | :--- |
| **`pedido`** | `id_pedido` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | `id_cliente` $\rightarrow$ `cliente(id_cliente)` (`ON DELETE RESTRICT`) | `forma_pago` de tipo `forma_pago_enum` (`'EFECTIVO'`, `'TARJETA'`, `'TRANSFERENCIA'`) | `id_pedido`, `fecha`, `forma_pago`, `id_cliente` |
| **`detalle_pedido`** | `id_detalle` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | `id_pedido` $\rightarrow$ `pedido(id_pedido)` (`ON DELETE CASCADE`)<br>`id_producto` $\rightarrow$ `producto(id_producto)` (`ON DELETE RESTRICT`) | **`UNIQUE (id_pedido, id_producto)`** (impide repetir el mismo producto en más de una línea del mismo pedido)<br>`CHECK (cantidad > 0)`<br>`CHECK (precio_unitario >= 0)` | `id_pedido`, `id_producto`, `cantidad`, `precio_unitario` |
| **`cliente`** | `id_cliente` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | — | `UNIQUE (email)` (clave candidata R6) | `id_cliente`, `nombre`, `apellido`, `email` |
| **`producto`** | `id_producto` (`BIGINT GENERATED ALWAYS AS IDENTITY`) | `id_categoria` $\rightarrow$ `categoria(id_categoria)` (`ON DELETE RESTRICT`) | `CHECK (precio >= 0)`<br>`activo BOOLEAN` (baja lógica R7) | `id_producto`, `nombre` |

### Observaciones del modelo relacional de origen
* **Relación N:M resuelta por `detalle_pedido`:** Un pedido contiene una o varias líneas de detalle, y cada producto puede figurar en múltiples pedidos. La clave sustituta `id_detalle` identifica la fila en PostgreSQL, mientras que la restricción compuesta `UNIQUE (id_pedido, id_producto)` garantiza a nivel motor que cada producto aparezca como máximo una vez dentro del mismo pedido.
* **Precio histórico congelado (R4):** La columna `detalle_pedido.precio_unitario` almacena el valor al que se vendió el producto en el momento del pedido, independientemente de actualizaciones posteriores en `producto.precio`.
* **Subtotal no almacenado (3FN):** En `detalle_pedido` no existe columna `subtotal`; se calcula como `cantidad * precio_unitario` para evitar dependencias transitivas.

---

## 2. Esquema de la colección `pedidos` en MongoDB

Para pasar del modelo relacional normalizado (4 tablas unidas mediante `INNER JOIN`) al modelo documental en MongoDB, se diseña una única colección llamada **`pedidos`**, donde cada documento representa un pedido completo de forma autocontenida:

### Estructura general del esquema

```javascript
{
  _id: <Number>,                 // Conserva el id_pedido original de PostgreSQL (_id = id_pedido)
  fecha: <ISODate>,              // Fecha y hora de emisión del pedido
  forma_pago: <String>,          // "EFECTIVO" | "TARJETA" | "TRANSFERENCIA" (decisión de diseño)
  cliente: {                     // OBJETO EMBEBIDO (1:1 con el pedido)
    id_cliente: <Number>,        // Conserva el id_cliente original de PostgreSQL
    nombre: <String>,            // Nombre y apellido concatenados ("nombre apellido")
    email: <String>              // Correo electrónico del cliente
  },
  lineas: [                      // ARREGLO DE OBJETOS EMBEBIDOS (1:N desde detalle_pedido + producto)
    {
      id_producto: <Number>,     // Conserva el id_producto original de PostgreSQL
      nombre: <String>,          // Nombre del producto al momento de exportar
      cantidad: <Number>,        // Unidades vendidas en esa línea (cantidad > 0)
      precio_unitario: <Number>  // Precio histórico congelado de detalle_pedido (R4)
    }
  ]
}
```

### Decisiones de diseño documentadas

1. **Conservación de identificadores de origen:**
   * `_id`: se asigna directamente el `id_pedido` entero de PostgreSQL (`_id = id_pedido`), evitando generar un `ObjectId` artificial que dificulte la trazabilidad y la comparación entre motores.
   * `cliente.id_cliente` y `lineas[].id_producto`: se conservan dentro del objeto embebido y de cada elemento del arreglo respectivamente para permitir consultas por identificador de cliente o de producto (Consigna 4.c) y auditorías cruzadas contra `bd2_tp3`.
2. **Uso de `forma_pago` como atributo de estado/clasificación del pedido:**
   * En el DDL oficial del proyecto (`food-store/schema.sql` y base `bd2_tp3`), la tabla `pedido` **no posee una columna `estado`**, sino la columna `forma_pago` definida sobre el tipo enumerado `forma_pago_enum` (`'EFECTIVO'`, `'TARJETA'`, `'TRANSFERENCIA'`).
   * Se deja documentada como decisión de diseño del equipo utilizar `forma_pago` como campo equivalente en el documento raíz y en los filtros de selección y consulta (Consigna 4.b).
3. **El subtotal y el total no se almacenan:**
   * Ni el subtotal de cada renglón ni el total de la cabecera se guardan como campos fijos dentro del documento. Ambos se calculan en las consultas mediante `cantidad * precio_unitario` (`$multiply` y `$sum`), evitando posibles inconsistencias entre los renglones del arreglo `lineas[]` y un valor precalculado.

### Ejemplo de documento real (`_id: 1`) con anotaciones de estructura

```javascript
{
  // [ID CONSERVADO] Clave primaria del documento: conserva pedido.id_pedido = 1
  "_id": 1,
  "fecha": ISODate("2026-08-01T13:15:00Z"),
  "forma_pago": "EFECTIVO",

  // [OBJETO EMBEBIDO] Datos del cliente asociados al pedido (conserva cliente.id_cliente = 1)
  "cliente": {
    "id_cliente": 1,
    "nombre": "Ana Gutiérrez",
    "email": "ana.gutierrez@example.com"
  },

  // [ARREGLO DE SUBDOCUMENTOS] Renglones del pedido (conserva detalle_pedido.id_producto en cada línea)
  // El subtotal de cada línea no se guarda: se calcula como cantidad * precio_unitario
  "lineas": [
    {
      "id_producto": 1,
      "nombre": "Pan de campo 1kg",
      "cantidad": 2,
      "precio_unitario": 2200.00
    },
    {
      "id_producto": 5,
      "nombre": "Leche entera 1L",
      "cantidad": 1,
      "precio_unitario": 1650.00
    },
    {
      "id_producto": 66076,
      "nombre": "Producto 31065",
      "cantidad": 1,
      "precio_unitario": 860.75
    },
    {
      "id_producto": 72206,
      "nombre": "Producto 37195",
      "cantidad": 3,
      "precio_unitario": 746.65
    },
    {
      "id_producto": 83667,
      "nombre": "Producto 48656",
      "cantidad": 3,
      "precio_unitario": 279.07
    }
  ]
}
```

---

## 3. Selección de pedidos desde `bd2_tp3`

Se seleccionaron **7 pedidos reales** de la base `bd2_tp3` (29 líneas de detalle en total):

$$\text{IDs seleccionados: } \mathbf{1,\ 2,\ 3,\ 4,\ 5,\ 59428,\ 74364}$$

### Tabla resumen de los 7 pedidos elegidos

| `id_pedido` (`_id`) | `fecha` (UTC) | `forma_pago` | `id_cliente` | Cliente (`nombre`) | Cantidad de líneas | Total calculado (`SUM(cantidad * precio_unitario)`) | IDs de productos en `lineas[]` |
| :---: | :---: | :---: | :---: | :--- | :---: | :---: | :--- |
| **1** | `2026-08-01 13:15:00+00` | `EFECTIVO` | `1` | Ana Gutiérrez | 5 | `$9.987,91` | **`1`**, `5`, `66076`, `72206`, `83667` |
| **2** | `2026-08-03 21:40:00+00` | `TARJETA` | `2` | Bruno Salinas | 6 | `$19.036,35` | `3`, `7`, `38558`, `51872`, `66351`, `69939` |
| **3** | `2026-08-07 12:05:00+00` | `TRANSFERENCIA` | `1` | Ana Gutiérrez | 6 | `$15.453,62` | `2`, `6`, `67973`, `71591`, `71682`, `72234` |
| **4** | `2026-08-12 23:30:00+00` | `TARJETA` | `3` | Carla Medina | 5 | `$16.658,04` | `8`, `9`, `66290`, `68909`, `81323` |
| **5** | `2026-08-18 15:00:00+00` | `EFECTIVO` | `4` | Diego Ferrari | 3 | `$4.293,65` | `4`, `75467`, `80098` |
| **59428** | `2025-05-08 10:01:17+00` | `TRANSFERENCIA` | `22903` | Nombre4898 Apellido4898 | 2 | `$7.552,58` | **`1`**, `64780` |
| **74364** | `2026-02-27 12:13:59+00` | `TARJETA` | `24222` | Nombre6217 Apellido6217 | 2 | `$9.489,63` | **`1`**, `35739` |
| **Total (7 pedidos)** | — | — | — | — | **29 líneas** | **`$82.471,78`** | — |

### Verificación de los criterios de selección

1. **Rango de cantidad (entre 5 y 8 pedidos):** Se eligieron **7 pedidos** (los 5 pedidos iniciales del lote semilla con nombres reales más 2 pedidos de la carga masiva de `bd2_tp3`).
2. **Al menos 2 formas de pago distintas (para la consulta 4.b):** Están presentes las **3 formas de pago** posibles:
   * `EFECTIVO`: 2 pedidos (`1`, `5`).
   * `TARJETA`: 3 pedidos (`2`, `4`, `74364`).
   * `TRANSFERENCIA`: 2 pedidos (`3`, `59428`).
3. **Al menos un producto repetido en 2 o más pedidos (para la consulta 4.c y regla R4):**
   * El producto **`id_producto = 1` (`Pan de campo 1kg`)** aparece en **3 de los pedidos seleccionados**: `1`, `59428` y `74364` (con 2 unidades en el pedido `1`, 3 unidades en el `59428` y 3 unidades en el `74364`, sumando 8 unidades vendidas en total dentro del subconjunto migrado).
   * Además, permite verificar empíricamente la regla de negocio **R4 (precio histórico congelado)**: en el pedido `1` tiene `precio_unitario = 2200.00`, mientras que en los pedidos `59428` y `74364` tiene `precio_unitario = 2500.00`.
4. **Pedidos con 2 o más líneas y totales variados (para la consulta 4.d):**
   * Todos los pedidos tienen entre **2 y 6 líneas**.
   * Los importes totales cubren un rango amplio desde **`$4.293,65`** (pedido `5`) hasta **`$19.036,35`** (pedido `2`), con un **promedio de `$11.781,68`** por pedido.
   * Si en la consulta 4.d se utiliza como umbral un monto cercano al promedio (por ejemplo `$10.000,00` o `$11.781,68`), el filtro divide limpiamente el lote en **3 pedidos que superan el umbral** (`2`, `3` y `4`) y **4 pedidos por debajo** (`1`, `5`, `59428` y `74364`).

---

## 4. Detalle completo de las 29 líneas exportadas (`seleccion_pedidos.sql`)

La consulta SQL de extracción se encuentra en el archivo [`seleccion_pedidos.sql`](./seleccion_pedidos.sql). A continuación se transcribe el resultado exacto de las 29 filas en `bd2_tp3` para facilitar el armado del `insertMany()` y el control cruzado:

| `id_pedido` | `forma_pago` | `id_cliente` | `cliente_nombre` | `id_producto` | `producto_nombre` | `cantidad` | `precio_unitario` | `subtotal_linea` |
| :---: | :---: | :---: | :--- | :---: | :--- | :---: | :---: | :---: |
| 1 | `EFECTIVO` | 1 | Ana Gutiérrez | 1 | Pan de campo 1kg | 2 | 2200.00 | 4400.00 |
| 1 | `EFECTIVO` | 1 | Ana Gutiérrez | 5 | Leche entera 1L | 1 | 1650.00 | 1650.00 |
| 1 | `EFECTIVO` | 1 | Ana Gutiérrez | 66076 | Producto 31065 | 1 | 860.75 | 860.75 |
| 1 | `EFECTIVO` | 1 | Ana Gutiérrez | 72206 | Producto 37195 | 3 | 746.65 | 2239.95 |
| 1 | `EFECTIVO` | 1 | Ana Gutiérrez | 83667 | Producto 48656 | 3 | 279.07 | 837.21 |
| 2 | `TARJETA` | 2 | Bruno Salinas | 3 | Agua mineral 2L | 3 | 1400.00 | 4200.00 |
| 2 | `TARJETA` | 2 | Bruno Salinas | 7 | Yerba mate 1kg | 1 | 6800.00 | 6800.00 |
| 2 | `TARJETA` | 2 | Bruno Salinas | 38558 | Producto 3547 | 3 | 328.07 | 984.21 |
| 2 | `TARJETA` | 2 | Bruno Salinas | 51872 | Producto 16861 | 4 | 906.37 | 3625.48 |
| 2 | `TARJETA` | 2 | Bruno Salinas | 66351 | Producto 31340 | 3 | 556.04 | 1668.12 |
| 2 | `TARJETA` | 2 | Bruno Salinas | 69939 | Producto 34928 | 3 | 586.18 | 1758.54 |
| 3 | `TRANSFERENCIA` | 1 | Ana Gutiérrez | 2 | Medialunas x6 | 2 | 3200.00 | 6400.00 |
| 3 | `TRANSFERENCIA` | 1 | Ana Gutiérrez | 6 | Queso cremoso 500g | 1 | 7600.00 | 7600.00 |
| 3 | `TRANSFERENCIA` | 1 | Ana Gutiérrez | 67973 | Producto 32962 | 2 | 376.55 | 753.10 |
| 3 | `TRANSFERENCIA` | 1 | Ana Gutiérrez | 71591 | Producto 36580 | 1 | 529.53 | 529.53 |
| 3 | `TRANSFERENCIA` | 1 | Ana Gutiérrez | 71682 | Producto 36671 | 1 | 149.07 | 149.07 |
| 3 | `TRANSFERENCIA` | 1 | Ana Gutiérrez | 72234 | Producto 37223 | 1 | 21.92 | 21.92 |
| 4 | `TARJETA` | 3 | Carla Medina | 8 | Aceite girasol 900ml | 1 | 4100.00 | 4100.00 |
| 4 | `TARJETA` | 3 | Carla Medina | 9 | Fideos secos 500g | 4 | 1950.00 | 7800.00 |
| 4 | `TARJETA` | 3 | Carla Medina | 66290 | Producto 31279 | 2 | 470.10 | 940.20 |
| 4 | `TARJETA` | 3 | Carla Medina | 68909 | Producto 33898 | 4 | 243.39 | 973.56 |
| 4 | `TARJETA` | 3 | Carla Medina | 81323 | Producto 46312 | 4 | 711.07 | 2844.28 |
| 5 | `EFECTIVO` | 4 | Diego Ferrari | 4 | Gaseosa cola 2.25L | 1 | 3900.00 | 3900.00 |
| 5 | `EFECTIVO` | 4 | Diego Ferrari | 75467 | Producto 40456 | 1 | 281.07 | 281.07 |
| 5 | `EFECTIVO` | 4 | Diego Ferrari | 80098 | Producto 45087 | 2 | 56.29 | 112.58 |
| 59428 | `TRANSFERENCIA` | 22903 | Nombre4898 Apellido4898 | 1 | Pan de campo 1kg | 3 | 2500.00 | 7500.00 |
| 59428 | `TRANSFERENCIA` | 22903 | Nombre4898 Apellido4898 | 64780 | Producto 29769 | 2 | 26.29 | 52.58 |
| 74364 | `TARJETA` | 24222 | Nombre6217 Apellido6217 | 1 | Pan de campo 1kg | 3 | 2500.00 | 7500.00 |
| 74364 | `TARJETA` | 24222 | Nombre6217 Apellido6217 | 35739 | Producto 728 | 3 | 663.21 | 1989.63 |
