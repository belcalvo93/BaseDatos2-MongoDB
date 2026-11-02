# Bitácora de uso de IA — TP8

Formato: fecha · quién · herramienta · qué se pidió · qué se aceptó · qué se corrigió o descartó y por qué · cómo se comprobó.

---

## Entrada 1 · 01/11/2026 · Belén Calvo · Kiro

**Qué se pidió:** generar `requirements.md` con 4 requisitos en notación EARS, cada uno con el caso que lo prueba (C2, C3/C4, C6, C7).

**Qué se aceptó:** los 4 requisitos y su relación con los casos de prueba; los nombres de columnas (coinciden con el esquema del apunte).

**Qué se corrigió:**
- Usó `WHERE` para las reglas "gana el rojo" (REQ-02) y "error de clave primaria" (REQ-03). En EARS, `WHERE` es para funciones opcionales; para comportamientos no deseados corresponde `IF … THEN THE SYSTEM SHALL …`.
- Dijo que la sincronización era unidireccional (tablet → servidor). La parada 5 la describe con dos movimientos: bajar la instantánea y subir los envíos.
- Citó la ley como "LPDA 25.326". El nombre correcto es Ley 25.326 de Protección de los Datos Personales.

**Qué se descartó:** guardó el archivo en `.kiro/steering/`, que es la carpeta de contexto fijo de Kiro. Se movió a `.kiro/specs/tp8-tablet/`.

**Cómo se comprobó:** en SQLite, dentro de un `BEGIN`, un INSERT con `cantidad = 0` falla por CHECK, pero las filas insertadas antes siguen ahí y la transacción sigue abierta. Por eso se agregó a REQ-04 que el `ROLLBACK` tiene que ser explícito en el script.

---

## Entrada 2 · 01/11/2026 · Belén Calvo · Kiro

**Qué se pidió:** generar `design.md` con arquitectura (diagrama mermaid), modelo de datos SQLite, lógica del semáforo y decisiones de diseño con su alternativa descartada.

**Qué se aceptó:** el diagrama, las 5 tablas STRICT con los nombres del contexto, el índice parcial, la vista del catálogo y las reglas del semáforo con "gana el rojo".

**Qué se corrigió:**
- Repitió que la sincronización es unidireccional (ya corregido en requirements.md): son dos movimientos, bajar la instantánea y subir los envíos.
- En la decisión del ROLLBACK dijo que la transacción "queda en estado fallido". Eso es comportamiento de PostgreSQL; en SQLite solo se deshace la sentencia que falló y la transacción sigue abierta y válida.
- Puso fuera de alcance "aceptar el precio nuevo", pero el caso C2 lo exige (actualizar el borrador y crear una solicitud nueva).
- Justificó el índice parcial con REQ-03 (idempotencia); el requisito que lo necesita es REQ-01 (reenvío tras conflicto, C2).

**Cómo se comprobó:** el diagrama mermaid se renderizó sin errores; el comportamiento de SQLite ante un error de CHECK dentro de una transacción se probó en la entrada 1.

---

## Entrada 3 · 01/11/2026 · Belén Calvo · Kiro

**Qué se pidió:** generar `tasks.md` con 7 tareas (archivo, requisito, responsable) a partir de requirements.md y design.md.

**Qué se aceptó:** la estructura de 7 tareas, la verificación en el motor por tarea y la matriz de trazabilidad.

**Qué se descartó:** el archivo tal como lo escribió Kiro. Al guardarlo se perdieron caracteres (`v_snapshot_movil` → `_snapshot_movil`, `bd2_tp8` → `d2_tp8`, `food-store` → `ood-store`, UUIDs incompletos, bloques de código rotos). Se reescribió.

**Qué se corrigió:**
- La prueba de ROLLBACK insertaba una segunda solicitud para el mismo borrador: habría fallado por el índice parcial `ux_cola_una_pendiente`. Se cambió por un segundo borrador completo.
- La verificación del esquema creaba una tabla `test` en la base real; se reemplazó por `pragma_table_list` (columna `strict`).
- Ponía el `\copy` (comando de psql) dentro de un script de SQLite; se separó en dos pasos.
- Decía "4 tablas" y listaba 5; asignaba a Hernán la elección de productos fijos (es del bloque B, Elías); faltaba la rama de Bruno.

**Cómo se comprobó:** se probó en SQLite que `pragma_table_list` devuelve `strict = 1` para una tabla STRICT.

---

## Entrada 4 · 01/11/2026 · Belén Calvo · OpenCode (agente Build)

**Qué se pidió:** generar `food-store/movil/schema_sqlite.sql` a partir de la Tarea 2 de `tasks.md` (PRAGMA, 5 tablas STRICT, índice parcial, vista del catálogo), con comentarios y que se pueda correr dos veces.

**Qué se aceptó:** las 5 tablas con los nombres exactos del contexto, las restricciones CHECK y FK, el índice único parcial `ux_cola_una_pendiente`, el bloque `DROP … IF EXISTS` en orden (vista, hijas, padres) y los comentarios explicativos.

**Qué se descartó:** en la vista `v_catalogo_disponible`, OpenCode cambió `precio_centavos / 100.0 AS precio` por `printf('%d.%02d', …)` para que "no aparezca ningún REAL". Se descartó: la regla de centavos INTEGER es para **guardar** precios; la vista no guarda nada, solo muestra un valor calculado desde un entero exacto. Además, el cambio se apartaba del apunte (parada 3) y del `design.md`. Se volvió a la versión del apunte.

**Cómo se comprobó:** se corrió el script dos veces seguidas sin error; `PRAGMA integrity_check` dio `ok`; `pragma_table_list` mostró `strict = 1` en las 5 tablas.

---

## Entrada 5 · 01/11/2026 · Belén Calvo · OpenCode (agente Build)

**Qué se pidió:** generar `food-store/movil/pruebas_sqlite.sql` a partir de la Tarea 4: borrador con COMMIT, borrador con ROLLBACK, C1 y C7 con conteos antes y después.

**Qué se aceptó:** las 5 pruebas tal como se pidieron; los 3 productos inventados (uno disponible, uno sin stock y una lápida con `disponible_visto = 1` a propósito, para comprobar que el filtro por `eliminado` funciona solo); el `ROLLBACK` explícito después de cada error del C7, con el comentario que explica por qué.

**Qué se corrigió:** se eliminó una consulta `SELECT … WHERE 0` que no devolvía filas ni aportaba nada a la salida.

**Cómo se comprobó:** se corrió sobre una base nueva (`pruebas.db`) con `schema_sqlite.sql`. Resultado en `food-store/evidencias/salida_pruebas_sqlite.txt`: 1/1/1 tras el COMMIT; antes = después en el ROLLBACK y en el C7; el catálogo muestra solo el producto 900001; aparecen solo los dos errores esperados (CHECK y FOREIGN KEY) y el script llega al final.

---

## Entrada 6 · 01/11/2026 · Elías Tello · Claude Code

**Qué se pidió:** a partir de las Tareas 1, 3, 5 y 7 de `tasks.md`, generar la vista `v_snapshot_movil` (`postgresql/10_snapshot_catalogo.sql`), la importación con upsert (`movil/importar_catalogo.sql`), el semáforo (`movil/semaforo.sql`) y el `README.md`, y proponer los productos fijos de los casos.

**Qué se aceptó:** la vista con precio en centavos enteros y la lápida que viaja; el upsert al caché; el semáforo con `LEFT JOIN` y el chequeo explícito `s.producto_id IS NULL`; los productos fijos 3, 2, 11, 9 y 10.

**Qué se corrigió:**
- La spec decía `eliminado = NOT activo`. Con `\d categoria` se vio que `categoria` también tiene `activo`, y que Congelados está dada de baja. Se cambió a `eliminado = NOT p.activo OR NOT c.activo` (y lo mismo en `disponible`). Así 10048 productos viajan como lápidas en vez de 1.
- Se agregaron dos casos borde que la spec no cubría: un borrador sin ítems queda `RECHAZADO` (si no, quedaba `PENDIENTE` para siempre) y, si no hay instantánea cargada, el semáforo no evalúa nada (si no, rechazaba todo como "producto inexistente").

**Qué se descartó:** el primer control para que la vista no se cree en `bd2_tp3` era `SELECT CASE WHEN current_database() <> 'bd2_tp8' THEN 1/0 END`. Falló también en `bd2_tp8`: PostgreSQL calcula la constante `1/0` al planificar la consulta, aunque esa rama del `CASE` nunca se use. Se reemplazó por un bloque `DO` con `RAISE EXCEPTION`.

**Cómo se comprobó:**
- La vista: en `bd2_tp8` da 50011 filas, 10048 lápidas y 39963 disponibles. Corrida sobre `bd2_tp3` corta con el error del `RAISE`, y `pg_views` confirma que en `bd2_tp3` no quedó ninguna vista.
- La importación: corrida dos veces seguidas da los mismos conteos (50011 / 50011 / 10048 / 39963).
- El semáforo: en una base de prueba, con los cambios del servidor simulados sobre `snapshot_servidor`, dio `CONFLICTO`, `RECHAZADO` (stock, baja, no disponible, inexistente, sin ítems, rojo + amarillo) y `SIMULADO_APROBADO` con el motivo correcto. Corrido dos veces dio una salida idéntica. Un `solicitud_uuid` repetido y dos `PENDIENTE` del mismo borrador dieron error de `UNIQUE`. `PRAGMA integrity_check` dio `ok`.
- El README: se siguió paso a paso desde una base de la tablet vacía.

---

## Entrada 7 · 01/11/2026 · Hernán González · OpenCode (agente Build)

**Qué se pidió:** a partir de la Tarea 6 de `tasks.md` y de los productos fijos del bloque B (3, 2, 11 y 9), generar `food-store/postgresql/casos_servidor.sql` (consulta inicial, preparación de C2 y C4 en `bd2_tp8`, reexportación del CSV y consulta final de pedidos y stock), `food-store/movil/casos_sqlite.sql` (ejecución completa de los casos C2 a C6 sobre `foodstore_movil.db` usando `importar_catalogo.sql` y `semaforo.sql`) y `food-store/docs/2c_casos_y_3a_mapa.md` (explicación de los casos C2–C6 con la frase de la parada 8 sobre idempotencia en el servidor y mapa de capas de datos de la consigna 3.a).

**Qué se aceptó:** los UUIDs fijos (`b0000000-...-000000000202` a `205` y `c0000000-...-000000000201` a `205`), el bloqueo de seguridad en `casos_servidor.sql` para abortar si la base no es `bd2_tp8`, el reenvío de C2 con actualización de `precio_unitario_centavos = 160000` y `total_centavos = 160000` más nueva fila en `cola_sync`, la comprobación de C4 en `v_catalogo_disponible` (`0`) vs. `producto_cache` (`eliminado = 1`), y el diagrama junto con la tabla comparativa de los tres motores (PostgreSQL, MongoDB y SQLite).

**Qué se corrigió:**
- En la primera versión de `casos_sqlite.sql`, la prueba C6 intentaba reinsertar `c0000000-0000-4000-8000-000000000205` con `.bail off` y enseguida volvía a activar `.bail on` (o llamaba a `.read movil/semaforo.sql`, que tiene `.bail on`). En el CLI de SQLite, `process_input()` acumula el contador de errores (`errCnt`) durante un `.read`; al reactivar `.bail on` con `errCnt > 0`, el script principal se abortaba antes de terminar C6. Se reordenó C6 para correr primero la parte a (reejecución idempotente de `semaforo.sql` con `.bail on`) y al final la parte b (inserción duplicada de `solicitud_uuid` con `.bail off`), seguida de las consultas de verificación e integridad.
- En C6.b se verificó que la solicitud `205` ya estuviera en estado `SIMULADO_APROBADO` antes de reintentar el `INSERT` con el mismo `solicitud_uuid`, para que el rechazo provenga exclusivamente de la `PRIMARY KEY (solicitud_uuid)` (`UNIQUE constraint failed: cola_sync.solicitud_uuid`) y no del índice parcial `ux_cola_una_pendiente`.

**Qué se descartó:** dejar `movil/servidor_snapshot.csv` modificado en el árbol de trabajo después de correr los casos, porque generaba un diff de 50011 líneas por el `capturado_en` de `now()` y alteraba los conteos iniciales del paso 5 del `README.md` (`10048` lápidas → `10049`). El script `casos_servidor.sql` exporta el CSV actualizado cuando se corre la prueba de C2–C6, y en el repositorio se conserva el CSV de la instantánea inicial para que el paso 5 siga siendo reproducible desde cero.

**Cómo se comprobó:**
- En PostgreSQL (`bd2_tp8`): se ejecutó `psql -U postgres -d bd2_tp8 -f postgresql/casos_servidor.sql`. Tanto al inicio como al final `SELECT count(*) FROM pedido` dio `200005` y los stocks de los productos `(2, 3, 9, 10, 11)` se mantuvieron en `(3, 40, 30, 0, 10)` (evidencia en `food-store/evidencias/salida_casos_servidor_postgresql.txt`). En `bd2_tp3` se verificó que el producto 3 sigue en `$1400.00` y el 11 en `activo = true`.
- En SQLite (`movil/foodstore_movil.db`): se ejecutó `sqlite3 movil/foodstore_movil.db ".read movil/casos_sqlite.sql"`. La primera corrida del semáforo dejó C2 en `CONFLICTO`, C3 y C4 en `RECHAZADO` y C5 en `SIMULADO_APROBADO`; el reenvío de C2 con `202b` dio `SIMULADO_APROBADO` conservando el historial de `201`; la segunda corrida del semáforo no alteró ninguna fila; y el duplicado de `solicitud_uuid` devolvió `Runtime error: UNIQUE constraint failed: cola_sync.solicitud_uuid (19)`. `PRAGMA foreign_key_check` dio vacío y `PRAGMA integrity_check` dio `ok` (evidencia en `food-store/evidencias/salida_casos_c2_c6_sqlite.txt`).

