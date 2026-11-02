-- ============================================================================
-- TP8 · Food Store · Instantánea del catálogo para la tablet (consigna 2.a)
-- Crea la vista v_snapshot_movil en la COPIA bd2_tp8 (nunca en bd2_tp3).
-- Se corre desde food-store/:
--   psql -U postgres -d bd2_tp8 -f postgresql/10_snapshot_catalogo.sql
-- Se puede correr varias veces (CREATE OR REPLACE).
-- No modifica datos: solo define una vista de lectura.
-- ============================================================================

\set ON_ERROR_STOP on

-- Protección: si alguien la corre conectado a otra base, se corta acá.
DO $$
BEGIN
    IF current_database() <> 'bd2_tp8' THEN
        RAISE EXCEPTION 'Este script es solo para bd2_tp8 (estás en %)', current_database();
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- Qué viaja a la tablet: solo lo necesario para vender (consigna 1.a).
-- No viajan clientes, pedidos, descripción, categoría ni fechas de alta.
--
-- Columnas reales de nuestra base (verificadas con \d producto y \d categoria):
--   producto(id_producto, nombre, precio NUMERIC(10,2), stock, activo, id_categoria)
--   categoria(id_categoria, nombre, activo)
--
-- Decisiones del grupo:
--   * precio_centavos: el precio se pasa a centavos ENTEROS acá, una sola vez,
--     para que la tablet nunca guarde precios con decimales (REAL).
--   * disponible: se puede vender si el producto está activo, su categoría
--     está activa y tiene stock.
--   * eliminado (lápida): el producto está dado de baja si se dio de baja él
--     O su categoría. La lápida VIAJA como dato (la vista no filtra por activo):
--     la tablet saca el producto del catálogo pero conserva la fila, porque
--     algún borrador puede estar usándolo (caso C4).
--   * capturado_en: fecha y hora de la copia, en UTC e ISO 8601, para saber
--     qué tan vieja es la lista que tiene la tablet.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id_producto                                   AS producto_id,
       p.nombre,
       round(p.precio * 100)::INTEGER                  AS precio_centavos,
       p.stock,
       (p.activo AND c.activo AND p.stock > 0)         AS disponible,
       (NOT p.activo OR NOT c.activo)                  AS eliminado,
       to_char(now() AT TIME ZONE 'UTC',
               'YYYY-MM-DD"T"HH24:MI:SS"Z"')           AS capturado_en
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria;

-- ----------------------------------------------------------------------------
-- Verificación rápida
-- ----------------------------------------------------------------------------
-- Productos fijos de los casos (ver README):
SELECT * FROM v_snapshot_movil WHERE producto_id IN (2, 3, 9, 10, 11) ORDER BY producto_id;

-- Total de filas y cuántas son lápidas (tienen que viajar, no se filtran):
SELECT count(*)                          AS filas,
       count(*) FILTER (WHERE eliminado) AS lapidas,
       count(*) FILTER (WHERE disponible) AS disponibles
FROM v_snapshot_movil;
