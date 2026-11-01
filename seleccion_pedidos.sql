-- ============================================================================
-- Trabajo Práctico N.º 7 — Migración a MongoDB (Food Store)
-- Consigna 1: Selección de pedidos desde PostgreSQL (bd2_tp3)
-- Integrante: Bruno Fiouchetta
-- Importante: Script de solo lectura (SELECT). No modifica datos ni estructura.
-- ============================================================================

SELECT current_database();
\set ON_ERROR_STOP on

-- ----------------------------------------------------------------------------
-- 1. Consulta principal: pedidos seleccionados con cliente, productos y líneas
--    IDs elegidos (8 pedidos, 30 líneas en total):
--    1, 2, 3, 4, 5, 45018, 59428, 74364
--    (45018 se agregó para tener un pedido de 1 sola línea)
-- ----------------------------------------------------------------------------
SELECT
    p.id_pedido,
    p.fecha,
    p.forma_pago,
    c.id_cliente,
    c.nombre || ' ' || c.apellido AS cliente_nombre,
    c.email                       AS cliente_email,
    dp.id_producto,
    pr.nombre                     AS producto_nombre,
    dp.cantidad,
    dp.precio_unitario,
    (dp.cantidad * dp.precio_unitario) AS subtotal_linea
FROM pedido p
INNER JOIN cliente c
    ON c.id_cliente = p.id_cliente
INNER JOIN detalle_pedido dp
    ON dp.id_pedido = p.id_pedido
INNER JOIN producto pr
    ON pr.id_producto = dp.id_producto
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
ORDER BY p.id_pedido, dp.id_producto;

-- ----------------------------------------------------------------------------
-- 2. Resumen de control por pedido (para verificar la carga en Consigna 2:
--    cantidad de líneas y total calculado por pedido)
-- ----------------------------------------------------------------------------
SELECT
    p.id_pedido,
    p.fecha,
    p.forma_pago,
    c.id_cliente,
    c.nombre || ' ' || c.apellido           AS cliente_nombre,
    COUNT(dp.id_detalle)                    AS cantidad_lineas,
    SUM(dp.cantidad * dp.precio_unitario)   AS total_pedido
FROM pedido p
INNER JOIN cliente c
    ON c.id_cliente = p.id_cliente
INNER JOIN detalle_pedido dp
    ON dp.id_pedido = p.id_pedido
WHERE p.id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
GROUP BY p.id_pedido, p.fecha, p.forma_pago, c.id_cliente, c.nombre, c.apellido
ORDER BY p.id_pedido;

-- ----------------------------------------------------------------------------
-- 3. Generación directa de los documentos JSON según el esquema de "pedidos"
--    (_id = id_pedido, fecha, forma_pago, cliente embebido y arreglo lineas[])
--    Lista para utilizar como base del insertMany() en MongoDB.
-- ----------------------------------------------------------------------------
SELECT jsonb_pretty(
    jsonb_agg(documento ORDER BY (documento->>'_id')::bigint)
) AS documentos_pedidos_json
FROM (
    SELECT jsonb_build_object(
        '_id', p.id_pedido,
        'fecha', to_char(p.fecha AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
        'forma_pago', p.forma_pago,
        'total', SUM(dp.cantidad * dp.precio_unitario),
        'cliente', jsonb_build_object(
            'id_cliente', c.id_cliente,
            'nombre', c.nombre || ' ' || c.apellido,
            'email', c.email
        ),
        'lineas', jsonb_agg(
            jsonb_build_object(
                'id_producto', dp.id_producto,
                'nombre', pr.nombre,
                'cantidad', dp.cantidad,
                'precio_unitario', dp.precio_unitario
            )
            ORDER BY dp.id_producto
        )
    ) AS documento
    FROM pedido p
    INNER JOIN cliente c
        ON c.id_cliente = p.id_cliente
    INNER JOIN detalle_pedido dp
        ON dp.id_pedido = p.id_pedido
    INNER JOIN producto pr
        ON pr.id_producto = dp.id_producto
    WHERE p.id_pedido IN (1, 2, 3, 4, 5, 45018, 59428, 74364)
    GROUP BY p.id_pedido, p.fecha, p.forma_pago, c.id_cliente, c.nombre, c.apellido, c.email
) sub;
