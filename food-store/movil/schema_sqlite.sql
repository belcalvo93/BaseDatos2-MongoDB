-- ============================================================================
-- TP8 · Food Store · Base de la tablet (SQLite)
-- Esquema de la base offline: 5 tablas STRICT + 1 índice único parcial + 1 vista.
-- Se corre con:  sqlite3 movil/foodstore_movil.db ".read movil/schema_sqlite.sql"
-- Se puede correr dos veces seguidas: al principio se borra lo anterior.
-- No crea datos de prueba: solo estructura.
-- ============================================================================

-- Las claves foráneas vienen APAGADAS en cada conexión nueva.
-- Tiene que ir antes de cualquier BEGIN (dentro de una transacción no hace nada).
PRAGMA foreign_keys = ON;

-- ----------------------------------------------------------------------------
-- Limpieza para poder correr el script dos veces sin error.
-- Orden obligatorio: primero la vista, después las hijas y al final las padres.
-- Con las FK activas no se puede borrar una tabla padre si todavía la referencia
-- una tabla hija que tiene filas.
-- ----------------------------------------------------------------------------
DROP VIEW IF EXISTS v_catalogo_disponible;   -- depende de producto_cache
DROP TABLE IF EXISTS cola_sync;              -- hija de pedido_borrador
DROP TABLE IF EXISTS item_borrador;          -- hija de pedido_borrador y de producto_cache
DROP TABLE IF EXISTS pedido_borrador;        -- padre de item_borrador y cola_sync
DROP TABLE IF EXISTS producto_cache;         -- padre de item_borrador
DROP TABLE IF EXISTS snapshot_servidor;      -- no tiene dependencias (la usa el semáforo)

-- ----------------------------------------------------------------------------
-- 1) snapshot_servidor
-- Copia fiel del CSV que exporta PostgreSQL desde la vista v_snapshot_movil.
-- Se crea ANTES del .import: si no existe, .import la crea con todo TEXT y sin STRICT.
-- Los booleanos llegan como texto 't'/'f' porque así los escribe el \copy de psql;
-- se guardan tal cual para que la importación no necesite transformaciones.
-- Incluye las lápidas (productos dados de baja) para poder rechazar los borradores
-- que los usan.
-- ----------------------------------------------------------------------------
CREATE TABLE snapshot_servidor (
    producto_id     INTEGER PRIMARY KEY,                                  -- el mismo id del servidor
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),        -- centavos, nunca REAL
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      TEXT    NOT NULL CHECK (disponible IN ('t','f')),     -- 't' = activo y con stock
    eliminado       TEXT    NOT NULL CHECK (eliminado  IN ('t','f')),     -- 't' = dado de baja (lápida)
    capturado_en    TEXT    NOT NULL                                      -- fecha de la copia (ISO 8601)
) STRICT;

-- ----------------------------------------------------------------------------
-- 2) producto_cache
-- Catálogo que queda guardado en la tablet. Se carga desde snapshot_servidor
-- con un upsert: la fila nunca se borra, la baja solo marca eliminado = 1
-- (lápida), así los borradores viejos siguen teniendo su referencia válida.
-- Los booleanos acá ya son INTEGER 0/1 porque SQLite no tiene tipo booleano.
-- ----------------------------------------------------------------------------
CREATE TABLE producto_cache (
    producto_id      INTEGER PRIMARY KEY,                                 -- mismo id que en el servidor
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),       -- centavos, nunca REAL
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),           -- stock al momento de la copia (orientativo)
    disponible_visto INTEGER NOT NULL CHECK (disponible_visto IN (0,1)),  -- 1 = se podía vender
    eliminado        INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0,1)), -- 1 = lápida
    capturado_en     TEXT    NOT NULL                                     -- cuándo se copió
) STRICT;

-- ----------------------------------------------------------------------------
-- 3) pedido_borrador
-- Cabecera del pedido armado sin señal. NO es una venta: no descuenta stock,
-- no está pagado y el servidor todavía no lo conoce.
-- id_local es un UUID generado en la tablet (PRIMARY KEY) para no depender del
-- servidor; usuario_id_servidor es un id inventado, nunca datos personales.
-- ----------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local            TEXT    PRIMARY KEY,
    usuario_id_servidor INTEGER NOT NULL,
    forma_pago          TEXT    NOT NULL
                        CHECK (forma_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    creado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;

-- ----------------------------------------------------------------------------
-- 4) item_borrador
-- Líneas del borrador. La PK es compuesta (id_local, producto_id): un mismo
-- producto no se repite dentro del borrador (se suma la cantidad).
-- precio_centavos_visto es el precio CONGELADO al armar el pedido; si el
-- servidor lo cambia después, el semáforo lo detecta comparando contra
-- snapshot_servidor.precio_centavos.
-- La FK a producto_cache no lleva ON DELETE: borrar un producto del caché
-- queda prohibido, justamente para no romper las líneas ya cargadas.
-- ----------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL
                          REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL
                          REFERENCES producto_cache(producto_id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),          -- 0 o negativo se rechaza (C7)
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0), -- centavos, nunca REAL
    PRIMARY KEY (id_local, producto_id)
) STRICT;

-- ----------------------------------------------------------------------------
-- 5) cola_sync
-- Cola de envíos hacia el servidor. Cada envío es una solicitud con su UUID
-- propio: el mismo borrador puede generar varias solicitudes (por ejemplo, tras
-- aceptar un cambio de precio en C2), por eso la PK es solicitud_uuid y no
-- id_local.
-- estado: PENDIENTE -> el semáforo todavía no la evaluó; CONFLICTO -> cambió el
-- precio y decide el cliente; RECHAZADO -> producto inexistente, no disponible,
-- dado de baja o sin stock; SIMULADO_APROBADO -> pasaría las validaciones del
-- servidor (NO es una venta).
-- motivo queda como texto libre para auditar por qué terminó en ese estado.
-- ----------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,                                      -- no cambia si se reintenta (C6)
    id_local       TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                   CHECK (estado IN ('PENDIENTE','CONFLICTO','RECHAZADO','SIMULADO_APROBADO')),
    motivo         TEXT,                                                  -- explicación legible del resultado
    creada_en      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;

-- ----------------------------------------------------------------------------
-- Índice único PARCIAL: un borrador no puede tener dos envíos PENDIENTE a la vez.
-- Es parcial (WHERE estado = 'PENDIENTE') a propósito: una vez resuelta la
-- solicitud, el borrador puede reenviarse con otro UUID (caso C2: el cliente
-- acepta el precio nuevo). Un UNIQUE total sobre id_local lo impediría.
-- ----------------------------------------------------------------------------
CREATE UNIQUE INDEX ux_cola_una_pendiente
    ON cola_sync (id_local)
    WHERE estado = 'PENDIENTE';

-- ----------------------------------------------------------------------------
-- Vista v_catalogo_disponible
-- Lo que ve el vendedor en la tablet cuando NO hay señal (caso C1): solo los
-- productos que se pueden vender, es decir ni lápidas ni productos sin stock.
-- El precio se muestra en pesos (precio_centavos / 100.0) solo para leerlo;
-- lo que se guarda y se compara siempre es precio_centavos INTEGER.
-- ----------------------------------------------------------------------------
CREATE VIEW v_catalogo_disponible AS
SELECT producto_id,
       nombre,
       precio_centavos / 100.0 AS precio,   -- solo para mostrar; lo guardado sigue en centavos INTEGER
       stock_visto
FROM producto_cache
WHERE eliminado = 0 AND disponible_visto = 1;
