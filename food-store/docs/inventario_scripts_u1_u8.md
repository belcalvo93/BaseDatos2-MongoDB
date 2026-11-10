# Inventario de scripts de la cursada (U1 a U8)

Lista de **todos los scripts ejecutables** del proyecto Food Store (`.sql`, `.sh`, `.ps1` y `.js`), en los dos repositorios. Es la base del code review de la consigna 3.c (`docs/3c_code_review_ia.md`) y del Objetivo 13 del TPI: la revisión con OpenCode (agente Plan) cubre todos los scripts de esta lista, sin que ninguno quede sin registro de revisión.

| Repositorio | Unidades | Enlace |
|---|---|---|
| `base-datos-2` (relacional) | U1 a U6 | https://github.com/belcalvo93/base-datos-2 |
| `BaseDatos2-MongoDB` (documental y móvil) | U7 y U8 | https://github.com/belcalvo93/BaseDatos2-MongoDB |

**Cómo leer la tabla**
- **Base:** dónde se corre. Ninguno de los scripts que cambian datos se corre sobre `bd2_tp3` ni sobre `foodstore`: cada TP trabaja sobre su copia (`bd2_trabajo`, `bd2_tp4u4`, `bd2_tp5u5`, `foodstore_restore_test`, `bd2_tp8`).
- **Cómo se corre:** `psql -U postgres -d <base> -f <ruta>`, `bash <ruta>`, `powershell -ExecutionPolicy Bypass -File <ruta>`, `mongosh --file <ruta>` o `sqlite3 <base>.db ".read <ruta>"`, según el motor.
- **Revisión / Hallazgo 3.c:** número de la fila en la tabla de hallazgos de [`3c_code_review_ia.md`](3c_code_review_ia.md) o estado `"Revisado sin observaciones (08/11/2026)"`, junto con el informe detallado por unidad en [`docs/tpi_parcial2/review/` en base-datos-2](https://github.com/belcalvo93/base-datos-2/tree/main/docs/tpi_parcial2/review) (`review_u1.md` a `review_u8.md`, y `mantenimiento/revision_opencode.md` / `revision_opencode_v2.md` para U6).

---

## Repositorio `base-datos-2` (U1 a U6)

### Unidad 1 · Modelo, normalización, restricciones y concurrencia (`review_u1.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `food-store/schema.sql` | Crea las tablas del núcleo (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`) con PK, FK y tipos | copia de trabajo | Revisado sin observaciones (08/11/2026) · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `food-store/data.sql` | Datos de carga inicial del esquema del TP1 | copia de trabajo | Revisado sin observaciones (08/11/2026) · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `food-store/verificacion_normalizacion.sql` | Consultas de solo lectura que verifican la normalización del esquema | `bd2_tp3` (solo lee) | Revisado sin observaciones (08/11/2026) · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `food-store/restricciones.sql` | Restricciones de integridad de las reglas de negocio (CHECK, UNIQUE, triggers) | copia de trabajo | Hallazgo 12 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `food-store/pruebas_restricciones.sql` | Prueba cada restricción con casos válidos e inválidos | copia de trabajo | Hallazgo 12 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `food-store/procedimientos.sql` | Procedimiento `registrar_pedido` (alta de pedido con validación de stock) | copia de trabajo | Hallazgos 1, 2 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `concurrencia/escenario0_atomicidad.sql` | Atomicidad: COMMIT y ROLLBACK | `bd2_trabajo` | Hallazgo 2 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `concurrencia/escenario1_lectura_no_repetible_sesionA.sql` · `…_sesionB.sql` | Lectura no repetible entre dos sesiones | `bd2_trabajo` | Hallazgo 2 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `concurrencia/escenario2_lectura_fantasma_sesionA.sql` · `…_sesionB.sql` | Lectura fantasma entre dos sesiones | `bd2_trabajo` | Hallazgo 2 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |
| `concurrencia/escenario3_espera_bloqueo_sesionA.sql` · `…_sesionB.sql` | Espera por bloqueo (`SELECT … FOR UPDATE`) | `bd2_trabajo` | Hallazgo 2 · [`review_u1.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u1.md) |

### Unidad 2 · Carga masiva (`review_u2.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `food-store/carga_masiva.sql` | Carga masiva de clientes, productos (~50.000), pedidos y detalle | copia de trabajo | Hallazgo 13 · [`review_u2.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u2.md) |
| `food-store/carga_masiva_bloque3_B.sql` | Variante B del bloque 3 (pedido → cliente), medida contra la A y descartada | copia de trabajo | Revisado sin observaciones (08/11/2026) · [`review_u2.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u2.md) |
| `food-store/verificacion_carga_masiva.sql` | Verificación de la carga, solo lectura | copia de trabajo | Hallazgo 13 · [`review_u2.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u2.md) |

### Unidad 3 · Índices, vistas y rendimiento (TP5) (`review_u3.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `food-store/indices.sql` | Índices aceptados después de medir | `bd2_trabajo` | Revisado sin observaciones (08/11/2026) · [`review_u3.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u3.md) |
| `food-store/queries.sql` | Consultas del proyecto, extraídas de los informes | `bd2_trabajo` | Revisado sin observaciones (08/11/2026) · [`review_u3.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u3.md) |
| `food-store/medicion_planes.sql` | `EXPLAIN (ANALYZE, BUFFERS)` antes y después de cada índice | `bd2_trabajo` | Revisado sin observaciones (08/11/2026) · [`review_u3.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u3.md) |
| `food-store/medicion_escritura.sql` | Costo de los índices sobre INSERT y UPDATE | `bd2_trabajo` | Revisado sin observaciones (08/11/2026) · [`review_u3.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u3.md) |
| `food-store/views.sql` | Vistas (`vista_cliente_completo`, vista de reportes sin contraseña) | `bd2_tp3` | Hallazgo 14 · [`review_u3.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u3.md) |
| `food-store/materializadas.sql` | Vista materializada de facturación por categoría y mes | copia de trabajo | Hallazgo 14 · [`review_u3.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u3.md) |

### Unidad 4 · FNBC y desnormalización controlada (`review_u4.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `food-store/tp_fnbc_control_lote.sql` | Esquema heredado `control_lote_almacen`, anomalías, descomposición FNBC, migración y verificación con `EXCEPT` (en `BEGIN … ROLLBACK`) | `bd2_tp4u4` | Revisado sin observaciones (08/11/2026) · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/tp_fnbc_reversion.sql` | Reversión transaccional de la migración a FNBC hacia `control_lote_almacen` respetando el orden de FK sin `CASCADE` y doble `EXCEPT` | `bd2_tp4u4` | Hallazgo 15 · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/carga_pedidos_hoy.sql` | Carga pedidos del día (insumo de la Parte 2) | `bd2_tp4u4` | Hallazgo 15 · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/medicion_top_categorias_antes.sql` | Medición basal antes de desnormalizar | `bd2_tp4u4` | Hallazgo 15 · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/tp_desnormalizacion_top_categorias.sql` | Resumen desnormalizado + triggers de sincronización | `bd2_tp4u4` | Hallazgo 3 · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/medicion_top_categorias_despues.sql` | Medición después de desnormalizar | `bd2_tp4u4` | Revisado sin observaciones (08/11/2026) · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/medicion_escritura_top_categorias.sql` | Costo de escritura del trigger de sincronización | `bd2_tp4u4` | Revisado sin observaciones (08/11/2026) · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/auditoria_top_categorias.sql` | Auditoría del resumen contra los datos base (esperado: 0 filas) | `bd2_tp4u4` | Hallazgo 15 · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |
| `food-store/tp_desnormalizacion_reversion.sql` | Reversión completa de la desnormalización | `bd2_tp4u4` | Revisado sin observaciones (08/11/2026) · [`review_u4.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u4.md) |

### Unidad 5 · Seguridad, roles y auditoría (`review_u5.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `sql/funciones_auth.sql` | Extensión `pgcrypto` y funciones de autenticación y reseteo de contraseña | `bd2_tp5u5` | Hallazgo 4 · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/mv_ventas_categoria_mes.sql` | Agregado del panel gerencial | `bd2_tp5u5` | Revisado sin observaciones (08/11/2026) · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/roles.sql` | Roles, usuarios y permisos (mínimo privilegio) | `bd2_tp5u5` | Hallazgo 1 · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/verificacion_roles.sql` | Verificación de permisos con `SET ROLE` | `bd2_tp5u5` | Hallazgo 16 · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/auditoria_test.sql` | Activación y prueba de la auditoría (`log_statement`) | `bd2_tp5u5` | Hallazgo 5 · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/simulacro_incidente.sql` | Simulacro de acceso indebido (fuerza bruta y escalada) | `bd2_tp5u5` | Revisado sin observaciones (08/11/2026) · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/simulacro_limpieza.sql` | Deja la base y el servidor como antes del simulacro | `bd2_tp5u5` | Revisado sin observaciones (08/11/2026) · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/anonimizar_log.sh` | Anonimiza el log del simulacro antes de pasárselo a la IA | `bd2_tp5u5` | Hallazgo 16 · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |
| `sql/usuario_anon.sql` | Tabla `usuario_anon` con datos sintéticos | `bd2_tp5u5` | Hallazgo 16 · [`review_u5.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u5.md) |

### Unidad 6 · Mantenimiento, respaldo y restauración (`revision_opencode.md` y `revision_opencode_v2.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `mantenimiento/conteo_referencia.sql` | Huella de 11 claves (filas de las 6 tablas, total facturado, tablas, vistas, restricciones, índices) | `foodstore` (solo lee) | Hallazgo 7 · rev. U6 (`revision_opencode_v2.md`) |
| `mantenimiento/backup_foodstore.sh` | Huella `.conteo` → `pg_dump -Fc` → `pg_restore -l` → `.sha256` → `pg_dumpall --globals-only` → retención 7 días; línea PASS/FAIL en el log | `foodstore` (solo lee) | Hallazgo 7 · rev. U6 (`revision_opencode_v2.md`) |
| `mantenimiento/restore_test.sh` | Verifica SHA256, pide autorización, restaura en la base descartable, valida huella 11/11 y 8 indicadores, mide RTO y RPO | `foodstore_restore_test` | Hallazgo 7 · rev. U6 (`revision_opencode_v2.md`) |
| `mantenimiento/maintenance.sql` | Diagnóstico de estadísticas y tuplas muertas; `ANALYZE` solo de las tablas pendientes; nunca `VACUUM FULL` | `foodstore` o `foodstore_restore_test` | Hallazgo 6 · rev. U6 (`revision_opencode_v2.md`) |
| `mantenimiento/health_check.sql` | Chequeo de salud (tamaño, conexiones, estado de tablas, consultas activas) | `foodstore` (solo lee) | Hallazgo 8 · rev. U6 (`revision_opencode_v2.md`) |
| `mantenimiento/programar_respaldo.ps1` · `quitar_respaldo.ps1` | Registra y elimina la tarea diaria de las 21:00 (`FoodStore_Backup_Diario`) en el Programador de tareas de Windows (`schtasks`) | Windows (`schtasks`) | Hallazgo 7 · rev. U6 (`belen_bitacora_duia.md`) |

---

## Repositorio `BaseDatos2-MongoDB` (U7 y U8)

### Unidad 7 · MongoDB (`review_u7.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `seleccion_pedidos.sql` | Selecciona en PostgreSQL los pedidos a migrar | `bd2_tp3` (solo lee) | Hallazgo 17 · [`review_u7.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u7.md) |
| `consultas_postgresql.sql` | Las 5 consultas de verificación en SQL | `bd2_tp3` (solo lee) | Hallazgo 17 · [`review_u7.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u7.md) |
| `consultas_mongodb.js` | Migración, validador `$jsonSchema`, las 5 consultas equivalentes y auditoría del total | MongoDB `foodstore` | Hallazgo 9 · [`review_u7.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u7.md) |
| `prueba_indice_unico_ia.js` | Evidencia de laboratorio contra el índice único multikey que propuso la IA | MongoDB `foodstore` | Hallazgo 9 · [`review_u7.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u7.md) |

### Unidad 8 · SQLite (la base de la tablet) (`review_u8.md`)

| Ruta | Qué hace | Base | Revisión / Hallazgo 3.c |
|---|---|---|---|
| `food-store/postgresql/10_snapshot_catalogo.sql` | Vista `v_snapshot_movil` (precio en centavos, lápidas) | `bd2_tp8` | Hallazgo 11 · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/movil/schema_sqlite.sql` | 6 tablas STRICT, índice único parcial y vista del catálogo | `foodstore_movil.db` | Hallazgo 10 · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/movil/importar_catalogo.sql` | Importa el CSV en `snapshot_servidor` y hace el upsert a `producto_cache` | `foodstore_movil.db` | Hallazgo 18 · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/movil/pruebas_sqlite.sql` | COMMIT, ROLLBACK, subtotal, C1 y C7 | `pruebas.db` | Revisado sin observaciones (08/11/2026) · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/movil/semaforo.sql` | Evalúa las solicitudes `PENDIENTE`, registra en `evaluacion_sync` y actualiza `cola_sync` | `foodstore_movil.db` | Hallazgo 11 · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/postgresql/casos_servidor.sql` | Prepara C2, C3 y C4 en el servidor y exporta la instantánea nueva | `bd2_tp8` | Revisado sin observaciones (08/11/2026) · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/movil/casos_sqlite.sql` | Casos C2 a C6 con el semáforo y el registro de evaluaciones | `foodstore_movil.db` | Hallazgo 18 · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |
| `food-store/postgresql/consulta_final.sql` | Pedidos y stock después de la simulación (sin cambios) | `bd2_tp8` (solo lee) | Revisado sin observaciones (08/11/2026) · [`review_u8.md`](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/review/review_u8.md) |

---

**Total:** 56 scripts originales de la cursada (44 en `base-datos-2` y 12 en `BaseDatos2-MongoDB`) + 3 scripts incorporados en el TPI (`tp_fnbc_reversion.sql`, `programar_respaldo.ps1` y `quitar_respaldo.ps1`) = **100 % revisados y documentados (0 scripts en «—»)**.
