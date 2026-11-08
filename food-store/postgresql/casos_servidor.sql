-- ============================================================================
-- TP8 · Food Store · Preparación en servidor y consultas de control (consigna 2.c)
-- Responsable: Hernán González (Bloque C · Tarea 6)
--
-- Se corre SIEMPRE sobre la copia bd2_tp8 (nunca sobre bd2_tp3), desde food-store/:
--   psql -U postgres -d bd2_tp8 -f postgresql/casos_servidor.sql
--
-- Qué hace este script:
--   0. Verifica que la conexión sea a bd2_tp8 y restablece el estado inicial de
--      los productos 2, 3 y 11 para que el flujo sea repetible desde cero.
--   1. Ejecuta la CONSULTA INICIAL de control (cantidad de pedidos y estado/stock
--      de los productos fijos 2, 3, 9, 10 y 11 antes de la simulación).
--   2. Aplica los cambios manuales en la copia del servidor para preparar:
--        * Caso C2: sube el precio del producto 3 (Agua mineral 2L) de $1400 a $1600.
--        * Caso C3: baja el stock del producto 2 (Medialunas x6) de 3 a 1, como si
--                   otra tablet hubiera vendido 2 unidades mientras esta no tenía señal.
--        * Caso C4: da de baja lógica el producto 11 (Cerveza 1L, activo = false).
--      (Nota: estos tres UPDATE son preparación manual del escenario de prueba
--      mientras la tablet está sin señal; el semáforo de la tablet NO toca PostgreSQL).
--   3. Exporta la nueva instantánea a movil/servidor_snapshot.csv con \copy.
--   4. Muestra el estado del servidor ya preparado: 200005 pedidos y stock
--      1, 40, 30, 0, 10. Después de la simulación, consulta_final.sql tiene que
--      mostrar exactamente lo mismo (la tablet no cambió nada).
-- ============================================================================

\set ON_ERROR_STOP on

-- Protección: aborta si alguien lo corre por error en bd2_tp3 u otra base.
DO $$
BEGIN
    IF current_database() <> 'bd2_tp8' THEN
        RAISE EXCEPTION 'Este script es solo para bd2_tp8 (estás en %)', current_database();
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- PASO 0: Estado inicial limpio de los productos de prueba (idempotencia)
-- ----------------------------------------------------------------------------
UPDATE producto SET stock  = 3       WHERE id_producto = 2;
UPDATE producto SET precio = 1400.00 WHERE id_producto = 3;
UPDATE producto SET activo = true    WHERE id_producto = 11;

-- ----------------------------------------------------------------------------
-- PASO 1: CONSULTA INICIAL EN POSTGRESQL (ANTES DE LA SIMULACIÓN)
-- Se verifica la cantidad total de pedidos y el stock/precio/activo de los
-- 5 productos fijos elegidos en el Bloque B.
-- ----------------------------------------------------------------------------
\echo '=== 1. CONSULTA INICIAL EN bd2_tp8 (ANTES DE PREPARAR Y SIMULAR) ==='

SELECT count(*) AS total_pedidos_antes FROM pedido;

SELECT id_producto, nombre, precio, stock, activo
FROM producto
WHERE id_producto IN (2, 3, 9, 10, 11)
ORDER BY id_producto;

-- ----------------------------------------------------------------------------
-- PASO 2: PREPARACIÓN MANUAL EN LA COPIA DEL SERVIDOR (bd2_tp8) PARA C2, C3 Y C4
-- Mientras la tablet armó borradores sin señal con la instantánea inicial:
--   * C2 (REQ-01): el precio del producto 3 (Agua mineral 2L) sube de $1400,00
--                  (140000 centavos) a $1600,00 (160000 centavos).
--   * C3 (REQ-02): el stock del producto 2 (Medialunas x6) baja de 3 a 1: otra
--                  tablet vendió 2 unidades y el servidor ya lo registró.
--   * C4 (REQ-02): el producto 11 (Cerveza 1L) se da de baja (activo = false).
-- Ninguno de los tres cambios crea pedidos. Son preparación manual del escenario:
-- el semáforo de la tablet nunca modifica PostgreSQL.
-- ----------------------------------------------------------------------------
\echo '=== 2. PREPARACION MANUAL EN bd2_tp8: SUBA DE PRECIO (C2), VENTA DE OTRA TABLET (C3) Y BAJA LOGICA (C4) ==='

BEGIN;

-- Caso C2: Agua mineral 2L pasa de $1400.00 a $1600.00 (160000 centavos)
UPDATE producto
SET precio = 1600.00
WHERE id_producto = 3;

-- Caso C3: venta de otra tablet. Medialunas x6 pasa de stock 3 a 1
UPDATE producto
SET stock = 1
WHERE id_producto = 2;

-- Caso C4: Cerveza 1L pasa a activo = false (viajará como lápida eliminado = 't')
UPDATE producto
SET activo = false
WHERE id_producto = 11;

COMMIT;

-- Verificación en la vista v_snapshot_movil tras preparar C2, C3 y C4:
SELECT *
FROM v_snapshot_movil
WHERE producto_id IN (2, 3, 9, 10, 11)
ORDER BY producto_id;

-- ----------------------------------------------------------------------------
-- PASO 3: EXPORTAR LA NUEVA INSTANTÁNEA PARA LA TABLET
-- Genera movil/servidor_snapshot.csv con el nuevo precio del prod. 3 (160000),
-- el stock nuevo del prod. 2 (1) y la lápida del prod. 11 (eliminado = 't',
-- disponible = 'f').
-- ----------------------------------------------------------------------------
\echo '=== 3. EXPORTANDO NUEVA INSTANTANEA A movil/servidor_snapshot.csv ==='

\copy (SELECT * FROM v_snapshot_movil ORDER BY producto_id) TO 'movil/servidor_snapshot.csv' CSV HEADER

-- ----------------------------------------------------------------------------
-- PASO 4: ESTADO DEL SERVIDOR YA PREPARADO (ANTES DE SIMULAR)
-- Es la referencia para consulta_final.sql, que se corre DESPUÉS de
-- movil/casos_sqlite.sql y tiene que dar exactamente lo mismo:
--   200005 pedidos y stock 1, 40, 30, 0 y 10.
-- El stock del producto 2 pasó de 3 a 1 por la preparación manual del C3 (paso 2),
-- no por la simulación.
-- ----------------------------------------------------------------------------
\echo '=== 4. ESTADO DE bd2_tp8 YA PREPARADO (REFERENCIA PARA LA CONSULTA FINAL) ==='

SELECT count(*) AS total_pedidos_preparado FROM pedido;

SELECT id_producto, nombre, precio, stock, activo
FROM producto
WHERE id_producto IN (2, 3, 9, 10, 11)
ORDER BY id_producto;
