-- ============================================================================
-- TP8 · Food Store · Semáforo de sincronización (consigna 2.b)
-- Compara cada solicitud PENDIENTE de cola_sync contra la última instantánea
-- del servidor (snapshot_servidor) y guarda el resultado en cola_sync:
--
--   ROJO     RECHAZADO          producto inexistente, dado de baja, no
--                               disponible o cantidad mayor que el stock
--   AMARILLO CONFLICTO          no hay rojo, pero cambió algún precio
--   VERDE    SIMULADO_APROBADO  todo coincide (es una SIMULACIÓN, NO una venta)
--
-- Si en la misma solicitud hay rojo y amarillo, gana el rojo.
--
-- Se corre desde food-store/:
--   sqlite3 movil/foodstore_movil.db ".read movil/semaforo.sql"
-- Antes hay que haber cargado una instantánea con importar_catalogo.sql.
--
-- NO se conecta a PostgreSQL ni modifica nada ahí: el móvil propone, el
-- servidor dispone. La venta real solo existiría cuando el servidor vuelva a
-- validar stock y precio en su propia transacción.
--
-- Idempotencia: solo se evalúan las solicitudes en estado PENDIENTE. Una vez
-- evaluada, la solicitud conserva su resultado aunque el script se corra de
-- nuevo (caso C6).
-- ============================================================================

.bail on

PRAGMA foreign_keys = ON;   -- antes del BEGIN, en cada conexión

BEGIN;

WITH
-- Un renglón por cada ítem de cada solicitud pendiente.
-- LEFT JOIN a item_borrador: un borrador sin ítems también se evalúa (rojo).
-- LEFT JOIN a snapshot_servidor: si el producto no está en la instantánea,
-- s.* queda en NULL; por eso se pregunta "s.producto_id IS NULL" explícitamente
-- (comparar i.cantidad > NULL daría NULL y el producto pasaría sin rojo).
evaluacion_item AS (
    SELECT c.solicitud_uuid,
           i.producto_id,
           CASE
               WHEN i.producto_id IS NULL
                    THEN 'borrador sin ítems'
               WHEN s.producto_id IS NULL
                    THEN 'producto inexistente: producto ' || i.producto_id
               WHEN s.eliminado = 't'
                    THEN 'dado de baja: producto ' || i.producto_id
               WHEN s.disponible = 'f'
                    THEN 'no disponible: producto ' || i.producto_id
               WHEN i.cantidad > s.stock
                    THEN printf('stock insuficiente: producto %d (pide %d, hay %d)',
                                i.producto_id, i.cantidad, s.stock)
           END AS rojo,                       -- NULL = este ítem no tiene rojo
           CASE
               WHEN s.producto_id IS NOT NULL
                AND i.precio_centavos_visto <> s.precio_centavos
                    THEN printf('precio cambió: producto %d (visto %d, actual %d centavos)',
                                i.producto_id, i.precio_centavos_visto, s.precio_centavos)
           END AS amarillo                    -- NULL = el precio no cambió
    FROM cola_sync c
    LEFT JOIN item_borrador     i ON i.id_local    = c.id_local
    LEFT JOIN snapshot_servidor s ON s.producto_id = i.producto_id
    WHERE c.estado = 'PENDIENTE'
    ORDER BY c.solicitud_uuid, i.producto_id
),
-- Un renglón por solicitud: count() solo cuenta los valores no NULL.
evaluacion AS (
    SELECT solicitud_uuid,
           CASE
               WHEN count(rojo)     > 0 THEN 'RECHAZADO'
               WHEN count(amarillo) > 0 THEN 'CONFLICTO'
               ELSE                          'SIMULADO_APROBADO'
           END AS estado,
           CASE
               WHEN count(rojo)     > 0 THEN group_concat(rojo, '; ')
               WHEN count(amarillo) > 0 THEN group_concat(amarillo, '; ')
               ELSE 'todo coincide con la instantánea (simulación, no es una venta)'
           END AS motivo
    FROM evaluacion_item
    GROUP BY solicitud_uuid
)
UPDATE cola_sync
SET    estado = evaluacion.estado,
       motivo = evaluacion.motivo
FROM   evaluacion
WHERE  cola_sync.solicitud_uuid = evaluacion.solicitud_uuid
  AND  cola_sync.estado = 'PENDIENTE'                 -- nunca se reevalúa lo ya resuelto
  AND  EXISTS (SELECT 1 FROM snapshot_servidor);      -- sin instantánea cargada no se evalúa nada

COMMIT;

-- Resultado
.headers on
.mode column
SELECT (SELECT count(*) FROM snapshot_servidor) AS filas_instantanea,
       (SELECT DISTINCT capturado_en FROM snapshot_servidor) AS fecha_de_la_copia,
       (SELECT count(*) FROM cola_sync WHERE estado = 'PENDIENTE') AS quedan_pendientes;
SELECT solicitud_uuid, id_local, estado, motivo
FROM cola_sync
ORDER BY creada_en, solicitud_uuid;
