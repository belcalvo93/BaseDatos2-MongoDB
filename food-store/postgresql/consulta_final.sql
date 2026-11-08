-- ============================================================================
-- TP8 · Food Store · Consulta final en PostgreSQL (consigna 2.c)
-- Se corre DESPUÉS de movil/casos_sqlite.sql, desde food-store/:
--   psql -U postgres -d bd2_tp8 -f postgresql/consulta_final.sql > evidencias/salida_consulta_final_postgresql.txt 2>&1
--
-- Muestra que la simulación de la tablet no creó pedidos ni cambió el stock:
-- se compara con el paso 4 de casos_servidor.sql (servidor ya preparado):
-- 200005 pedidos; stock 1, 40, 30, 0 y 10.
-- Respecto del estado inicial (paso 1: stock 3, 40, 30, 0, 10), lo único distinto
-- en bd2_tp8 es lo que se preparó a mano ANTES de simular: precio del producto 3
-- (C2), stock del producto 2 de 3 a 1 (C3, venta de otra tablet) y activo del
-- producto 11 (C4). La simulación no cambió nada.
-- Solo lee: no modifica nada.
-- ============================================================================

\set ON_ERROR_STOP on

DO $$
BEGIN
    IF current_database() <> 'bd2_tp8' THEN
        RAISE EXCEPTION 'Este script es solo para bd2_tp8 (estás en %)', current_database();
    END IF;
END $$;

\echo '=== CONSULTA FINAL EN bd2_tp8 (DESPUÉS DE CORRER LA SIMULACIÓN EN SQLITE) ==='

SELECT now() AS momento_de_la_consulta;

SELECT count(*) AS total_pedidos_despues FROM pedido;          -- esperado: 200005

SELECT id_producto, nombre, precio, stock, activo
FROM producto
WHERE id_producto IN (2, 3, 9, 10, 11)
ORDER BY id_producto;                                            -- stock esperado: 1, 40, 30, 0, 10
