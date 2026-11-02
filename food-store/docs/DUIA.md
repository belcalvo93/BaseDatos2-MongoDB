# DUIA — Declaración de Uso de Inteligencia Artificial (TP8 · Unidad 8)

**Asignatura:** Base de Datos II · Tecnicatura Universitaria en Programación (UTN-FRM)  
**Profesor:** Sergio Neira  
**Proyecto integrador:** Food Store — La base de la tablet (SQLite) y cierre de la capa de datos  
**Período:** Noviembre 2026  
**Integrantes del grupo:** Belén Calvo, Elías Tello, Hernán González, Bruno Fiouchetta  

---

## 1. Regla de trabajo del equipo

En cumplimiento de la pauta de la cátedra (*"se delega la escritura, nunca la decisión"*):

1. **Kiro** se utiliza para redactar y ajustar la especificación previa (`requirements.md` en notación EARS, `design.md` y `tasks.md`).
2. **OpenCode (agente Build)** propone los scripts SQL a partir de las tareas aprobadas en la spec.
3. **OpenCode (agente Plan)** y **Gemini (Antigravity) / Claude Code** se utilizan en modo de revisión, análisis y apoyo para documentación.
4. **Validación humana obligatoria:** cada integrante lee línea por línea el código generado, lo ejecuta sobre una base de prueba (`bd2_tp8` o `foodstore_movil.db`, nunca sobre `bd2_tp3`), comprueba el resultado en el motor y descarta o corrige todo lo que contradiga las reglas de negocio.
5. **Privacidad:** no se envían contraseñas, correos reales ni datos personales en ningún prompt ni se incluyen en la base SQLite o en los archivos CSV.

---

## 2. Registro consolidado de uso de IA por bloque

### Bloque A — Spec en Kiro, datos que viajan, esquema y pruebas SQLite (Belén Calvo)

| Fecha | Herramienta | Propósito | Qué se le dio (Input) | Qué devolvió (Output) | Decisión | Motivo y comprobación en el motor |
|---|---|---|---|---|---|---|
| 01/11/2026 | Kiro | Generar `requirements.md` (4.a) | Contexto del TP8 y pedido de 4 requisitos EARS vinculados a C2, C3/C4, C6 y C7 | 4 requisitos EARS con trazabilidad a los casos | **Aceptado con correcciones** | Se cambió `WHERE` por `IF … THEN` en comportamientos no deseados, se corrigió que la sincronización tiene dos movimientos (bajar instantánea y subir envíos), se corrigió la cita a Ley 25.326 y se movió de `.kiro/steering/` a `.kiro/specs/tp8-tablet/`. En SQLite se comprobó que tras un fallo de `CHECK` la transacción sigue abierta, por lo que se exigió `ROLLBACK` explícito en REQ-04. |
| 01/11/2026 | Kiro | Generar `design.md` (4.a) | `requirements.md` y contexto del proyecto | Arquitectura en Mermaid, 5 tablas STRICT, índice parcial, vista y reglas del semáforo | **Aceptado con correcciones** | Se corrigió la afirmación de que SQLite deja la transacción "en estado fallido" (eso es PostgreSQL; SQLite solo deshace la sentencia que falló), se incluyó la aceptación del precio nuevo para C2 y se vinculó el índice parcial con REQ-01 (reenvío en C2). |
| 01/11/2026 | Kiro | Generar `tasks.md` (4.a) | `requirements.md` y `design.md` | Plan de 7 tareas con verificaciones y matriz de trazabilidad | **Reescrito / Corregido** | Al guardar, Kiro truncó caracteres en nombres de objetos y archivos; se reescribió completo y se separó `\copy` (psql) de `.import` (SQLite), se corrigió la prueba de `ROLLBACK` con un segundo borrador y se usó `pragma_table_list` (`strict = 1`). |
| 01/11/2026 | OpenCode (agente Build) | Generar `food-store/movil/schema_sqlite.sql` (1.b) | Tarea 2 de `tasks.md` y `design.md` | Script idempotente con `PRAGMA foreign_keys = ON;`, 5 tablas `STRICT`, índice único parcial y vista | **Aceptado con 1 descarte** | Se descartó el cambio de OpenCode que usaba `printf('%d.%02d', ...)` en `v_catalogo_disponible` en lugar de `precio_centavos / 100.0`: la vista no almacena datos y el texto impide ordenar por precio. Comprobado en `sqlite3`: corre dos veces sin error, `PRAGMA integrity_check = ok` y `strict = 1` en las 5 tablas. |
| 01/11/2026 | OpenCode (agente Build) | Generar `food-store/movil/pruebas_sqlite.sql` (1.c) | Tarea 4 de `tasks.md` | Pruebas de `COMMIT`, `ROLLBACK`, C1 y C7 con conteos antes y después | **Aceptado con 1 ajuste** | Se quitó un `SELECT … WHERE 0` innecesario. Comprobado en `sqlite3` (`food-store/evidencias/salida_pruebas_sqlite.txt`): conteos `1/1/1` tras `COMMIT`, invariantes en `ROLLBACK` y C7, y solo los dos errores esperados (`CHECK` y `FOREIGN KEY`). |

### Bloque B — Instantánea, importación, semáforo y README (Elías Tello)

| Fecha | Herramienta | Propósito | Qué se le dio (Input) | Qué devolvió (Output) | Decisión | Motivo y comprobación en el motor |
|---|---|---|---|---|---|---|
| 01/11/2026 | Claude Code | Generar `10_snapshot_catalogo.sql`, `importar_catalogo.sql`, `semaforo.sql`, `README.md` y elegir productos fijos (Tareas 1, 3, 5 y 7) | `.kiro/specs/tp8-tablet/` y columnas reales en `bd2_tp8` (`\d producto`, `\d categoria`) | Vista con precio en centavos y lápida, upsert al caché, semáforo con `LEFT JOIN` y productos fijos 3, 2, 11, 9 y 10 | **Aceptado con 2 correcciones y 1 descarte** | 1) Con `\d categoria` se vio que `categoria` también tiene `activo` (`Congelados` dada de baja): se cambió a `eliminado = NOT p.activo OR NOT c.activo` (viajan 10.048 lápidas en vez de 1). 2) En `semaforo.sql` se cubrió el borrador sin ítems (`RECHAZADO`) y la instantánea vacía (no evaluar). 3) Se descartó la guarda `SELECT CASE WHEN current_database() <> 'bd2_tp8' THEN 1/0 END` porque PostgreSQL evalúa la constante `1/0` al planificar aunque no entre en esa rama; se reemplazó por `DO $$ … RAISE EXCEPTION`. |

### Bloque C — Casos C2–C6, consulta final, mapa de 3 motores e informe (Hernán González)

| Fecha | Herramienta | Propósito | Qué se le dio (Input) | Qué devolvió (Output) | Decisión | Motivo y comprobación en el motor |
|---|---|---|---|---|---|---|
| 01/11/2026 | OpenCode (agente Build) | Generar `casos_servidor.sql`, `casos_sqlite.sql` y `2c_casos_y_3a_mapa.md` (Tarea 6 y 3.a) | `.kiro/specs/tp8-tablet/`, productos fijos del Bloque B (3, 2, 11 y 9) y `semaforo.sql` | Preparación de C2 y C4 en `bd2_tp8`, corridas C2–C6 en SQLite, consulta de control en PostgreSQL y mapa de 3 motores | **Aceptado con 2 correcciones y 1 descarte** | 1) En `casos_sqlite.sql` se reordenó C6 para correr primero la reejecución idempotente de `semaforo.sql` con `.bail on` y al final el duplicado de `solicitud_uuid` con `.bail off` (porque `process_input()` en SQLite acumula `errCnt` y aborta si se reactiva `.bail on` tras un error). 2) Se verificó que la solicitud `205` estuviera en `SIMULADO_APROBADO` antes de reinsertar el mismo UUID para que falle por `PRIMARY KEY`. 3) Se descartó dejar el CSV intermedio modificado en el repo. Comprobado en `bd2_tp8` (`200005` pedidos antes y después) y `foodstore_movil.db` (`PRAGMA integrity_check = ok`). |

### Bloque D — Plan de mantenimiento, Code Review y consolidación de Bitácora/DUIA (Bruno Fiouchetta)

| Fecha | Herramienta | Propósito | Qué se le dio (Input) | Qué devolvió (Output) | Decisión | Motivo y comprobación en el motor |
|---|---|---|---|---|---|---|
| 01/11/2026 | Gemini (Antigravity) | Redactar `food-store/docs/3b_plan_mantenimiento.md` (3.b) | Consigna 3.b del TP8, `contexto_tp8_equipo.md` y scripts reales de la Unidad 6 (`SPEC_U6.md`, `backup_foodstore.sh`, `restore_test.sh`) | Respuesta a las 3 preguntas de mantenimiento integrando PostgreSQL, MongoDB y SQLite | **Aceptado** | Se verificó que referencie los artefactos reales de la U6 (`.conteo`, `foodstore_restore_test`, `RPO = 24 h`, `RTO = 15 min`), descarte respaldar tablas de caché regenerables en SQLite y defina la recarga obligatoria de `v_snapshot_movil` si se restaura un backup viejo de PostgreSQL. |
| 01/11/2026 | OpenCode (agente Plan) + Gemini (Antigravity) | Revisión de scripts de la cursada y redacción de `food-store/docs/3c_code_review_ia.md` (3.c) | Scripts de U1–U6 (`base-datos-2`), U7 y U8 (`BaseDatos2-MongoDB`) y auditorías en modo Plan | Tabla de 10 hallazgos con decisiones y desarrollo de 4 casos (U7, U6, U5/U3 y U8) | **Aceptado con descartes fundados** | Se incluyeron 2 hallazgos corregidos (U6 `usuario` en `ANALYZE` y `.conteo`; U5/U3 revocación de `INSERT/UPDATE` directo y bloqueo de reseteo a `ADMIN`) y 2 propuestas de IA descartadas con prueba en motor (U7 índice único multikey que bloquea ventas con `E11000`; U8 `printf` en vista y `UNIQUE` total en `cola_sync`), además de descartar el falso positivo de OpenCode sobre `n_live_tup = 0` en `health_check.sql`. |
| 01/11/2026 | Gemini (Antigravity) | Consolidar `food-store/docs/bitacora_ia.md` y `food-store/docs/DUIA.md` (4.b) | Entradas 1 a 5 de Belén + Entrada 6 de Elías + Entrada 7 de Hernán + registros del Bloque D | Bitácora completa con las 9 entradas de los 4 bloques y documento DUIA consolidado | **Aceptado** | Verificado contra los requisitos de la consigna 4.b (todas las entradas de los 4 integrantes con qué se pidió, qué se aceptó, qué se descartó y por qué, más la DUIA). |

---

## 3. Apartamientos del flujo declarados

| Fecha | Integrante | Apartamiento | Justificación |
|---|---|---|---|
| 01/11/2026 | Elías Tello | Uso de Claude Code para generar los scripts del Bloque B (`10_snapshot_catalogo.sql`, `importar_catalogo.sql`, `semaforo.sql` y `README.md`) a partir de `tasks.md` | Se trabajó en una única sesión manteniendo la regla de delegar la escritura y no la decisión: el autor verificó primero con `\d` en `bd2_tp8`, corrigió la lógica de baja por categoría y la guarda de base de datos, y comprobó cada script en `psql` y `sqlite3`. |
| 01/11/2026 | Bruno Fiouchetta | Uso de Gemini (Antigravity) como asistente par junto con OpenCode (agente Plan) para estructurar el análisis de los puntos 3.b, 3.c y 4.b | En Windows, la invocación no interactiva de `opencode run --agent plan` queda en espera de confirmación de consola por la política `"bash": { "*": "ask" }` de `opencode.json`. Por eso se combinaron las auditorías en modo Plan de OpenCode ya ejecutadas en los repositorios con Gemini para consolidar la tabla transversal U1–U8 y la documentación, verificando cada afirmación contra las salidas reales de `psql`, `mongosh` y `sqlite3`. |

---

## 4. Declaración final del equipo

Declaramos que todo el código SQL y la documentación entregados en este Trabajo Práctico N.º 8 fueron leídos, probados en los motores correspondientes (`PostgreSQL` sobre `bd2_tp8` y `SQLite` sobre `foodstore_movil.db`) y comprendidos por los integrantes del grupo, quienes asumen la responsabilidad de explicar y defender cada decisión en la instancia oral.
