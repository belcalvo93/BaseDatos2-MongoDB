# 3.c · Code review con IA (OpenCode — Agente Plan)

Se revisaron con **OpenCode (agente Plan, modo de solo lectura)** los scripts de las unidades de la cursada (`base-datos-2` para U1–U6 y `BaseDatos2-MongoDB` para U7–U8) sobre la rama de revisión `review-final`. Cada hallazgo se contrastó contra la especificación y se comprobó en el motor correspondiente (`psql`, `mongosh` o `sqlite3`) antes de decidir si se corregía, se aceptaba o se descartaba.

---

## 1. Tabla de hallazgos de la cursada

| # | Unidad y script | Hallazgo / Propuesta de la IA | Decisión | Motivo |
|---|---|---|---|---|
| 1 | **U1–U3** · `food-store/procedimientos.sql` y `sql/roles.sql` | `CREATE OR REPLACE PROCEDURE registrar_pedido` sin `SECURITY DEFINER` en su cabecera pierde ese atributo si se reejecuta el script; además, `rol_app_escritura` tenía `INSERT, UPDATE` directo sobre `pedido` y `detalle_pedido`. | **Corregido** | Permitía insertar pedidos vacíos o alterar fechas salteando `registrar_pedido`. Se revocó el DML directo y se dejó la escritura solo vía `CALL registrar_pedido` con `SECURITY DEFINER` y `search_path` fijo. |
| 2 | **U3** · `concurrencia/` y `procedimientos.sql` | En alta concurrencia, `registrar_pedido` lee `producto` y luego hace `UPDATE producto SET stock = stock - v_cantidad`; el trigger `fn_verificar_stock_suficiente` sin bloqueo explícito puede sufrir condición de carrera si dos sesiones leen el mismo stock a la vez. | **Aceptado (documentado)** | En los escenarios de concurrencia (U3) se demostró el bloqueo con `SELECT … FOR UPDATE`. Para la confirmación real de pedidos desde las tablets (parada 8), el servidor debe tomar lock de fila con `FOR UPDATE`. |
| 3 | **U4** · `food-store/tp_desnormalizacion_top_categorias.sql` | Al borrar un `pedido`, el `ON DELETE CASCADE` borra sus filas en `detalle_pedido`, pero cuando corre el trigger `AFTER DELETE ON detalle_pedido` la fila padre en `pedido` ya no existe y no se puede obtener la `fecha` para descontar del resumen diario. | **Corregido** | Se agregó el trigger `BEFORE DELETE ON pedido` (`trg_resumen_ventas_pedido_borrado`) que descuenta las líneas antes del borrado en cascada, y si `fn_resumen_ventas_aplicar_linea` no encuentra el pedido (`IF NOT FOUND`), retorna sin descontar dos veces. |
| 4 | **U5** · `sql/funciones_auth.sql` | `fn_resetear_password` (`SECURITY DEFINER`) actualizaba la clave de cualquier usuario activo sin filtrar por `rol`, permitiendo que `rol_soporte` reseteara la contraseña de una cuenta `ADMIN`. | **Corregido** | Escalada de privilegios en la aplicación. Se agregó la condición `AND rol <> 'ADMIN'`, longitud mínima de 8 caracteres y `RAISE EXCEPTION` si `NOT FOUND`. |
| 5 | **U5** · `sql/auditoria_test.sql` | La IA propuso dejar `ALTER SYSTEM SET log_statement = 'all'` de forma global y leer el log en Windows con `pg_read_file()` asumiendo UTF-8. | **Corregido / Descartado** | `'all'` global audita todas las lecturas del servidor exponiendo datos sensibles (se dejó `'mod'` global y `SET LOCAL` solo en la prueba); `pg_read_file()` falló en Windows porque el colector escribe en `WIN1252`, por lo que se usó `convert_from(pg_read_binary_file(...), 'WIN1252')`. |
| 6 | **U6** · `mantenimiento/maintenance.sql` | El `ANALYZE VERBOSE` listaba 5 tablas fijas y omitía la tabla `usuario` (creada en U5); además corría de forma incondicional en cada ejecución semanal. | **Corregido** | La tabla `usuario` quedaba con `reltuples = -1` y `last_analyze IS NULL`. Se incluyó `usuario` y se agregó la evaluación previa de estadísticas/tuplas muertas según `SPEC_U6.md`. |
| 7 | **U6** · `mantenimiento/restore_test.sh` | El simulacro de restauración comparaba el conteo de filas de `foodstore_restore_test` contra la base `foodstore` viva en lugar de comparar contra el conteo tomado al momento del backup. | **Corregido** | Si entraban ventas entre el backup y el simulacro, la prueba daba un falso `FALLA`. Se modificó `backup_foodstore.sh` para guardar el archivo `.conteo` junto al `.dump` y validar contra él. |
| 8 | **U6** · `mantenimiento/health_check.sql` | OpenCode marcó como defecto que el control 3 mostrara `n_live_tup = 0` en las tablas recién creadas con `createdb -T bd2_tp3`. | **Descartado** | No es un error del script: `createdb -T` no copia los contadores dinámicos de actividad, y ese `0` en `health_check.sql` fue justamente la señal que permitió detectar las estadísticas vacías y justificar la primera corrida de `maintenance.sql`. |
| 9 | **U7** · `consultas_mongodb.js` / `prueba_indice_unico_ia.js` | La IA propuso `db.pedidos.createIndex({ "lineas.id_producto": 1 }, { unique: true })` para evitar repetir el mismo producto dentro de un mismo pedido, y guardar `total` como punto flotante (`double`). | **Descartado / Corregido** | El índice único multikey en MongoDB aplica entre documentos distintos (bloquea futuras ventas del producto y no evita duplicados dentro del mismo array). Se descartó el índice y se implementó `$jsonSchema` con `$expr` y `$setUnion`; los importes se corrigieron a `Decimal128` (`NumberDecimal`). |
| 10 | **U8** · `food-store/movil/schema_sqlite.sql` | En la vista `v_catalogo_disponible`, OpenCode propuso cambiar `precio_centavos / 100.0 AS precio` por `printf('%d.%02d', ...)` para "no usar `REAL`"; y en el diseño de `cola_sync` se evaluó poner `UNIQUE(id_local)` total. | **Descartado** | La regla de centavos `INTEGER` rige para almacenar y comparar precios sin error de redondeo; la vista no almacena nada y convertir a texto impide ordenar o filtrar por precio. Un `UNIQUE(id_local)` total impediría reenviar un borrador tras aceptar un cambio de precio en el Caso C2 (por eso se usa el índice único parcial `WHERE estado = 'PENDIENTE'`). |

---

## 2. Desarrollo de hallazgos comprobados en la base

A continuación se desarrollan **4 hallazgos de 4 unidades distintas (U7, U6, U5 y U8)**, incluyendo tanto correcciones aplicadas como propuestas de la IA **descartadas con fundamento y prueba en el motor**.

### Desarrollo 1 — Unidad 7 (MongoDB): Índice único multikey en `lineas.id_producto` (DESCARTADO)

- **Qué propuso la IA:** para replicar en MongoDB la restricción relacional `UNIQUE (id_pedido, id_producto)` de `detalle_pedido`, recomendó crear un índice único sobre el arreglo embebido:
  `db.pedidos.createIndex({ "lineas.id_producto": 1 }, { unique: true })`.
- **Decisión:** **Descartado.**
- **Fundamento técnico:** según la documentación oficial de MongoDB (*Unique Constraint Across Separate Documents*), un índice único sobre un campo indexado como *multikey* impide que **dos documentos distintos** de la colección compartan el mismo valor de clave, pero no impide que un mismo documento repita ese valor varias veces dentro de su propio arreglo.
- **Cómo se comprobó en la base (`mongosh`):** se ejecutó el script `prueba_indice_unico_ia.js` sobre una colección de prueba con ese índice creado (evidencia en `evidencias/salida_prueba_indice_unico_ia.txt`):
  1. **Prueba 1 (falso positivo dentro del mismo pedido):** se insertó un pedido con dos líneas que tenían `id_producto: 1`. El motor devolvió `ACEPTADO (insertedId: 9001)`: el índice único no detectó el producto duplicado dentro del pedido.
  2. **Prueba 2 (bloqueo del sistema entre pedidos distintos):** se intentó insertar un segundo pedido de otro cliente que también compraba el `id_producto: 1`. El motor lo rechazó con `MongoServerError: E11000 duplicate key error collection`.
  - **Solución adoptada:** se descartó el índice único y la unicidad interna del arreglo se impuso en el validador de la colección (`$jsonSchema`) mediante `$expr` comparando `{ $size: "$lineas.id_producto" }` contra `{ $size: { $setUnion: ["$lineas.id_producto", []] } }`.

---

### Desarrollo 2 — Unidad 6 (PostgreSQL): Omisión de `usuario` en `ANALYZE` y validación contra base viva (CORREGIDO)

- **Qué detectó OpenCode (agente Plan):** al revisar `mantenimiento/maintenance.sql` y `mantenimiento/restore_test.sh` contra `SPEC_U6.md` (documentado en `mantenimiento/revision_opencode.md`), señaló dos problemas de severidad media:
  1. En `maintenance.sql` (línea 35), la sentencia `ANALYZE VERBOSE categoria, cliente, producto, pedido, detalle_pedido;` enumeraba solo 5 tablas y dejaba afuera a la tabla `usuario` (incorporada en la Unidad 5).
  2. En `restore_test.sh` (línea 62), la validación del simulacro comparaba el `COUNT(*)` de la base restaurada (`foodstore_restore_test`) contra una consulta en vivo a `foodstore`, en vez de comparar contra la foto tomada al momento de hacer el backup (`SPEC_U6.md`, línea 27).
- **Decisión:** **Corregido.**
- **Cómo se comprobó en la base (`psql`):**
  1. En la primera evidencia (`mantenimiento/evidencias/maintenance_salida.txt`, línea 48), la consulta posterior al `ANALYZE` sobre `pg_stat_user_tables` y `pg_class` mostró que `categoria`, `cliente`, `producto`, `pedido` y `detalle_pedido` habían actualizado sus estadísticas (`499263`, `200005`, etc. y fecha en `last_analyze`), pero la fila de `usuario` seguía con `filas_estimadas = -1` y `last_analyze` vacío (`NULL`).
  2. Se corrigieron ambos scripts: `maintenance.sql` pasó a evaluar las 6 tablas de forma condicional (evidencia en `maintenance_v2_corrida1.txt`, donde analiza `usuario` en la primera corrida y en la segunda informa `sin accion, estadisticas al dia`), y `backup_foodstore.sh` pasó a generar un archivo `.conteo` junto a cada `.dump` para que `restore_test.sh` valide la restauración sin tocar ni depender de la base `foodstore` viva (`restore_test_v2_salida.txt`).

---

### Desarrollo 3 — Unidad 5 y Unidad 3 (PostgreSQL): Escritura directa en `pedido` y reseteo de cuentas `ADMIN` (CORREGIDO)

- **Qué detectó el agente Plan:** al auditar `sql/roles.sql` y `sql/funciones_auth.sql` contra la especificación de mínimo privilegio (`docs/auditoria_roles_ia.md`, hallazgos H1 y H4):
  1. `rol_app_escritura` tenía `GRANT INSERT, UPDATE ON pedido, detalle_pedido`, lo cual permitía que el login `app_web` insertara cabeceras de pedidos sin ítems o modificara la fecha/cliente de pedidos históricos sin pasar por el procedimiento transaccional `registrar_pedido` (creado en la Unidad 3).
  2. La función `fn_resetear_password(BIGINT, TEXT)`, definida con `SECURITY DEFINER`, actualizaba la contraseña de cualquier usuario con `eliminado = FALSE` sin verificar su rol, permitiendo que un operador de `rol_soporte` cambiara la clave de un usuario `ADMIN` y tomara su cuenta.
- **Decisión:** **Corregido.**
- **Cómo se comprobó en la base (`psql`):** dentro de una transacción de prueba (`BEGIN … ROLLBACK`):
  1. Antes del ajuste, ejecutando `SET ROLE app_web; INSERT INTO pedido (fecha, forma_pago, id_cliente) VALUES (now(), 'EFECTIVO', 1);` el motor permitía crear un pedido vacío (violando la regla de negocio de `registrar_pedido` que exige `jsonb_array_length(p_items) > 0`). Tras aplicar `REVOKE INSERT, UPDATE ON pedido, detalle_pedido FROM rol_app_escritura;` y dejar `GRANT EXECUTE ON PROCEDURE registrar_pedido`, el `INSERT` directo fue rechazado con `ERROR: permission denied for table pedido` mientras que `CALL registrar_pedido(...)` funcionó correctamente.
  2. En `fn_resetear_password` se agregó `AND rol <> 'ADMIN'` y el control `IF NOT FOUND THEN RAISE EXCEPTION`. Al probar en `psql` con `SET ROLE rol_soporte; SELECT fn_resetear_password(1, 'clave_nueva_123');` (siendo `id = 1` un usuario `ADMIN`), el motor abortó la operación con el error esperado.

---

### Desarrollo 4 — Unidad 8 (SQLite): Precio como texto en la vista e índice `UNIQUE` total en `cola_sync` (DESCARTADO)

- **Qué propuso la IA:** durante la construcción y revisión del bloque SQLite (`food-store/movil/schema_sqlite.sql`):
  1. OpenCode propuso reemplazar en la vista `v_catalogo_disponible` la expresión `precio_centavos / 100.0 AS precio` por `printf('%d.%02d', precio_centavos / 100, precio_centavos % 100)` argumentando que "así no aparece ningún tipo `REAL` en la base".
  2. En el diseño de `cola_sync`, se evaluó la sugerencia típica de definir `id_local TEXT NOT NULL UNIQUE` para impedir que un mismo borrador se encolara dos veces.
- **Decisión:** **Descartado en ambos puntos.**
- **Fundamento técnico y comprobación en SQLite (`sqlite3`):**
  1. **Sobre `v_catalogo_disponible`:** la regla de usar `INTEGER` en centavos (y tablas `STRICT`) es para **almacenar** precios en `producto_cache`, `item_borrador` y `snapshot_servidor` y comparar en el semáforo sin errores de punto flotante. Una `VIEW` no almacena datos; si devuelve un `TEXT` formateado con `printf`, una consulta del vendedor como `SELECT * FROM v_catalogo_disponible ORDER BY precio` ordena alfabéticamente (`'900.00'` aparece después de `'1500.00'`). Se comprobó en SQLite con los productos de `pruebas_sqlite.sql` (`precio_centavos` `150000` y `89900`): con `/ 100.0` el orden numérico es correcto y las 5 tablas base siguen teniendo `strict = 1` en `pragma_table_list`.
  2. **Sobre `ux_cola_una_pendiente`:** si `id_local` fuera `UNIQUE` en toda la tabla `cola_sync`, cuando un envío queda en `estado = 'CONFLICTO'` por cambio de precio (Caso C2) y el cliente acepta el nuevo precio, la tablet no podría insertar la nueva solicitud (con un nuevo `solicitud_uuid`) para ese mismo `id_local`. Al comprobarlo en SQLite con el índice único parcial `CREATE UNIQUE INDEX ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';`, un segundo `INSERT` mientras el primero sigue en `'PENDIENTE'` falla con `Runtime error: UNIQUE constraint failed: cola_sync.id_local`, pero en cuanto el primero pasa a `'CONFLICTO'`, el segundo `INSERT` con `estado = 'PENDIENTE'` se ejecuta sin error, cumpliendo a la vez la unicidad de envíos pendientes y el reenvío de C2.
