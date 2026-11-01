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
