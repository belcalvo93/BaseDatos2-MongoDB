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

## Entrada 6 · 01/11/2026 · Bruno Fiouchetta · Gemini (Antigravity) + OpenCode (agente Plan)

**Qué se pidió:** redactar el punto 3.b (`food-store/docs/3b_plan_mantenimiento.md`) como agregado al plan de la Unidad 6 (`SPEC_U6.md`, `backup_foodstore.sh` y `restore_test.sh`), respondiendo qué se respalda en los tres motores y cómo se prueba la restauración, qué hacen las tablets si se restaura un respaldo viejo de PostgreSQL y cada cuánto y quién revisa las solicitudes en `CONFLICTO` o `RECHAZADO`.

**Qué se aceptó:** la integración de los tres motores apoyada en los scripts reales de la Unidad 6 (`backup_foodstore.sh` con `pg_dump -Fc` y archivo `.conteo`, `restore_test.sh` sobre `foodstore_restore_test`), el procedimiento ante un respaldo viejo del servidor (publicar una nueva instantánea `v_snapshot_movil`, recargar `producto_cache` con `importar_catalogo.sql` y volver a evaluar las solicitudes) y la separación de responsabilidades entre el vendedor (en la feria, junto al cliente, para `CONFLICTO` y `RECHAZADO`) y el responsable de operaciones (cierre diario antes del backup nocturno).

**Qué se descartó:** no se propuso respaldar `producto_cache` ni `snapshot_servidor` de SQLite, porque son copias derivadas cuya fuente de verdad es PostgreSQL y se regeneran desde `v_snapshot_movil`; en la tablet solo importa resguardar `pedido_borrador`, `item_borrador` y `cola_sync` cuando quedan envíos pendientes de cierre.

**Cómo se comprobó:** se verificó contra `mantenimiento/SPEC_U6.md` y `mantenimiento/restore_test.sh` en el repositorio `base-datos-2` que los nombres de scripts, archivos `.conteo`, base descartable `foodstore_restore_test` y métricas (`RPO = 24 h`, `RTO = 15 min`) coincidan exactamente con lo implementado y medido en la Unidad 6.

---

## Entrada 7 · 01/11/2026 · Bruno Fiouchetta · OpenCode (agente Plan) + Gemini (Antigravity)

**Qué se pidió:** realizar el code review de los scripts de la cursada (punto 3.c, `food-store/docs/3c_code_review_ia.md`) revisando los repositorios `base-datos-2` (U1–U6) y `BaseDatos2-MongoDB` (U7–U8), consolidar la tabla de hallazgos con su decisión (`Corregido`, `Aceptado` o `Descartado`) y desarrollar 4 hallazgos de unidades distintas (U7, U6, U5/U3 y U8) con su comprobación en el motor.

**Qué se aceptó:** la tabla de 10 hallazgos que recorre todas las unidades y el desarrollo de 4 casos verificados en motor:
1. U7 (MongoDB): descarte del índice único multikey `{"lineas.id_producto": 1}` y reemplazo por `$jsonSchema` con `$expr` y `$setUnion`.
2. U6 (PostgreSQL): inclusión de `usuario` en `maintenance.sql` y validación contra `.conteo` en `restore_test.sh`.
3. U5/U3 (PostgreSQL): revocación de `INSERT, UPDATE` directo sobre `pedido` y `detalle_pedido` para `rol_app_escritura` (dejando solo `CALL registrar_pedido`) y bloqueo de reseteo de cuentas `ADMIN` en `fn_resetear_password`.
4. U8 (SQLite): descarte de `printf` como texto en `v_catalogo_disponible` y de `UNIQUE(id_local)` total en `cola_sync`.

**Qué se descartó:**
- El hallazgo de OpenCode en U6 que marcaba como defecto que `health_check.sql` mostrara `n_live_tup = 0` tras `createdb -T`: se descartó porque ese `0` refleja el comportamiento real de PostgreSQL al clonar una base sin copiar estadísticas dinámicas y fue la señal que justificó correr `ANALYZE`.
- La ejecución no interactiva de `opencode run --agent plan` desde una subshell sin TTY: como `opencode.json` tiene `"bash": { "*": "ask" }`, el comando espera confirmación interactiva y queda bloqueado; la revisión se apoya en las corridas en modo Plan y las comprobaciones directas en `psql`, `mongosh` y `sqlite3`.

**Cómo se comprobó:** cada uno de los 4 hallazgos desarrollados cuenta con su evidencia de ejecución en el motor: `evidencias/salida_prueba_indice_unico_ia.txt` (`mongosh`, U7), `mantenimiento/evidencias/maintenance_salida.txt` y `restore_test_v2_salida.txt` (`psql`, U6), pruebas con `SET ROLE` dentro de `BEGIN … ROLLBACK` (`psql`, U5) y `food-store/evidencias/salida_pruebas_sqlite.txt` (`sqlite3`, U8).

