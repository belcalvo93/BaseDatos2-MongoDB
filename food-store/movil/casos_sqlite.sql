-- ============================================================================
-- TP8 · Food Store · Casos C2 a C6 en SQLite (consigna 2.c · Tarea 6)
-- Responsable: Hernán González (Bloque C)
--
-- Flujo completo desde la carpeta food-store/:
--   1) Asegurar que la base de la tablet tenga el esquema y la instantánea inicial:
--        sqlite3 movil/foodstore_movil.db ".read movil/schema_sqlite.sql"
--        sqlite3 movil/foodstore_movil.db ".read movil/importar_catalogo.sql"
--   2) Preparar en bd2_tp8 los cambios del servidor (C2, C3 y C4) y exportar el CSV nuevo:
--        psql -U postgres -d bd2_tp8 -f postgresql/casos_servidor.sql
--   3) Correr este script en la tablet:
--        sqlite3 movil/foodstore_movil.db ".read movil/casos_sqlite.sql"
--
-- Productos fijos del grupo (Bloque B):
--   * C2 (sube precio): id_producto = 3  (Agua mineral 2L, visto 140000 -> actual 160000)
--   * C3 (baja stock):  id_producto = 2  (Medialunas x6, pide 2 con stock 3; otra
--                                         tablet vende y el servidor queda con 1)
--   * C4 (se da baja):  id_producto = 11 (Cerveza 1L, pasa a eliminado = 1)
--   * C5 (sin cambios): id_producto = 9  (Fideos secos 500g, pide 2 <= stock 30)
--
-- El único error esperado en toda la salida es el del Caso C6 parte b (UNIQUE
-- constraint failed: cola_sync.solicitud_uuid). La parte c muestra el reenvío
-- idempotente: no da error y devuelve el resultado guardado.
-- ============================================================================

PRAGMA foreign_keys = ON;
.headers on
.mode box

-- Limpieza previa de borradores/cola por si se reejecuta el script sobre la misma base
DELETE FROM evaluacion_sync;   -- hija de cola_sync: se borra primero
DELETE FROM cola_sync;
DELETE FROM item_borrador;
DELETE FROM pedido_borrador;

-- ============================================================================
-- ETAPA 1: LA TABLET SIN SEÑAL (ARMA BORRADORES CON EL CATÁLOGO INICIAL)
-- Antes de sincronizar, la tablet ve los precios y disponibilidad de la primera
-- instantánea: producto 3 a $1400 (140000 centavos) y producto 11 disponible.
-- ============================================================================
SELECT 'ETAPA 1: creacion de borradores offline en SQLite (C2, C3, C4 y C5)' AS etapa;

-- Borrador C2: pide 2 unidades de Agua mineral 2L (prod. 3) al precio visto de 140000 centavos
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago, creado_en)
VALUES ('cccccccc-0000-4000-8000-000000000002', 1, 'EFECTIVO', '2026-11-02T10:00:02Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('cccccccc-0000-4000-8000-000000000002', 3, 2, 140000);

INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000002', 'cccccccc-0000-4000-8000-000000000002', '2026-11-02T10:00:02Z');
COMMIT;

-- Borrador C3: pide 2 unidades de Medialunas x6 (prod. 2). Es VÁLIDO al armarlo
-- (la instantánea inicial muestra stock 3); después otra tablet vende y el
-- servidor queda con stock 1 (se prepara en casos_servidor.sql).
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago, creado_en)
VALUES ('cccccccc-0000-4000-8000-000000000003', 1, 'TARJETA', '2026-11-02T10:00:03Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('cccccccc-0000-4000-8000-000000000003', 2, 2, 320000);

INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000003', 'cccccccc-0000-4000-8000-000000000003', '2026-11-02T10:00:03Z');
COMMIT;

-- Borrador C4: pide 1 unidad de Cerveza 1L (prod. 11), que luego se da de baja en el servidor
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago, creado_en)
VALUES ('cccccccc-0000-4000-8000-000000000004', 1, 'TRANSFERENCIA', '2026-11-02T10:00:04Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('cccccccc-0000-4000-8000-000000000004', 11, 1, 450000);

INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000004', 'cccccccc-0000-4000-8000-000000000004', '2026-11-02T10:00:04Z');
COMMIT;

-- Borrador C5: pide 2 unidades de Fideos secos 500g (prod. 9), sin cambios en el servidor
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago, creado_en)
VALUES ('cccccccc-0000-4000-8000-000000000005', 1, 'EFECTIVO', '2026-11-02T10:00:05Z');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('cccccccc-0000-4000-8000-000000000005', 9, 2, 195000);

INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000005', 'cccccccc-0000-4000-8000-000000000005', '2026-11-02T10:00:05Z');
COMMIT;

SELECT solicitud_uuid, id_local, estado, motivo FROM cola_sync ORDER BY creada_en;

-- Consulta con subtotal: lo que la tablet le mostraría al cliente en cada
-- borrador. Se calcula en centavos (INTEGER, sin error de redondeo) y se
-- muestra en pesos solo para leerlo. El subtotal no se guarda: se calcula.
SELECT 'ETAPA 1: borradores con subtotal por item y total (centavos y pesos)' AS etapa;

SELECT i.id_local, i.producto_id, p.nombre, i.cantidad, i.precio_centavos_visto,
       i.cantidad * i.precio_centavos_visto         AS subtotal_centavos,
       i.cantidad * i.precio_centavos_visto / 100.0 AS subtotal_pesos
FROM item_borrador i
JOIN producto_cache p USING (producto_id)
ORDER BY i.id_local, i.producto_id;

SELECT id_local,
       count(*)                                      AS items,
       sum(cantidad * precio_centavos_visto)         AS total_centavos,
       sum(cantidad * precio_centavos_visto) / 100.0 AS total_pesos
FROM item_borrador
GROUP BY id_local
ORDER BY id_local;

-- ============================================================================
-- ETAPA 2: VUELVE LA SEÑAL -> SE IMPORTA LA NUEVA INSTANTÁNEA Y CORRE EL SEMÁFORO
-- Evalúa:
--   * C2 (prod. 3):  CONFLICTO (visto 140000 vs actual 160000 centavos)
--   * C3 (prod. 2):  RECHAZADO (pide 2, hay 1: otra tablet vendió)
--   * C4 (prod. 11): RECHAZADO (dado de baja: producto 11)
--   * C5 (prod. 9):  SIMULADO_APROBADO (todo coincide; simulación, no venta)
-- ============================================================================
SELECT 'ETAPA 2: importar nueva instantanea (con cambios de C2, C3 y C4) y correr semaforo' AS etapa;

.read movil/importar_catalogo.sql
.read movil/semaforo.sql
.mode box

-- ============================================================================
-- VERIFICACIÓN CASO C4: LÁPIDA EN producto_cache VS v_catalogo_disponible
-- El producto 11 ya NO aparece en v_catalogo_disponible (0 filas), pero la fila
-- SIGUE en producto_cache con eliminado = 1, preservando la FK de item_borrador.
-- ============================================================================
SELECT 'CASO C4: verificacion de lapida del producto 11 (Cerveza 1L)' AS verificacion;

SELECT count(*) AS prod_11_en_catalogo_disponible
FROM v_catalogo_disponible
WHERE producto_id = 11;

SELECT producto_id, nombre, precio_centavos, stock_visto, disponible_visto, eliminado
FROM producto_cache
WHERE producto_id = 11;

-- ============================================================================
-- CASO C2 (PARTE 2): EL CLIENTE ACEPTA EL PRECIO NUEVO Y SE REENVÍA CON OTRO UUID
-- Se actualiza precio_centavos_visto a 160000 en item_borrador y se encola una
-- solicitud nueva (dddddddd-...-0202). El índice parcial ux_cola_una_pendiente
-- lo permite porque la solicitud anterior ya no está PENDIENTE sino en CONFLICTO.
-- ============================================================================
SELECT 'CASO C2 (parte 2): se muestran los dos precios; el cliente acepta 160000 -> nueva solicitud -> SIMULADO_APROBADO' AS verificacion;

-- Lo que se le muestra al cliente antes de aceptar: subtotal visto contra
-- subtotal con el precio actual de la instantánea.
SELECT i.producto_id, i.cantidad,
       i.precio_centavos_visto                      AS precio_visto,
       s.precio_centavos                            AS precio_actual,
       i.cantidad * i.precio_centavos_visto / 100.0 AS subtotal_visto_pesos,
       i.cantidad * s.precio_centavos / 100.0       AS subtotal_actual_pesos
FROM item_borrador i
JOIN snapshot_servidor s USING (producto_id)
WHERE i.id_local = 'cccccccc-0000-4000-8000-000000000002';

BEGIN;
UPDATE item_borrador
SET precio_centavos_visto = 160000
WHERE id_local = 'cccccccc-0000-4000-8000-000000000002'
  AND producto_id = 3;

INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000202', 'cccccccc-0000-4000-8000-000000000002', '2026-11-02T10:05:00Z');
COMMIT;

.read movil/semaforo.sql
.mode box

-- ============================================================================
-- CASO C6: IDEMPOTENCIA (REEJECUCIÓN DEL SEMÁFORO Y REENVÍO CON MISMO UUID)
-- 6a) Volver a correr semaforo.sql no reevalúa lo ya resuelto: evaluacion_sync
--     tiene la misma cantidad de filas antes y después.
-- 6b) Insertar de nuevo el mismo solicitud_uuid con un INSERT común falla por
--     PK: la solicitud no se duplica (único error esperado del script).
-- 6c) Reenvío idempotente: INSERT ... ON CONFLICT DO NOTHING no hace nada y se
--     devuelve el resultado guardado; no se evalúa de nuevo.
-- ============================================================================
SELECT 'CASO C6 (parte a): volver a correr semaforo.sql -> no reevalua lo ya resuelto' AS verificacion;

SELECT count(*) AS evaluaciones_antes FROM evaluacion_sync;

.read movil/semaforo.sql
.mode box

SELECT count(*) AS evaluaciones_despues FROM evaluacion_sync;   -- igual que antes

SELECT 'CASO C6 (parte b): reenviar mismo solicitud_uuid con INSERT comun -> se espera error UNIQUE/PK' AS verificacion;

-- .bail off para que SQLite continúe después del error esperado de clave primaria
.bail off
INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000005', 'cccccccc-0000-4000-8000-000000000005', '2026-11-02T10:06:00Z');

SELECT 'CASO C6 (parte c): reenvio idempotente -> no se duplica y se devuelve el resultado guardado' AS verificacion;

INSERT INTO cola_sync (solicitud_uuid, id_local, creada_en)
VALUES ('dddddddd-0000-4000-8000-000000000005', 'cccccccc-0000-4000-8000-000000000005', '2026-11-02T10:06:00Z')
ON CONFLICT (solicitud_uuid) DO NOTHING;                         -- ya existe: no hace nada

SELECT changes() AS filas_insertadas;                            -- 0

SELECT solicitud_uuid, estado, motivo                            -- resultado guardado
FROM cola_sync
WHERE solicitud_uuid = 'dddddddd-0000-4000-8000-000000000005';

SELECT count(*) AS evaluaciones_de_esta_solicitud                -- sigue en 1
FROM evaluacion_sync
WHERE solicitud_uuid = 'dddddddd-0000-4000-8000-000000000005';

-- La cola sigue con las 5 solicitudes y sus estados
SELECT solicitud_uuid, id_local, estado, motivo
FROM cola_sync
ORDER BY creada_en, solicitud_uuid;

-- Registro de evaluaciones: una fila por cada vez que el semáforo evaluó una
-- solicitud. C2 tiene dos (CONFLICTO y la solicitud nueva aprobada); las
-- corridas repetidas y el reenvío del C6 no agregaron filas.
SELECT 'REGISTRO DE EVALUACIONES (evaluacion_sync)' AS verificacion;

SELECT e.id_evaluacion, e.solicitud_uuid, c.id_local, e.capturado_en, e.estado, e.motivo, e.evaluado_en
FROM evaluacion_sync e
JOIN cola_sync c USING (solicitud_uuid)
ORDER BY e.id_evaluacion;

-- Control final de integridad de la base de la tablet
SELECT 'CONTROL FINAL SQLite: foreign_key_check (0 filas) e integrity_check (ok)' AS verificacion;
PRAGMA foreign_key_check;
PRAGMA integrity_check;
SELECT 'FIN: se ejecutaron todos los casos C2 a C6 (solo 1 error esperado: UNIQUE en C6 parte b)' AS resultado;
