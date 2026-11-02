-- ============================================================================
-- TP8 · Food Store · Cargar la instantánea en la tablet (consigna 2.a)
-- Lee servidor_snapshot.csv (exportado desde v_snapshot_movil en bd2_tp8),
-- lo guarda en snapshot_servidor y actualiza producto_cache con un upsert.
--
-- Se corre desde la carpeta food-store/ (igual que los demás scripts):
--   sqlite3 movil/foodstore_movil.db ".read movil/importar_catalogo.sql"
--
-- Requiere que antes se haya corrido schema_sqlite.sql (las tablas STRICT
-- tienen que existir: si no, .import crea snapshot_servidor con todo TEXT).
-- Se puede correr cada vez que llega una instantánea nueva.
-- ============================================================================

.bail on

-- Las claves foráneas vienen apagadas en cada conexión: se prenden ANTES del BEGIN.
PRAGMA foreign_keys = ON;

BEGIN;

-- 1) La instantánea nueva reemplaza a la anterior.
DELETE FROM snapshot_servidor;

-- 2) Importar el CSV salteando la fila de encabezados.
--    Como la tabla es STRICT, una fila con un tipo inválido corta el script.
--    La ruta es relativa a food-store/, desde donde se corre el script.
.import --csv --skip 1 movil/servidor_snapshot.csv snapshot_servidor

-- 3) Upsert al caché de la tablet.
--    No se borra y se recarga: si un producto se dio de baja, su fila se
--    ACTUALIZA con eliminado = 1 (lápida) y sigue existiendo, así los
--    item_borrador que lo usan no rompen la clave foránea (caso C4).
--    Los booleanos llegan como 't'/'f' y se pasan a 1/0.
--    El "WHERE true" lo pide SQLite para poder usar ON CONFLICT con un SELECT.
INSERT INTO producto_cache (producto_id, nombre, precio_centavos, stock_visto,
                            disponible_visto, eliminado, capturado_en)
SELECT producto_id, nombre, precio_centavos, stock,
       (disponible = 't'), (eliminado = 't'), capturado_en
FROM snapshot_servidor
WHERE true
ON CONFLICT (producto_id) DO UPDATE SET
    nombre           = excluded.nombre,
    precio_centavos  = excluded.precio_centavos,
    stock_visto      = excluded.stock_visto,
    disponible_visto = excluded.disponible_visto,
    eliminado        = excluded.eliminado,
    capturado_en     = excluded.capturado_en;

COMMIT;

-- 4) Verificación: qué se cargó y de qué fecha es la copia.
.headers on
.mode column
SELECT (SELECT count(*) FROM snapshot_servidor)     AS filas_instantanea,
       (SELECT count(*) FROM producto_cache)        AS filas_cache,
       (SELECT count(*) FROM producto_cache WHERE eliminado = 1) AS lapidas,
       (SELECT count(*) FROM v_catalogo_disponible) AS catalogo_disponible;
SELECT DISTINCT capturado_en AS fecha_de_la_copia FROM snapshot_servidor;
