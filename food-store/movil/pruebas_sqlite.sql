-- ============================================================================
-- TP8 · Food Store · Pruebas de la base de la tablet (SQLite)
-- Cubre la Tarea 4: transacciones (COMMIT y ROLLBACK), C1 y C7 (REQ-04).
--
-- Se corre SIEMPRE desde food-store/ y sobre una base limpia:
--   rm -f movil/pruebas.db          (o: del movil\pruebas.db en Windows)
--   sqlite3 movil/pruebas.db ".read movil/schema_sqlite.sql" ".read movil/pruebas_sqlite.sql"
--
-- OJO: este script NO se puede correr dos veces sobre el mismo pruebas.db,
-- porque la Prueba 1 inserta UUIDs fijos y la segunda vez chocaría con la PK.
-- Si querés repetirlo, borrá movil/pruebas.db y volvé a empezar.
--
-- Los únicos errores esperados son los dos de la Prueba 4 (CHECK y FOREIGN KEY).
-- Cualquier otro mensaje de error es un problema real.
-- ============================================================================

PRAGMA foreign_keys = ON;   -- en cada conexión; va antes de cualquier BEGIN
.headers on
.mode box

-- Queremos que el shell siga después de los dos errores esperados de la Prueba 4.
-- (En SQLite un error de restricción deshace solo la sentencia que falló, no la
-- transacción: por eso cada prueba inválida termina con su ROLLBACK explícito.)
.bail off

-- ----------------------------------------------------------------------------
-- PRUEBA 0: catálogo inventado en producto_cache
-- En el flujo real esta tabla NO se carga a mano: se llena con el upsert desde
-- snapshot_servidor (movil/importar_catalogo.sql), que viene del CSV exportado
-- de PostgreSQL. Acá se cargan 3 filas inventadas para poder probar el esquema
-- sin depender de tener el servidor levantado.
-- La fecha es fija para que la salida sea siempre igual y se pueda comparar.
-- ----------------------------------------------------------------------------
SELECT 'PRUEBA 0: carga de 3 productos inventados en producto_cache' AS prueba;

INSERT INTO producto_cache
    (producto_id, nombre, precio_centavos, stock_visto, disponible_visto, eliminado, capturado_en)
VALUES
    -- Se puede vender: aparece en el catálogo (C1).
    (900001, 'Producto inventado A (disponible)', 150000, 10, 1, 0, '2026-11-01T12:00:00Z');

INSERT INTO producto_cache
    (producto_id, nombre, precio_centavos, stock_visto, disponible_visto, eliminado, capturado_en)
VALUES
    -- Sin stock: NO aparece en el catálogo (disponible_visto = 0).
    (900002, 'Producto inventado B (sin stock)', 89900, 0, 0, 0, '2026-11-01T12:00:00Z');

INSERT INTO producto_cache
    (producto_id, nombre, precio_centavos, stock_visto, disponible_visto, eliminado, capturado_en)
VALUES
    -- Lápida (dado de baja): NO aparece en el catálogo por eliminado = 1.
    -- Se le deja disponible_visto = 1 a propósito, así se prueba que el filtro
    -- por lápida funciona solo y no "gracias" al stock.
    (900003, 'Producto inventado C (dado de baja)', 250000, 5, 1, 1, '2026-11-01T12:00:00Z');

-- Control: tienen que quedar 3 filas en el caché.
SELECT 'filas en producto_cache (esperado 3)' AS control, COUNT(*) AS filas
FROM producto_cache;

-- ----------------------------------------------------------------------------
-- PRUEBA 1: borrador completo con BEGIN ... COMMIT
-- Cabecera + ítem + solicitud se guardan juntos: o queda todo, o no queda nada.
-- Esperado: 1 fila en cada una de las tres tablas.
-- ----------------------------------------------------------------------------
SELECT 'PRUEBA 1: borrador completo con COMMIT (esperado 1/1/1)' AS prueba;

BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000001', 1, 'EFECTIVO');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('aaaaaaaa-0000-4000-8000-000000000001', 900001, 2, 150000);

-- estado y creada_en toman su DEFAULT: 'PENDIENTE' y la hora actual.
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('bbbbbbbb-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001');
COMMIT;

SELECT 'pedido_borrador' AS tabla, COUNT(*) AS filas FROM pedido_borrador
UNION ALL
SELECT 'item_borrador',   COUNT(*) FROM item_borrador
UNION ALL
SELECT 'cola_sync',       COUNT(*) FROM cola_sync;

-- ----------------------------------------------------------------------------
-- PRUEBA 2: segundo borrador completo con BEGIN ... ROLLBACK
-- Mismo trabajo que la Prueba 1, pero se deshace: no tiene que quedar nada.
-- Esperado: los COUNT(*) de antes y de después son idénticos (1/1/1).
-- ----------------------------------------------------------------------------
SELECT 'PRUEBA 2: borrador completo con ROLLBACK (esperado: antes = despues)' AS prueba;

SELECT 'antes' AS momento, 'pedido_borrador' AS tabla, COUNT(*) AS filas FROM pedido_borrador
UNION ALL
SELECT 'antes', 'item_borrador',   COUNT(*) FROM item_borrador
UNION ALL
SELECT 'antes', 'cola_sync',       COUNT(*) FROM cola_sync;

BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000002', 2, 'TARJETA');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('aaaaaaaa-0000-4000-8000-000000000002', 900002, 1, 89900);

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('bbbbbbbb-0000-4000-8000-000000000002', 'aaaaaaaa-0000-4000-8000-000000000002');
ROLLBACK;

SELECT 'despues' AS momento, 'pedido_borrador' AS tabla, COUNT(*) AS filas FROM pedido_borrador
UNION ALL
SELECT 'despues', 'item_borrador',   COUNT(*) FROM item_borrador
UNION ALL
SELECT 'despues', 'cola_sync',       COUNT(*) FROM cola_sync;

-- ----------------------------------------------------------------------------
-- PRUEBA 3 (C1): el catálogo disponible se lee sin servidor
-- La vista filtra por eliminado = 0 AND disponible_visto = 1.
-- Esperado: aparece SOLO el 900001. No tienen que aparecer el 900002 (sin stock)
-- ni el 900003 (lápida).
-- ----------------------------------------------------------------------------
SELECT 'PRUEBA 3 (C1): v_catalogo_disponible sin servidor (esperado: solo 900001)' AS prueba;

SELECT * FROM v_catalogo_disponible;

-- ----------------------------------------------------------------------------
-- PRUEBA 4 (C7): datos inválidos (REQ-04)
-- Se cuentan las filas antes y después: los dos intentos fallan y el ROLLBACK
-- deshace lo que se había alcanzado a insertar (el pedido_borrador válido).
-- Esperado: antes = despues (1/1/1) y solo dos errores en toda la salida.
-- ----------------------------------------------------------------------------
SELECT 'PRUEBA 4 (C7): datos invalidos, esperado antes = despues' AS prueba;

SELECT 'antes' AS momento, 'pedido_borrador' AS tabla, COUNT(*) AS filas FROM pedido_borrador
UNION ALL
SELECT 'antes', 'item_borrador',   COUNT(*) FROM item_borrador
UNION ALL
SELECT 'antes', 'cola_sync',       COUNT(*) FROM cola_sync;

-- 4a) cantidad = 0 -> viola CHECK (cantidad > 0). Error esperado.
-- El pedido_borrador de arriba sí es válido, y es justamente lo que el ROLLBACK
-- tiene que borrar: en SQLite el error deshace solo el INSERT del ítem.
SELECT 'PRUEBA 4a: item con cantidad 0 -> se espera error CHECK' AS prueba;

BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000003', 1, 'EFECTIVO');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('aaaaaaaa-0000-4000-8000-000000000003', 900001, 0, 150000);   -- acá falla: cantidad > 0
ROLLBACK;

-- 4b) producto_id 999999 no existe en producto_cache -> viola la FOREIGN KEY.
-- Error esperado (con PRAGMA foreign_keys = ON; si estuviera apagado, pasaría).
SELECT 'PRUEBA 4b: item con producto_id 999999 -> se espera error FOREIGN KEY' AS prueba;

BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000004', 1, 'TRANSFERENCIA');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('aaaaaaaa-0000-4000-8000-000000000004', 999999, 1, 100);      -- acá falla: FK inexistente
ROLLBACK;

SELECT 'despues' AS momento, 'pedido_borrador' AS tabla, COUNT(*) AS filas FROM pedido_borrador
UNION ALL
SELECT 'despues', 'item_borrador',   COUNT(*) FROM item_borrador
UNION ALL
SELECT 'despues', 'cola_sync',       COUNT(*) FROM cola_sync;

-- ----------------------------------------------------------------------------
-- Cierre: si esta línea aparece, el script llegó al final a pesar de los dos
-- errores esperados de la Prueba 4.
-- ----------------------------------------------------------------------------
SELECT 'FIN: se corrieron todas las pruebas (solo se esperaban 2 errores: CHECK y FOREIGN KEY)' AS prueba;
