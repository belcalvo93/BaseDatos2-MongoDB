# Tasks — TP8 Food Store: Base SQLite y Semáforo de Sincronización

**Proyecto:** Trabajo Práctico N.º 8 — Base de Datos II  
**Grupo:** Belén Calvo, Elías Tello, Hernán González, Bruno Fiouchetta  
**Fecha:** Noviembre 2026

---

## Introducción

El código de todas las tareas lo **genera OpenCode (agente Build)** a partir de esta especificación (`requirements.md` y `design.md`). Cada script se **lee completo, se prueba en el motor y se verifica antes de commitear**. No se acepta código generado sin revisión. Lo que la IA propone, se acepta, se corrige o se descarta queda anotado en `food-store/docs/bitacora_ia.md`.

Todas las rutas son relativas a la carpeta `food-store/`.

---

## Tareas

### [ ] Tarea 1: Vista `v_snapshot_movil` en PostgreSQL

**Archivo:** `postgresql/10_snapshot_catalogo.sql`  
**Responsable:** Elías (Bloque B)  
**Requisito relacionado:** REQ-01, REQ-02 (el semáforo compara contra lo que exporta esta vista)  
**Descripción:**
- Antes de escribirla, verificar las columnas reales con `\d producto` y `\d categoria` en `bd2_tp8`.
- Crea la vista `v_snapshot_movil` en `bd2_tp8` (copia de `bd2_tp3`; nunca sobre `bd2_tp3`).
- `producto_id` = `id_producto`.
- `precio_centavos` = `round(precio * 100)::INTEGER`.
- `disponible` = `activo AND stock > 0`.
- `eliminado` = `NOT activo` (lápida: los productos dados de baja **también** viajan).
- `capturado_en` = `now()`.
- Elegir y anotar los **productos fijos** para los casos (tabla de la sección 7 del contexto) y pasarlos al grupo.

**Verificación:**
```sql
-- psql -U postgres -d bd2_tp8
SELECT * FROM v_snapshot_movil LIMIT 5;
-- Esperado: producto_id, nombre, precio_centavos (entero), stock, disponible (t/f), eliminado (t/f), capturado_en
SELECT count(*) FROM v_snapshot_movil WHERE eliminado;
-- Esperado: incluye los productos con activo = false (no se filtran)
```

---

### [ ] Tarea 2: Esquema SQLite con 5 tablas STRICT

**Archivo:** `movil/schema_sqlite.sql`  
**Responsable:** Belén (Bloque A)  
**Requisito relacionado:** REQ-04 (restricciones CHECK y FK) y base de todos los demás  
**Descripción:**
- Comienza con `PRAGMA foreign_keys = ON;`.
- Crea **5** tablas STRICT con los nombres exactos de la sección 5 del contexto:
  - `snapshot_servidor`: copia del CSV, booleanos como TEXT `'t'`/`'f'`.
  - `producto_cache`: copia del catálogo en la tablet, **incluidas las lápidas**; booleanos como INTEGER 0/1.
  - `pedido_borrador`: cabecera del borrador.
  - `item_borrador`: líneas del borrador, PK `(id_local, producto_id)`.
  - `cola_sync`: cola de envíos con estado y motivo.
- Crea el índice único parcial `ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE'`.
- Crea la vista `v_catalogo_disponible` (solo `eliminado = 0 AND disponible_visto = 1`).
- Se puede correr sobre una base vacía sin errores.

**Verificación:**
```sql
-- sqlite3 foodstore_movil.db
.read schema_sqlite.sql
PRAGMA foreign_keys;        -- esperado: 1
PRAGMA integrity_check;     -- esperado: ok
SELECT count(*) FROM sqlite_master
WHERE type = 'table'
  AND name IN ('snapshot_servidor','producto_cache','pedido_borrador','item_borrador','cola_sync');
-- esperado: 5
SELECT name, strict FROM pragma_table_list WHERE schema = 'main' AND name NOT LIKE 'sqlite_%';
-- esperado: strict = 1 en las 5 tablas
```

---

### [ ] Tarea 3: Exportar la instantánea, importarla y cargar el caché

**Archivos:** `movil/servidor_snapshot.csv` y `movil/importar_catalogo.sql`  
**Responsable:** Elías (Bloque B)  
**Requisito relacionado:** REQ-02 (lápida del caso C4)  
**Descripción:**
- **En psql** (paso aparte, documentado en el README), desde la carpeta `movil/`:
  `\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER`
- **En SQLite**, el script `importar_catalogo.sql` (se corre con `.read`):
  - `PRAGMA foreign_keys = ON;`
  - `DELETE FROM snapshot_servidor;` (cada instantánea nueva reemplaza la anterior)
  - `.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor`
  - `INSERT INTO producto_cache … SELECT … FROM snapshot_servidor WHERE true ON CONFLICT (producto_id) DO UPDATE SET …` (upsert: la lápida actualiza la fila, no la borra).
- Anotar la fecha de la copia (`capturado_en`).

**Verificación:**
```sql
SELECT count(*) FROM snapshot_servidor;        -- esperado: igual a las filas del CSV
SELECT count(*) FROM producto_cache;           -- esperado: >= snapshot_servidor (no se borran filas)
SELECT count(*) FROM v_catalogo_disponible;    -- esperado: <= producto_cache (excluye bajas y sin stock)
SELECT DISTINCT capturado_en FROM snapshot_servidor;   -- fecha de la copia
```

---

### [ ] Tarea 4: Pruebas SQLite (transacciones, C1 y C7)

**Archivo:** `movil/pruebas_sqlite.sql`  
**Responsable:** Belén (Bloque A)  
**Requisito relacionado:** REQ-04  
**Descripción:**
- **Prueba 1 · Borrador completo con COMMIT:** `BEGIN;` → `pedido_borrador` + `item_borrador` + `cola_sync` → `COMMIT;`. UUIDs fijos: `aaaaaaaa-0000-4000-8000-000000000001` (borrador) y `bbbbbbbb-0000-4000-8000-000000000001` (solicitud). Verificar que quedó una fila en cada tabla.
- **Prueba 2 · Operación deshecha con ROLLBACK:** `BEGIN;` → un **segundo borrador completo** (`aaaaaaaa-…-000000000002`, con su ítem y su solicitud) → `ROLLBACK;`. Verificar con `COUNT(*)` que las tres tablas quedaron igual que antes.
- **Prueba 3 · C1 (catálogo sin servidor):** `SELECT * FROM v_catalogo_disponible;` sin ninguna conexión a PostgreSQL. Esperado: solo productos con `disponible_visto = 1` y `eliminado = 0`.
- **Prueba 4 · C7 (datos inválidos):**
  - `COUNT(*)` de las tres tablas **antes**.
  - `BEGIN;` → `pedido_borrador` válido → `item_borrador` con `cantidad = 0` → error CHECK → `ROLLBACK;`.
  - `BEGIN;` → `pedido_borrador` válido → `item_borrador` con un `producto_id` que no está en `producto_cache` → error FOREIGN KEY → `ROLLBACK;`.
  - `COUNT(*)` de las tres tablas **después**: iguales a los de antes.
  - El `ROLLBACK` es explícito: en SQLite el error solo deshace la sentencia que falló (ver design.md 4.5).

**Verificación:**
- Las únicas fallas son las dos esperadas del C7 (CHECK y FOREIGN KEY).
- Los `COUNT(*)` antes y después del C7 y de la prueba 2 son idénticos.
- Guardar la salida con `.output` como evidencia.

---

### [ ] Tarea 5: Semáforo (evaluación de solicitudes PENDIENTE)

**Archivo:** `movil/semaforo.sql`  
**Responsable:** Elías (Bloque B)  
**Requisito relacionado:** REQ-01, REQ-02, REQ-03  
**Descripción:**
- Toma solo las solicitudes con `estado = 'PENDIENTE'` en `cola_sync`.
- Para cada una, `item_borrador LEFT JOIN snapshot_servidor` y agrupa por solicitud.
- Reglas (en este orden):
  1. **Rojo (`RECHAZADO`):** `s.producto_id IS NULL` OR `disponible = 'f'` OR `eliminado = 't'` OR `cantidad > stock`.
  2. **Amarillo (`CONFLICTO`):** no hay rojo AND `precio_centavos_visto <> precio_centavos`.
  3. **Verde (`SIMULADO_APROBADO`):** ni rojo ni amarillo.
- Si hay rojo y amarillo en la misma solicitud, gana el rojo.
- Actualiza `cola_sync` con estado y un `motivo` que diga qué producto y por qué.
- No se conecta ni modifica nada en PostgreSQL.

**Verificación:**
```sql
.read semaforo.sql
SELECT count(*) FROM cola_sync WHERE estado = 'PENDIENTE';   -- esperado: 0
SELECT solicitud_uuid, estado, motivo FROM cola_sync;        -- estado y motivo legibles
.read semaforo.sql                                           -- correrlo otra vez
SELECT solicitud_uuid, estado, motivo FROM cola_sync;        -- esperado: exactamente lo mismo (REQ-03)
```

---

### [ ] Tarea 6: Casos C2–C6 y consulta final

**Archivo:** `postgresql/casos_servidor.sql` + salidas de cada caso  
**Responsable:** Hernán (Bloque C)  
**Requisito relacionado:** REQ-01 (C2), REQ-02 (C3, C4), REQ-03 (C6); C5 es el caso verde  
**Descripción:**
- Usa los **productos fijos** que eligió Elías en la Tarea 1.
- **Antes de empezar:** consulta inicial en `bd2_tp8` (`SELECT count(*) FROM pedido;` y stock de los productos fijos).
- Para cada caso:
  1. Crear el borrador en SQLite (transacción, UUIDs fijos).
  2. Preparar el cambio en `bd2_tp8` si corresponde (C2: subir el precio; C4: `activo = false`). Estos cambios son preparación manual del caso, no parte de la simulación.
  3. Exportar una instantánea nueva y correr `importar_catalogo.sql` (Tarea 3).
  4. Correr `semaforo.sql` y mostrar `cola_sync`.
  5. Escribir comando, resultado y 1–2 oraciones de explicación.
- Detalles por caso:
  - **C2:** primero `CONFLICTO`; después el cliente acepta: `UPDATE item_borrador SET precio_centavos_visto = <nuevo>` y una **solicitud nueva** (otro UUID) → `SIMULADO_APROBADO`.
  - **C3:** cantidad mayor que el stock → `RECHAZADO`; el stock del servidor no se toca.
  - **C4:** `RECHAZADO`; el producto ya no aparece en `v_catalogo_disponible`, pero la fila sigue en `producto_cache` con `eliminado = 1`.
  - **C5:** sin cambios → `SIMULADO_APROBADO` (simulación, no venta).
  - **C6:** reinsertar una solicitud con el mismo `solicitud_uuid` → error de clave primaria; volver a correr el semáforo no cambia su estado. Agregar la oración de la parada 8 (la protección real va en el servidor: clave única + misma transacción).
- **Consulta final:** repetir la consulta inicial después de la simulación. Esperado: la cantidad de pedidos no cambió y el stock solo cambió donde se preparó a mano un caso (documentado).

**Verificación:**
- Cada caso tiene comando, resultado y explicación.
- La consulta final demuestra que la simulación no creó pedidos ni cambió stock.

---

### [ ] Tarea 7: README.md (orden de creación desde cero)

**Archivo:** `README.md` (dentro de `food-store/`)  
**Responsable:** Elías (Bloque B)  
**Descripción:**
- Requisitos: PostgreSQL 16+, SQLite 3.37+ (`sqlite3 --version`), `psql` en el PATH.
- Orden, con comandos listos para copiar y pegar:
  1. Copiar la base: `createdb -U postgres -T bd2_tp3 bd2_tp8`.
  2. Crear la vista: `psql -U postgres -d bd2_tp8 -f postgresql/10_snapshot_catalogo.sql`.
  3. Crear la base de la tablet: `sqlite3 movil/foodstore_movil.db ".read movil/schema_sqlite.sql"`.
  4. Exportar la instantánea con `\copy` (Tarea 3).
  5. Importar y cargar el caché: `.read importar_catalogo.sql`.
  6. Correr `pruebas_sqlite.sql` (C1, C7, transacciones).
  7. Casos C2–C6 según la Tarea 6 y `semaforo.sql`.
  8. Consulta final de pedidos y stock.
- Notas: `PRAGMA foreign_keys = ON` en cada conexión; `sqlite3` sin nombre de archivo abre una base en memoria.

**Verificación:**
- Otro integrante sigue el README paso a paso en su compu, desde una base vacía, sin hacer preguntas.

---

## Notas generales

- **Código generado:** OpenCode (agente Build) genera cada script a partir de esta especificación; cada script se revisa completo antes de commitear.
- **Pruebas en el motor:** cada tarea tiene su verificación en `sqlite3` o `psql`.
- **Code review (Bruno, Bloque D):** no genera tareas de esta spec; revisa con OpenCode (agente **Plan**) todos los scripts de la cursada, incluidos los de estas tareas cuando estén terminados.
- **Ramas:** `tp8-belen`, `tp8-elias`, `tp8-hernan`, `tp8-bruno`; PR a `main`.
- **Bitácora:** cada integrante anota sus entradas en `docs/bitacora_ia.md`.

---

## Matriz de trazabilidad

| Tarea | Archivo | Responsable | REQ-01 | REQ-02 | REQ-03 | REQ-04 | Casos |
|:---:|---|:---:|:---:|:---:|:---:|:---:|:---:|
| 1 | `postgresql/10_snapshot_catalogo.sql` | Elías | ✓ | ✓ | — | — | — |
| 2 | `movil/schema_sqlite.sql` | Belén | — | — | ✓ | ✓ | C1, C7 |
| 3 | `movil/importar_catalogo.sql` | Elías | — | ✓ | — | — | C4 |
| 4 | `movil/pruebas_sqlite.sql` | Belén | — | — | — | ✓ | C1, C7 |
| 5 | `movil/semaforo.sql` | Elías | ✓ | ✓ | ✓ | — | C2–C6 |
| 6 | `postgresql/casos_servidor.sql` | Hernán | ✓ | ✓ | ✓ | — | C2–C6 |
| 7 | `README.md` | Elías | — | — | — | — | — |
