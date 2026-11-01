# Requirements — TP8 Food Store: Base SQLite y Semáforo de Sincronización

**Proyecto:** Trabajo Práctico N.º 8 — Base de Datos II  
**Grupo:** Belén Calvo, Elías Tello, Hernán González, Bruno Fiouchetta  
**Fecha:** Noviembre 2026

---

## Contexto

La tablet del food truck trabaja offline con SQLite. Consulta un catálogo copiado de PostgreSQL, arma borradores de pedido y los encola. Al recuperar señal, se **simula** la sincronización mediante un semáforo que compara cada solicitud pendiente contra una instantánea del servidor y decide si aprobarla, rechazarla o marcarla como conflicto.

**Reglas fundamentales:**
- **La tablet propone, el servidor dispone:** SQLite solo prepara borradores; PostgreSQL es la única fuente de verdad para precio, stock y ventas.
- **`SIMULADO_APROBADO` no es una venta:** la simulación verifica que pasaría las validaciones del servidor, pero no modifica nada en PostgreSQL.
- **Precios en centavos:** todos los importes se guardan como `INTEGER` (centavos), nunca `REAL`.
- **Tablas STRICT:** todas las tablas SQLite usan `STRICT` y `PRAGMA foreign_keys = ON;` está activo en cada conexión.

---

## Requisitos Funcionales (Notación EARS)

### REQ-01: Detección de conflicto por cambio de precio

**WHEN** el precio actual del servidor (`snapshot_servidor.precio_centavos`) es distinto del precio visto en el borrador (`item_borrador.precio_centavos_visto`), **AND** el producto existe, está disponible, no fue dado de baja y la cantidad solicitada no supera el stock,  
**THE SYSTEM SHALL** marcar la solicitud con `estado = 'CONFLICTO'` en `cola_sync`, registrar en `motivo` el identificador del producto cuyo precio cambió, y NO modificar ningún dato en PostgreSQL.

**Se prueba con:** C2

---

### REQ-02: Rechazo por producto inválido o stock insuficiente

**WHEN** al menos uno de los ítems del borrador cumple alguna de estas condiciones:
- el `producto_id` no existe en `snapshot_servidor`,
- el producto tiene `disponible = 'f'`,
- el producto tiene `eliminado = 't'`,
- la `cantidad` solicitada es mayor que el `stock` disponible en la instantánea,

**THE SYSTEM SHALL** marcar la solicitud con `estado = 'RECHAZADO'` en `cola_sync`, registrar en `motivo` la causa específica del rechazo (producto inexistente, no disponible, dado de baja o stock insuficiente) junto con el `producto_id` afectado, y NO modificar ningún dato en PostgreSQL.

**IF** una misma solicitud tiene a la vez ítems con problemas de existencia, disponibilidad, baja o stock (rojo) e ítems con cambio de precio (amarillo), **THEN THE SYSTEM SHALL** asignar `RECHAZADO` (gana el rojo).

**Se prueba con:** C3 y C4

---

### REQ-03: Idempotencia del semáforo

**WHEN** se intenta evaluar una solicitud cuyo `solicitud_uuid` ya existe en `cola_sync` con un `estado` distinto de `'PENDIENTE'`,  
**THE SYSTEM SHALL** devolver el resultado guardado previamente sin reevaluar la solicitud, garantizando que una misma solicitud no cambie de estado por reintentos.

**IF** se intenta insertar en `cola_sync` un registro con un `solicitud_uuid` que ya existe, **THEN THE SYSTEM SHALL** rechazar la inserción con un error de clave primaria y no crear un envío duplicado.

**Se prueba con:** C6

---

### REQ-04: Validación de ítems inválidos en borradores

**WHEN** se intenta insertar en `item_borrador`:
- un ítem con `cantidad = 0` o `cantidad < 0`, **OR**
- un ítem cuyo `producto_id` no existe en `producto_cache`,

**THE SYSTEM SHALL** rechazar la operación con un error (violación de restricción `CHECK` o clave foránea respectivamente), deshacer la transacción completa mediante un `ROLLBACK` explícito, y garantizar que NO quede ninguna fila nueva en `item_borrador`, `pedido_borrador` ni `cola_sync`.

> Nota: en SQLite, un error de restricción solo deshace **la sentencia** que falló; las sentencias anteriores de la misma transacción siguen vigentes. Por eso el `ROLLBACK` tiene que estar escrito en el script.

**Se prueba con:** C7

---

## Casos de Prueba Asociados

| Caso | Descripción | Requisito |
|:---:|---|:---:|
| **C1** | Consultar el catálogo disponible sin servidor (`v_catalogo_disponible`) | — |
| **C2** | Borrador válido, pero el precio sube en el servidor antes de sincronizar | REQ-01 |
| **C3** | Borrador solicita más unidades de las disponibles en stock | REQ-02 |
| **C4** | Borrador con producto que luego se da de baja (`activo = false`) | REQ-02 |
| **C5** | Borrador sin cambios en precio, stock ni disponibilidad | — |
| **C6** | Reenvío de una solicitud con el mismo UUID | REQ-03 |
| **C7** | Intentar crear ítem con cantidad 0 o producto inexistente | REQ-04 |

---

## Restricciones No Funcionales

1. **Arquitectura:** La base SQLite es autónoma para consultas offline. La sincronización tiene dos movimientos: **bajar** la instantánea del catálogo (servidor → tablet) y **subir** las solicitudes pendientes para validarlas (tablet → servidor, en el TP solo simulado).
2. **Seguridad:** No viajan datos personales de clientes (Ley 25.326 de Protección de los Datos Personales, art. 4: datos "adecuados, pertinentes y no excesivos"; art. 9: seguridad de los datos).
3. **Integridad:** Las claves foráneas están activas (`PRAGMA foreign_keys = ON`); las transacciones garantizan atomicidad.
4. **Precisión:** Los precios se almacenan en centavos enteros para evitar errores de redondeo binario.
5. **Trazabilidad:** Cada solicitud conserva el `motivo` del resultado para auditoría y depuración.

---

## Fuera de Alcance

- Implementación de la venta real en PostgreSQL (procedimiento `sp_crear_pedido`).
- Protección definitiva de idempotencia en el servidor (tabla `solicitud_movil`).
- Interfaz gráfica o aplicación de la tablet.
- Estrategia de resolución automática de conflictos de precio.
