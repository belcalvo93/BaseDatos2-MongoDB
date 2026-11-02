# TP8 · Food Store · La base de la tablet (SQLite)

Base de Datos II · UTN-FRM · Tecnicatura Universitaria en Programación
Grupo: Belén Calvo, Elías Tello, Hernán González, Bruno Fiouchetta

El food truck vende en una feria sin señal. La tablet guarda una copia del catálogo en SQLite, arma **borradores** de pedido sin conexión y, al volver la señal, se **simula** la sincronización con PostgreSQL con un **semáforo**.

**Regla de oro: el móvil propone, el servidor dispone.** La tablet nunca decide precio, stock ni ventas: eso es solo de PostgreSQL. `SIMULADO_APROBADO` significa "pasaría las validaciones", **no es una venta**, y ningún script de la simulación modifica PostgreSQL.

---

## Requisitos

| Herramienta | Versión | Cómo verificar |
|---|---|---|
| PostgreSQL (`psql`, `createdb` en el PATH) | 16 o más | `psql --version` |
| SQLite (CLI `sqlite3`) | 3.37 o más (por `STRICT`) | `sqlite3 --version` |
| Base `bd2_tp3` cargada | la del TP3 | `psql -U postgres -d bd2_tp3 -c "select count(*) from producto"` → 50011 |

Instalar `sqlite3` en Windows: `winget install SQLite.SQLite` (después abrir una terminal nueva), o *sqlite-tools-win-x64* de sqlite.org descomprimido en `C:\sqlite` y agregado al PATH.

> **Todos los comandos se corren desde la carpeta `food-store/`.**
> `sqlite3` **sin** nombre de archivo abre una base en memoria que se pierde al salir: siempre pasar `movil/foodstore_movil.db`.

---

## Orden para crear todo desde cero

### 1. Copia de la base del servidor (`bd2_tp8`)

Los casos C2 y C4 cambian datos del servidor, así que se trabaja sobre una copia. **`bd2_tp3` no se toca.** No tiene que haber nadie conectado a `bd2_tp3` (cerrar pgAdmin o DBeaver).

```bash
createdb -U postgres -T bd2_tp3 bd2_tp8
```

Si ya existía y se quiere empezar de cero: `dropdb -U postgres bd2_tp8` y repetir.

### 2. Vista de la instantánea en PostgreSQL

```bash
psql -U postgres -d bd2_tp8 -f postgresql/10_snapshot_catalogo.sql
```

Crea `v_snapshot_movil` y muestra los productos fijos y el total de filas (50011, de las cuales 10048 son lápidas). El script se corta solo si se lo corre sobre otra base que no sea `bd2_tp8`.

### 3. Base de la tablet (esquema)

```bash
sqlite3 movil/foodstore_movil.db ".read movil/schema_sqlite.sql"
```

Crea las 5 tablas `STRICT`, el índice parcial `ux_cola_una_pendiente` y la vista `v_catalogo_disponible`. Borra lo anterior si ya existía.

### 4. Exportar la instantánea (en el servidor)

```bash
psql -U postgres -d bd2_tp8 -c "\copy (SELECT * FROM v_snapshot_movil ORDER BY producto_id) TO 'movil/servidor_snapshot.csv' CSV HEADER"
```

Esperado: `COPY 50011`. Los booleanos salen como `t`/`f`.

### 5. Importar la instantánea y cargar el catálogo de la tablet

```bash
sqlite3 movil/foodstore_movil.db ".read movil/importar_catalogo.sql"
```

Esperado: `filas_instantanea = filas_cache = 50011`, `lapidas = 10048`, `catalogo_disponible = 39963`, y la fecha de la copia (`capturado_en`).
Los pasos 4 y 5 se repiten cada vez que cambia algo en el servidor (casos C2 y C4).

### 6. Pruebas de la base de la tablet (transacciones, C1 y C7)

Van sobre una base **aparte** (`pruebas.db`), porque usan productos inventados:

```bash
rm -f movil/pruebas.db
sqlite3 movil/pruebas.db ".read movil/schema_sqlite.sql" ".read movil/pruebas_sqlite.sql"
```

Los únicos errores esperados son el `CHECK` y la `FOREIGN KEY` del C7. Ver `evidencias/salida_pruebas_sqlite.txt`.

### 7. Casos C2 a C6 con el semáforo

Cada caso sigue el mismo flujo:

1. Crear el borrador en SQLite (transacción, UUIDs fijos).
2. Si el caso lo pide, cambiar el dato en `bd2_tp8` (C2: subir el precio; C4: `activo = false`). Es preparación manual del caso, no parte de la simulación.
3. Exportar una instantánea nueva (paso 4) e importarla (paso 5).
4. Correr el semáforo:
   ```bash
   sqlite3 movil/foodstore_movil.db ".read movil/semaforo.sql"
   ```
5. Mirar `cola_sync` (el script la muestra al final) y explicar el resultado.

Para reproducir los casos C2 a C6 completos en forma automatizada (una vez creada `foodstore_movil.db` y cargada la instantánea inicial de los pasos 3 a 5):

```bash
psql -U postgres -d bd2_tp8 -f postgresql/casos_servidor.sql
sqlite3 movil/foodstore_movil.db ".read movil/casos_sqlite.sql"
```

El detalle de cada caso y el mapa de los 3 motores están en `docs/2c_casos_y_3a_mapa.md`, y las salidas en `evidencias/salida_casos_servidor_postgresql.txt` y `evidencias/salida_casos_c2_c6_sqlite.txt`.

### 8. Consulta final en PostgreSQL

Antes y después de la simulación:

```sql
SELECT count(*) FROM pedido;                                          -- 200005
SELECT id_producto, stock FROM producto WHERE id_producto IN (2, 3, 9, 10, 11) ORDER BY 1;
```

La cantidad de pedidos y el stock no cambian por la simulación. Lo único que cambia en `bd2_tp8` es lo que se preparó a mano para C2 (precio del producto 3) y C4 (`activo` del producto 11).

---

## Productos fijos para los casos

Datos de `bd2_tp8` recién copiada (precio en pesos y en centavos, como viaja a la tablet):

| Uso | id_producto | Nombre | Precio | precio_centavos | Stock | Qué se hace |
|---|---|---|---|---|---|---|
| C2 · el precio sube | 3 | Agua mineral 2L | $1400,00 | 140000 | 40 | Se sube a $1600,00 en `bd2_tp8` → `CONFLICTO` |
| C3 · poco stock | 2 | Medialunas x6 | $3200,00 | 320000 | 3 | El borrador pide 5 → `RECHAZADO` |
| C4 · se da de baja | 11 | Cerveza 1L | $4500,00 | 450000 | 10 | `activo = false` en `bd2_tp8` → `RECHAZADO` |
| C5 · sin cambios | 9 | Fideos secos 500g | $1950,00 | 195000 | 30 | Nada → `SIMULADO_APROBADO` |
| C1/C7 · pruebas | 10 | Helado 1L | $9500,00 | 950000 | 0 | Ya está dado de baja (producto y categoría): no aparece en `v_catalogo_disponible` |

---

## Decisiones de diseño (bloque B)

- **Precio en centavos enteros.** La conversión `round(precio * 100)::INTEGER` se hace una sola vez, en la vista de PostgreSQL. La tablet nunca guarda precios con decimales.
- **Baja por producto o por categoría.** `eliminado = NOT p.activo OR NOT c.activo` y `disponible = p.activo AND c.activo AND stock > 0`. La categoría Congelados está dada de baja en nuestra base, así que sus 10048 productos viajan como lápidas aunque el producto esté activo. Si se mirara solo `p.activo`, la tablet ofrecería productos de una categoría que el servidor ya no vende.
- **La lápida viaja.** La vista no filtra los productos dados de baja: viajan marcados `eliminado = t`. La tablet los saca del catálogo pero conserva la fila.
- **Upsert, no borrar y recargar.** `importar_catalogo.sql` actualiza las filas de `producto_cache` con `ON CONFLICT … DO UPDATE`. Si se borrara el caché para recargarlo, un borrador que usa un producto dado de baja rompería la clave foránea de `item_borrador` (C4).
- **El semáforo solo evalúa `PENDIENTE`.** Lo ya evaluado conserva su resultado aunque se vuelva a correr el script (idempotencia del lado de la tablet, C6). La protección real contra envíos duplicados va en el servidor (tabla con `solicitud_uuid` única y la misma transacción que crea el pedido); el TP no la implementa.
- **Sin instantánea no hay evaluación.** Si `snapshot_servidor` está vacía, el semáforo no toca nada: si no, rechazaría todo como "producto inexistente".
- **Un borrador sin ítems es rojo.** El semáforo lo rechaza con el motivo "borrador sin ítems" en vez de dejarlo pendiente para siempre.

## Cómo se verificó el semáforo

En una base de prueba aparte (no se sube al repo), con la instantánea real cargada y los cambios del servidor simulados **sobre `snapshot_servidor`** (sin tocar PostgreSQL):

| Escenario | Resultado | Motivo |
|---|---|---|
| Precio del producto 3 subió | `CONFLICTO` | `precio cambió: producto 3 (visto 140000, actual 160000 centavos)` |
| Cliente acepta el precio y se crea otra solicitud | `SIMULADO_APROBADO` | `todo coincide con la instantánea (simulación, no es una venta)` |
| Pide 5 del producto 2 (hay 3) | `RECHAZADO` | `stock insuficiente: producto 2 (pide 5, hay 3)` |
| Producto 11 dado de baja | `RECHAZADO` | `dado de baja: producto 11` |
| Producto 9 sin cambios | `SIMULADO_APROBADO` | `todo coincide …` |
| Rojo (producto 2) y amarillo (producto 3) juntos | `RECHAZADO` | gana el rojo |
| Producto sin stock (`disponible = f`) | `RECHAZADO` | `no disponible: producto 1` |
| Producto que no está en la instantánea | `RECHAZADO` | `producto inexistente: producto 900001` |
| Borrador sin ítems | `RECHAZADO` | `borrador sin ítems` |
| Mismo `solicitud_uuid` otra vez | error | `UNIQUE constraint failed: cola_sync.solicitud_uuid` |
| Dos `PENDIENTE` del mismo borrador | error | `UNIQUE constraint failed: cola_sync.id_local` (índice parcial) |
| Semáforo sin instantánea cargada | queda `PENDIENTE` | no evalúa |
| Correr el semáforo dos veces | salida idéntica | no reevalúa |

Al final: `PRAGMA foreign_key_check` sin filas y `PRAGMA integrity_check` = `ok`.

---

## Archivos

| Archivo | Consigna | Quién |
|---|---|---|
| `postgresql/10_snapshot_catalogo.sql` | 2.a vista `v_snapshot_movil` | Elías |
| `movil/servidor_snapshot.csv` | 2.a instantánea exportada | Elías |
| `movil/importar_catalogo.sql` | 2.a importación + upsert al caché | Elías |
| `movil/semaforo.sql` | 2.b semáforo | Elías |
| `movil/schema_sqlite.sql` | 1.b tablas de la tablet | Belén |
| `movil/pruebas_sqlite.sql` | 1.c transacciones, C1, C7 | Belén |
| `docs/1a_datos_que_viajan.md` | 1.a | Belén |
| `docs/kiro/` | 4.a spec (requirements, design, tasks) | Belén |
| `docs/bitacora_ia.md` | 4.b bitácora de IA | todos |
| `postgresql/casos_servidor.sql` | 2.c preparación en `bd2_tp8` y consulta inicial/final | Hernán |
| `movil/casos_sqlite.sql` | 2.c ejecución de los casos C2–C6 en SQLite | Hernán |
| `docs/2c_casos_y_3a_mapa.md` | 2.c explicación de casos C2–C6 y 3.a mapa de 3 motores | Hernán |
| `docs/informe.pdf` | informe (máx. 6 páginas) | Hernán |
