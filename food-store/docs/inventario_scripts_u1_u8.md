# Inventario de scripts de la cursada (U1 a U8)

Lista de **todos los scripts ejecutables** del proyecto Food Store (`.sql`, `.sh` y `.js`), en los dos repositorios. Es la base del code review de la consigna 3.c (`docs/3c_code_review_ia.md`): la revisión con OpenCode (agente Plan) cubre los scripts de esta lista.

| Repositorio | Unidades | Enlace |
|---|---|---|
| `base-datos-2` (relacional) | U1 a U6 | https://github.com/belcalvo93/base-datos-2 |
| `BaseDatos2-MongoDB` (documental y móvil) | U7 y U8 | https://github.com/belcalvo93/BaseDatos2-MongoDB |

**Cómo leer la tabla**
- **Base:** dónde se corre. Ninguno de los scripts que cambian datos se corre sobre `bd2_tp3` ni sobre `foodstore`: cada TP trabaja sobre su copia (`bd2_trabajo`, `bd2_tp4u4`, `bd2_tp5u5`, `foodstore_restore_test`, `bd2_tp8`).
- **Cómo se corre:** `psql -U postgres -d <base> -f <ruta>`, `bash <ruta>`, `mongosh --file <ruta>` o `sqlite3 <base>.db ".read <ruta>"`, según el motor.
- **Hallazgo 3.c:** número de la fila en la tabla de hallazgos de `docs/3c_code_review_ia.md`. "—" significa que no hay hallazgo registrado para ese archivo en esa tabla. Los scripts de la U6 tienen además dos revisiones propias con OpenCode (`mantenimiento/revision_opencode.md` y `revision_opencode_v2.md`, decisiones en `mantenimiento/decisiones_revision.md`).

---

## Repositorio `base-datos-2` (U1 a U6)

### Unidad 1 · Modelo, normalización, restricciones y concurrencia

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `food-store/schema.sql` | Crea las tablas del núcleo (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`) con PK, FK y tipos | copia de trabajo | — |
| `food-store/data.sql` | Datos de carga inicial del esquema del TP1 | copia de trabajo | — |
| `food-store/verificacion_normalizacion.sql` | Consultas de solo lectura que verifican la normalización del esquema | `bd2_tp3` (solo lee) | — |
| `food-store/restricciones.sql` | Restricciones de integridad de las reglas de negocio (CHECK, UNIQUE, triggers) | copia de trabajo | — |
| `food-store/pruebas_restricciones.sql` | Prueba cada restricción con casos válidos e inválidos | copia de trabajo | — |
| `food-store/procedimientos.sql` | Procedimiento `registrar_pedido` (alta de pedido con validación de stock) | copia de trabajo | 1, 2 |
| `concurrencia/escenario0_atomicidad.sql` | Atomicidad: COMMIT y ROLLBACK | `bd2_trabajo` | 2 |
| `concurrencia/escenario1_lectura_no_repetible_sesionA.sql` · `…_sesionB.sql` | Lectura no repetible entre dos sesiones | `bd2_trabajo` | 2 |
| `concurrencia/escenario2_lectura_fantasma_sesionA.sql` · `…_sesionB.sql` | Lectura fantasma entre dos sesiones | `bd2_trabajo` | 2 |
| `concurrencia/escenario3_espera_bloqueo_sesionA.sql` · `…_sesionB.sql` | Espera por bloqueo (`SELECT … FOR UPDATE`) | `bd2_trabajo` | 2 |

### Unidad 2 · Carga masiva

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `food-store/carga_masiva.sql` | Carga masiva de clientes, productos (~50.000), pedidos y detalle | copia de trabajo | — |
| `food-store/carga_masiva_bloque3_B.sql` | Variante B del bloque 3 (pedido → cliente), medida contra la A y descartada | copia de trabajo | — |
| `food-store/verificacion_carga_masiva.sql` | Verificación de la carga, solo lectura | copia de trabajo | — |

### Unidad 3 · Índices, vistas y rendimiento (TP5)

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `food-store/indices.sql` | Índices aceptados después de medir | `bd2_trabajo` | — |
| `food-store/queries.sql` | Consultas del proyecto, extraídas de los informes | `bd2_trabajo` | — |
| `food-store/medicion_planes.sql` | `EXPLAIN (ANALYZE, BUFFERS)` antes y después de cada índice | `bd2_trabajo` | — |
| `food-store/medicion_escritura.sql` | Costo de los índices sobre INSERT y UPDATE | `bd2_trabajo` | — |
| `food-store/views.sql` | Vistas (`vista_cliente_completo`, vista de reportes sin contraseña) | `bd2_tp3` | — |
| `food-store/materializadas.sql` | Vista materializada de facturación por categoría y mes | copia de trabajo | — |

### Unidad 4 · FNBC y desnormalización controlada

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `food-store/tp_fnbc_control_lote.sql` | Esquema heredado `control_lote_almacen`, anomalías, descomposición FNBC, migración y verificación con `EXCEPT` (en `BEGIN … ROLLBACK`) | `bd2_tp4u4` | — |
| `food-store/carga_pedidos_hoy.sql` | Carga pedidos del día (insumo de la Parte 2) | `bd2_tp4u4` | — |
| `food-store/medicion_top_categorias_antes.sql` | Medición basal antes de desnormalizar | `bd2_tp4u4` | — |
| `food-store/tp_desnormalizacion_top_categorias.sql` | Resumen desnormalizado + triggers de sincronización | `bd2_tp4u4` | 3 |
| `food-store/medicion_top_categorias_despues.sql` | Medición después de desnormalizar | `bd2_tp4u4` | — |
| `food-store/medicion_escritura_top_categorias.sql` | Costo de escritura del trigger de sincronización | `bd2_tp4u4` | — |
| `food-store/auditoria_top_categorias.sql` | Auditoría del resumen contra los datos base (esperado: 0 filas) | `bd2_tp4u4` | — |
| `food-store/tp_desnormalizacion_reversion.sql` | Reversión completa de la desnormalización | `bd2_tp4u4` | — |

### Unidad 5 · Seguridad, roles y auditoría

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `sql/funciones_auth.sql` | Extensión `pgcrypto` y funciones de autenticación y reseteo de contraseña | `bd2_tp5u5` | 4 |
| `sql/mv_ventas_categoria_mes.sql` | Agregado del panel gerencial | `bd2_tp5u5` | — |
| `sql/roles.sql` | Roles, usuarios y permisos (mínimo privilegio) | `bd2_tp5u5` | 1 |
| `sql/verificacion_roles.sql` | Verificación de permisos con `SET ROLE` | `bd2_tp5u5` | — |
| `sql/auditoria_test.sql` | Activación y prueba de la auditoría (`log_statement`) | `bd2_tp5u5` | 5 |
| `sql/simulacro_incidente.sql` | Simulacro de acceso indebido (fuerza bruta y escalada) | `bd2_tp5u5` | — |
| `sql/simulacro_limpieza.sql` | Deja la base y el servidor como antes del simulacro | `bd2_tp5u5` | — |
| `sql/anonimizar_log.sh` | Anonimiza el log del simulacro antes de pasárselo a la IA | `bd2_tp5u5` | — |
| `sql/usuario_anon.sql` | Tabla `usuario_anon` con datos sintéticos | `bd2_tp5u5` | — |

### Unidad 6 · Mantenimiento, respaldo y restauración

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `mantenimiento/conteo_referencia.sql` | Huella de 11 claves (filas de las 6 tablas, total facturado, tablas, vistas, restricciones, índices) | `foodstore` (solo lee) | — (rev. U6) |
| `mantenimiento/backup_foodstore.sh` | Huella `.conteo` → `pg_dump -Fc` → `pg_restore -l` → `.sha256`; línea PASS/FAIL en el log | `foodstore` (solo lee) | 7 · rev. U6 |
| `mantenimiento/restore_test.sh` | Verifica SHA256, pide autorización, restaura en la base descartable, valida huella 11/11 y 8 indicadores, mide RTO y RPO | `foodstore_restore_test` | 7 · rev. U6 |
| `mantenimiento/maintenance.sql` | Diagnóstico de estadísticas y tuplas muertas; `ANALYZE` solo de las tablas pendientes; nunca `VACUUM FULL` | `foodstore` o `foodstore_restore_test` | 6 · rev. U6 |
| `mantenimiento/health_check.sql` | Chequeo de salud (tamaño, conexiones, estado de tablas, consultas activas) | `foodstore` (solo lee) | 8 · rev. U6 |

---

## Repositorio `BaseDatos2-MongoDB` (U7 y U8)

### Unidad 7 · MongoDB

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `seleccion_pedidos.sql` | Selecciona en PostgreSQL los pedidos a migrar | `bd2_tp3` (solo lee) | — |
| `consultas_postgresql.sql` | Las 5 consultas de verificación en SQL | `bd2_tp3` (solo lee) | — |
| `consultas_mongodb.js` | Migración, validador `$jsonSchema`, las 5 consultas equivalentes y auditoría del total | MongoDB `foodstore` | 9 |
| `prueba_indice_unico_ia.js` | Evidencia de laboratorio contra el índice único multikey que propuso la IA | MongoDB `foodstore` | 9 |

### Unidad 8 · SQLite (la base de la tablet)

| Ruta | Qué hace | Base | Hallazgo 3.c |
|---|---|---|---|
| `food-store/postgresql/10_snapshot_catalogo.sql` | Vista `v_snapshot_movil` (precio en centavos, lápidas) | `bd2_tp8` | 11 |
| `food-store/movil/schema_sqlite.sql` | 6 tablas STRICT, índice único parcial y vista del catálogo | `foodstore_movil.db` | 10 |
| `food-store/movil/importar_catalogo.sql` | Importa el CSV en `snapshot_servidor` y hace el upsert a `producto_cache` | `foodstore_movil.db` | — |
| `food-store/movil/pruebas_sqlite.sql` | COMMIT, ROLLBACK, subtotal, C1 y C7 | `pruebas.db` | — |
| `food-store/movil/semaforo.sql` | Evalúa las solicitudes `PENDIENTE`, registra en `evaluacion_sync` y actualiza `cola_sync` | `foodstore_movil.db` | 11 |
| `food-store/postgresql/casos_servidor.sql` | Prepara C2, C3 y C4 en el servidor y exporta la instantánea nueva | `bd2_tp8` | — |
| `food-store/movil/casos_sqlite.sql` | Casos C2 a C6 con el semáforo y el registro de evaluaciones | `foodstore_movil.db` | — |
| `food-store/postgresql/consulta_final.sql` | Pedidos y stock después de la simulación (sin cambios) | `bd2_tp8` (solo lee) | — |

---

**Total:** 56 scripts (44 en `base-datos-2` y 12 en `BaseDatos2-MongoDB`, contando por separado las sesiones A y B de concurrencia).
