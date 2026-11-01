-- ============================================================================
-- Trabajo Práctico N.º 7 — Migración a MongoDB (Food Store)
-- Archivo: consultas_postgresql.sql
-- Consigna 5 (Belén Calvo): consultas equivalentes en PostgreSQL (bd2_tp3).
-- Ejecutar con: psql -U postgres -d bd2_tp3 -f consultas_postgresql.sql
-- Script de solo lectura (SELECT). No modifica datos ni estructura.
--
-- Todas las consultas se limitan a los 8 pedidos migrados
-- (1, 2, 3, 4, 5, 45018, 59428, 74364); sin ese filtro, PostgreSQL devolvería
-- toda la base y las cantidades no serían comparables con MongoDB.
-- eliminado = false: ninguna de las tablas que intervienen tiene esa columna
-- en bd2_tp3 (ver nota en consultas_mongodb.js), por eso no se aplica.
-- total = SUM(cantidad * precio_unitario): pedido no guarda el total (3FN).
-- ============================================================================
\set ON_ERROR_STOP on
SET TIME ZONE 'UTC';   -- fechas en UTC, igual que en MongoDB
SELECT current_database();

-- ----------------------------------------------------------------------------
-- b) Pedidos con forma_pago = 'EFECTIVO'  (equivale a la consulta b de Mongo)
-- ----------------------------------------------------------------------------
SELECT p.id_pedido, p.fecha, p.forma_pago,
       SUM(dp.cantidad * dp.precio_unitario) AS total
FROM pedido p
INNER JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
  AND p.forma_pago = 'EFECTIVO'
GROUP BY p.id_pedido, p.fecha, p.forma_pago
ORDER BY p.id_pedido;

-- ----------------------------------------------------------------------------
-- c) Pedidos que contienen id_producto = 1 (Pan de campo 1kg)
--    En PostgreSQL hace falta unir 3 tablas; en MongoDB es un solo find
--    sobre el arreglo lineas.
-- ----------------------------------------------------------------------------
SELECT p.id_pedido, p.forma_pago, pr.nombre, dp.cantidad, dp.precio_unitario
FROM pedido p
INNER JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
INNER JOIN producto pr       ON pr.id_producto = dp.id_producto
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
  AND dp.id_producto = 1
ORDER BY p.id_pedido;

-- ----------------------------------------------------------------------------
-- Control adicional: a) todos los pedidos migrados
-- ----------------------------------------------------------------------------
SELECT id_pedido, forma_pago
FROM pedido
WHERE id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
ORDER BY id_pedido;

-- ----------------------------------------------------------------------------
-- Control adicional: d) pedidos con total > 10000, de mayor a menor
-- ----------------------------------------------------------------------------
SELECT p.id_pedido, p.forma_pago,
       SUM(dp.cantidad * dp.precio_unitario) AS total
FROM pedido p
INNER JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
GROUP BY p.id_pedido, p.forma_pago
HAVING SUM(dp.cantidad * dp.precio_unitario) > 10000
ORDER BY total DESC;
