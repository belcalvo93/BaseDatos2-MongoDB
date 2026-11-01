# Contexto TP8 · Base de Datos II · Food Store (SQLite: la base de la tablet)

> **Para la IA o el agente que lea esto:** sos asistente de un integrante del grupo en el TP8 de Base de Datos II (UTN-FRM, Tecnicatura Universitaria en Programación, Prof. Neira). Este archivo tiene la consigna, el material de la cátedra, el esquema real de nuestra base y el reparto del trabajo. **Antes de generar algo, ubicá qué bloque le toca a la persona que te habla (sección 9) y trabajá solo sobre ese bloque.**
>
> Grupo: **Belén Calvo, Elías Tello, Hernán González, Bruno Fiouchetta.**
> Fuentes: consigna `BDII_U8_TP8_Food_Store.pdf`, apunte `BDII_U8_Material_Teorico_Food_Store.pdf` (paradas 0 a 10), diapositivas "SQLite: preparación del entorno", video de la plataforma y clases del profe hasta el 29/10/2026.

---

## 1. Reglas para la IA (obligatorias)

1. **La regla de oro:** *el móvil propone, el servidor dispone.* La tablet (SQLite) solo consulta el catálogo y arma borradores. **El precio, el stock y las ventas los decide únicamente PostgreSQL.**
2. **Nunca** generes código que modifique stock, precio o pedidos de PostgreSQL como parte de la simulación. `SIMULADO_APROBADO` **no es una venta**.
3. Trabajamos sobre una **copia** de la base (`bd2_tp8`), **nunca** sobre `bd2_tp3`.
4. **Nada de datos personales reales** (contraseñas, mails, teléfonos, nombres de clientes) en SQLite, en los CSV ni en los ejemplos.
5. **Respetá los nombres de columnas de la sección 4** (los de nuestra base) y los de la sección 5 (los de la tablet). No inventes columnas. Si te falta un dato del esquema, pedile a la persona que corra `\d <tabla>` en psql.
6. **Precio en centavos (INTEGER)**, nunca `REAL` ni float, aunque algún ejemplo de clase use `REAL`. Manda la consigna.
7. **Todas las tablas SQLite con `STRICT`** y `PRAGMA foreign_keys = ON;` al principio de cada script.
8. Explicá cada script en palabras simples. **En la defensa, lo que no se puede explicar cuenta como no hecho**, y cada integrante tiene que poder explicar cualquier script.
9. Cuando propongas algo, decí cómo se prueba en el motor (una consulta, un error esperado, un `SELECT COUNT(*)` antes y después). Lo que dice la IA no es prueba.
10. En los commits **no van líneas de autoría de IA** (sin `Co-Authored-By`, sin "Generated with…"). El uso de IA se declara en la bitácora y en la DUIA.

---

## 2. Fechas

| Fecha | Qué pasa |
|---|---|
| Lun 2/11 | Posible clase (confirmar en el aula virtual) |
| Jue 5/11 | **Fin de la fase 1** del reparto (sección 9) |
| Lun 9/11 | No hay clase. **Fin de la fase 2** |
| **Jue 12/11** | **Fecha límite según Neira** para tener todo terminado (y la instancia teórica, en horario de clase) |
| Semana 13 | Ensayo de defensa en clase. Sin entregas tardías |
| Semana 14 | Segundo parcial: presencial, individual, **sin IA**, unidades 4 a 8 |

---

## 3. Consigna del TP8 (resumen fiel)

**Historia:** el food truck vende en una feria sin señal. La tablet usa SQLite, arma borradores offline, y después se **simula** la sincronización con PostgreSQL usando un **semáforo**. No se pide app ni interfaz: alcanza con SQL en SQLite (`sqlite3` CLI o DB Browser) y PostgreSQL. Python es opcional.

**Herramientas:** PostgreSQL 16+, SQLite 3.37+, **Kiro** (spec), **OpenCode** (agente **Build** para generar, agente **Plan** para revisar).

### Puntaje (aprueba con 60)

| Consigna | Qué se hace | Paradas del apunte | Puntos |
|---|---|---|---|
| 1 · La base de la tablet | Qué datos viajan, tablas SQLite, pruebas | 1 a 4 | 30 |
| 2 · Sincronizar y resolver | Instantánea, semáforo, casos C2–C6 | 5 a 8 | 35 |
| 3 · Integrar y revisar | Mapa de 3 motores, mantenimiento, code review con IA | 9 y 10 | 20 |
| 4 · Kiro, bitácora y defensa | Spec EARS, bitácora + DUIA, README, ensayo | 10 | 15 |

**Errores que más descuentan:** cambiar stock o precio del servidor desde la tablet; presentar `SIMULADO_APROBADO` como venta; entregar capturas sin scripts; aceptar lo que dijo la IA sin comprobarlo.

### Consigna 1 · La base de la tablet (30)
- **1.a Qué datos viajan (5).** Tabla corta: columnas de `producto` que viajan y las que no (datos de clientes, etc.). Dos o tres oraciones: por qué, y **quién es la fuente de verdad** (PostgreSQL). Base teórica: parada 2 y Ley 25.326 (datos "adecuados, pertinentes y no excesivos", art. 4; seguridad, art. 9).
- **1.b Las tablas (15).** `schema_sqlite.sql`, que empiece con `PRAGMA foreign_keys = ON;` y cree las 4 tablas STRICT (sección 5).
- **1.c Probarla (10).** `pruebas_sqlite.sql`:
  1. un borrador completo (borrador + ítems + solicitud) con `BEGIN … COMMIT`, y otra operación deshecha con `ROLLBACK`;
  2. **C1:** la consulta del catálogo disponible funciona sin servidor;
  3. **C7:** cantidad 0 y producto inexistente dan error y **no dejan filas nuevas** (mostrar `COUNT(*)` antes y después).

### Consigna 2 · Sincronizar y resolver (35)
- **2.a La instantánea (5).** En el PostgreSQL de pruebas crear la vista `v_snapshot_movil`, exportarla a CSV, importarla en SQLite en `snapshot_servidor` y cargar con ella `producto_cache`. Anotar la fecha de la copia.
- **2.b El semáforo (15).** Consulta o script que compare cada solicitud `PENDIENTE` con `snapshot_servidor` y guarde estado y motivo en `cola_sync`. **No se modifica nada en PostgreSQL.**
- **2.c Los casos (15, 3 cada uno).** C2 a C6 (sección 7). Para cada caso: **comando, resultado y una o dos oraciones**. Al final, una consulta en PostgreSQL que muestre que **la cantidad de pedidos y el stock no cambiaron** por la simulación. En C6, una oración sobre dónde iría la protección real (parada 8).

### Consigna 3 · Integrar y revisar (20)
- **3.a Mapa de la capa de datos (5).** Tabla o dibujo con PostgreSQL, MongoDB (TP7) y SQLite: qué guarda cada uno y quién manda sobre cada dato.
- **3.b Plan de mantenimiento (5)**, como agregado al plan de la U6: qué se respalda y cómo se prueba la restauración; qué hacen las tablets si se restaura un respaldo viejo de PostgreSQL; cada cuánto y quién revisa las solicitudes en `CONFLICTO` o `RECHAZADO`.
- **3.c Code review con IA (10).** OpenCode en el **agente Plan** revisa **todos los scripts de la cursada**. Tabla con cada hallazgo y su decisión (aceptado, corregido o descartado) y el motivo. Desarrollar **al menos 3**, de **al menos 2 unidades distintas**, con **cómo se comprobó en la base**. **Al menos uno descartado con fundamento.**

### Consigna 4 · Kiro, bitácora y defensa (15)
- **4.a Spec en Kiro (5).** **Antes de generar código:** `requirements.md` con **4 requisitos EARS**, cada uno con el caso que lo prueba, más `design.md` y `tasks.md` breves. El esquema y la simulación se generan con OpenCode (agente Build) a partir de esas tareas.
- **4.b Bitácora de IA y DUIA (5).** Al menos 3 entradas: qué se le pidió, qué se aceptó, **qué se descartó y por qué**. Más la DUIA de la cátedra.
- **4.c README y ensayo (5).** `README.md` con el orden para crear todo desde cero. Ensayo de defensa (ver sección 10).

### Qué se entrega
Un `.zip` o el enlace al repositorio con la **etiqueta `tp8`**. **El TP8 va en el mismo repo que el TP7:** `github.com/belcalvo93/BaseDatos2-MongoDB`, dentro de la carpeta `food-store/`.

```
food-store/
├── README.md
├── movil/
│   ├── schema_sqlite.sql         1.b
│   ├── pruebas_sqlite.sql        1.c
│   ├── semaforo.sql              2.b (o simulador.py)
│   ├── servidor_snapshot.csv     2.a
│   └── foodstore_movil.db
├── postgresql/
│   ├── 10_snapshot_catalogo.sql  vista v_snapshot_movil (2.a)
│   └── casos_servidor.sql        cambios en la copia para C2–C4 + consulta final (2.c)
└── docs/
    ├── informe.pdf               1.a, 2.c, 3.a, 3.b y 3.c (MÁXIMO 6 PÁGINAS)
    ├── kiro/                     requirements.md · design.md · tasks.md
    ├── bitacora_ia.md
    └── DUIA.md
```
(La carpeta `postgresql/` no la pide la consigna, pero sirve para no entregar "capturas sin scripts".)

---

## 4. Nuestra base real en PostgreSQL (`bd2_tp3` → copia `bd2_tp8`)

PostgreSQL 16, local en cada compu. Para el TP8 se trabaja sobre una copia, porque C2–C4 cambian datos del servidor:

```bash
createdb -U postgres -T bd2_tp3 bd2_tp8     # copia exacta (no tiene que haber nadie conectado a bd2_tp3)
psql -U postgres -d bd2_tp8
```

| Tabla | Columnas | Detalles |
|---|---|---|
| `producto` | `id_producto` (BIGINT IDENTITY), `nombre`, `descripcion`, `precio` NUMERIC(10,2) ≥ 0, `stock` INTEGER ≥ 0, `activo` BOOLEAN, `id_categoria` FK, `created_at` | ~50.000 filas. **Baja lógica = `activo = false`**. No tiene `eliminado` ni `disponible` |
| `categoria` | `id_categoria`, `nombre`, … | **Verificar con `\d categoria`** si tiene columna de baja |
| `cliente` | `id_cliente`, `nombre`, `apellido`, `email` UNIQUE, `telefono`, `created_at` | Datos personales: **no viajan** |
| `pedido` | `id_pedido`, `fecha` TIMESTAMPTZ, `forma_pago` (enum `EFECTIVO`/`TARJETA`/`TRANSFERENCIA`), `id_cliente` FK | No tiene `estado` ni `eliminado` |
| `detalle_pedido` | `id_detalle`, `cantidad` > 0, `precio_unitario` NUMERIC ≥ 0, `id_pedido` FK CASCADE, `id_producto` FK RESTRICT | `UNIQUE (id_pedido, id_producto)` |

**Antes de escribir la vista, correr `\d producto` y `\d categoria` en `bd2_tp8` y confirmar los nombres.**

### La vista `v_snapshot_movil` (parada 5, adaptada a nuestras columnas)

El apunte la escribe sobre el esquema de la cátedra (`p.id`, `p.disponible`, `p.eliminado`, `c.eliminado`). El profe pidió armarla **con los nombres reales de nuestras columnas**. Propuesta:

```sql
CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id_producto                    AS producto_id,
       p.nombre,
       round(p.precio * 100)::INTEGER   AS precio_centavos,   -- la conversión se hace acá, una vez
       p.stock,
       (p.activo AND p.stock > 0)       AS disponible,        -- decisión del grupo (documentar)
       (NOT p.activo)                   AS eliminado,         -- la lápida: la baja viaja como dato
       now()                            AS capturado_en       -- la fecha de la lista
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria;
-- Si categoria tiene columna de baja: eliminado = (NOT p.activo OR <baja de categoría>)
```

**Lápida:** el producto dado de baja **sigue viajando**, marcado `eliminado = true`. La tablet lo saca del catálogo pero **conserva la fila**, porque algún borrador puede usarlo. Por eso la vista **no filtra** por `activo`.

**Exportar** (desde la carpeta `food-store/movil/`):
```sql
\copy (SELECT * FROM v_snapshot_movil) TO 'servidor_snapshot.csv' CSV HEADER
```
En el CSV los booleanos vienen como **`t` / `f`**.

> Para los casos alcanza con unos pocos productos. Si exportar 50.000 filas molesta, se puede exportar `SELECT * FROM v_snapshot_movil WHERE producto_id IN (…)` con los ids fijos de la sección 7, y documentarlo.

---

## 5. La base de la tablet (SQLite) — esquema del apunte, parada 3

Usar estos nombres (son los del kit de la cátedra):

```sql
PRAGMA foreign_keys = ON;   -- siempre, al abrir la base y ANTES de cualquier BEGIN

CREATE TABLE producto_cache (
    producto_id      INTEGER PRIMARY KEY,                               -- el mismo id que en el servidor
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),         -- solo orientativo
    disponible_visto INTEGER NOT NULL CHECK (disponible_visto IN (0,1)),
    eliminado        INTEGER NOT NULL DEFAULT 0 CHECK (eliminado IN (0,1)),
    capturado_en     TEXT    NOT NULL                                   -- cuándo se copió
) STRICT;

CREATE TABLE pedido_borrador (
    id_local            TEXT    PRIMARY KEY,                            -- UUID creado en la tablet
    usuario_id_servidor INTEGER NOT NULL,                               -- id inventado del vendedor, no datos reales
    forma_pago          TEXT    NOT NULL
                        CHECK (forma_pago IN ('EFECTIVO','TARJETA','TRANSFERENCIA')),
    creado_en           TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;

CREATE TABLE item_borrador (
    id_local              TEXT    NOT NULL REFERENCES pedido_borrador(id_local) ON DELETE CASCADE,
    producto_id           INTEGER NOT NULL REFERENCES producto_cache(producto_id),
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),  -- precio congelado
    PRIMARY KEY (id_local, producto_id)
) STRICT;

CREATE TABLE cola_sync (
    solicitud_uuid TEXT PRIMARY KEY,                                    -- no cambia si se reintenta
    id_local       TEXT NOT NULL REFERENCES pedido_borrador(id_local),
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                   CHECK (estado IN ('PENDIENTE','CONFLICTO','RECHAZADO','SIMULADO_APROBADO')),
    motivo         TEXT,
    creada_en      TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ','now'))
) STRICT;

-- Un borrador no puede tener dos envíos pendientes al mismo tiempo (permite el reenvío de C2)
CREATE UNIQUE INDEX ux_cola_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';

-- Lo que ve el vendedor en pantalla (C1)
CREATE VIEW v_catalogo_disponible AS
SELECT producto_id, nombre, precio_centavos / 100.0 AS precio, stock_visto
FROM producto_cache
WHERE eliminado = 0 AND disponible_visto = 1;
```

**Tabla de la instantánea** (el profe pidió que **todas** las tablas sean STRICT). Hay que **crearla antes del `.import`**: si no existe, `.import` la crea con todo TEXT y sin STRICT.

```sql
CREATE TABLE snapshot_servidor (
    producto_id     INTEGER PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      TEXT    NOT NULL CHECK (disponible IN ('t','f')),   -- así llegan del CSV de psql
    eliminado       TEXT    NOT NULL CHECK (eliminado  IN ('t','f')),
    capturado_en    TEXT    NOT NULL
) STRICT;
```

**Importar y cargar el caché** (en `sqlite3 foodstore_movil.db`):
```sql
DELETE FROM snapshot_servidor;                                  -- cada instantánea nueva reemplaza la anterior
.import --csv --skip 1 servidor_snapshot.csv snapshot_servidor

INSERT INTO producto_cache (producto_id, nombre, precio_centavos, stock_visto,
                            disponible_visto, eliminado, capturado_en)
SELECT producto_id, nombre, precio_centavos, stock,
       (disponible = 't'), (eliminado = 't'), capturado_en
FROM snapshot_servidor
WHERE true                                                      -- necesario para el upsert en SQLite
ON CONFLICT (producto_id) DO UPDATE SET
    nombre = excluded.nombre, precio_centavos = excluded.precio_centavos,
    stock_visto = excluded.stock_visto, disponible_visto = excluded.disponible_visto,
    eliminado = excluded.eliminado, capturado_en = excluded.capturado_en;
```
Se usa **upsert** (no borrar y recargar) para que la lápida del C4 **actualice la fila sin borrarla** y no rompa la FK de `item_borrador`.

### Machete de SQLite
- Verificar versión: `python -c "import sqlite3; print(sqlite3.sqlite_version)"` (≥ 3.37) o `sqlite3 --version`.
- Prueba rápida del entorno (resultado esperado `FK: 1 - STRICT OK`):
  `python -c "import sqlite3; c=sqlite3.connect(':memory:'); c.execute('PRAGMA foreign_keys=ON'); c.execute('CREATE TABLE t(x INTEGER CHECK(x>0)) STRICT'); print('FK:', c.execute('PRAGMA foreign_keys').fetchone()[0], '- STRICT OK')"`
- CLI en Windows: *sqlite-tools-win-x64* de sqlite.org → descomprimir en `C:\sqlite` → agregar al PATH.
- `sqlite3 foodstore_movil.db` abre o crea el archivo. **`sqlite3` sin nombre abre una base en memoria y se pierde al salir.**
- Comandos punto (no son SQL, no llevan `;`): `.read archivo.sql`, `.headers on`, `.mode column`, `.tables`, `.schema tabla`, `.import`, `.output archivo.txt` (para guardar evidencia).
- No hay booleano (INTEGER 0/1 con CHECK), ni `VARCHAR(n)` (TEXT), ni fecha (TEXT ISO 8601), ni ENUM (TEXT con CHECK).
- Con STRICT, un tipo no permitido da error; `'123'` se convierte a 123, `'abc'` en INTEGER da error.
- Las FK vienen **apagadas**. `PRAGMA foreign_keys = ON;` en **cada conexión**, **antes** de abrir una transacción. Revisar con `PRAGMA foreign_keys;` (debe dar 1).
- Checklist del profe para el repo: SQLite ≥ 3.37, `PRAGMA foreign_keys;` = 1, `PRAGMA integrity_check;` = ok, crear tabla STRICT funciona.
- No existen en SQLite: funciones PL/pgSQL, procedimientos, roles, GRANT, RLS. La seguridad de la tablet es **guardar poco**.

### Transacción de un borrador (parada 4)
```sql
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario_id_servidor, forma_pago)
VALUES ('aaaaaaaa-0000-4000-8000-000000000001', 1, 'EFECTIVO');
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('aaaaaaaa-0000-4000-8000-000000000001', <id>, 2, <precio_centavos>);
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('bbbbbbbb-0000-4000-8000-000000000001', 'aaaaaaaa-0000-4000-8000-000000000001');
COMMIT;   -- si algo falla antes: ROLLBACK y no queda nada
```
Un borrador **no descuenta stock, no está pagado y no es una venta.**
**UUIDs:** en las pruebas usamos UUIDs fijos y fáciles de leer (`aaaaaaaa-…` para borradores, `bbbbbbbb-…` para solicitudes) para que todos reproduzcan lo mismo.

---

## 6. El semáforo (paradas 6 a 8)

| Luz | Estado | Cuándo | Qué se hace |
|---|---|---|---|
| Rojo | `RECHAZADO` | El producto no existe en la instantánea, no está disponible, fue dado de baja, **o** la cantidad es mayor que el stock | No se envía. Se corrige el borrador |
| Amarillo | `CONFLICTO` | No hay rojo, pero cambió algún precio | Se le pregunta al cliente si acepta el precio nuevo |
| Verde | `SIMULADO_APROBADO` | Todo coincide | Pasaría las validaciones. **No es una venta** |

**Si hay rojo y amarillo en el mismo borrador, gana el rojo.**

Lógica del apunte:
```
SIMULAR(solicitud, instantanea_nueva):
    si la solicitud ya fue evaluada: devolver el resultado guardado     (parada 8)
    para cada producto del borrador:
        si no existe, no está disponible o fue dado de baja  -> rojo
        si la cantidad es mayor que el stock                 -> rojo
        si el precio visto no es el precio actual            -> amarillo
    si hubo rojo -> RECHAZADO; si no, si hubo amarillo -> CONFLICTO; si no -> SIMULADO_APROBADO
    guardar estado y motivo en cola_sync
    (no se toca nada en PostgreSQL)
```

Pista de la consigna: agrupar por solicitud con `LEFT JOIN item_borrador → snapshot_servidor` y un
`CASE WHEN SUM(i.cantidad > s.stock OR …) > 0 THEN 'RECHAZADO' WHEN SUM(i.precio_centavos_visto <> s.precio_centavos) > 0 THEN 'CONFLICTO' ELSE 'SIMULADO_APROBADO' END`.

**Trampas a cuidar:**
- Con `LEFT JOIN`, si el producto no está en la instantánea, `s.*` es NULL y `i.cantidad > s.stock` da NULL (no cuenta). Hay que chequear `s.producto_id IS NULL` explícitamente.
- `disponible` y `eliminado` en `snapshot_servidor` son `'t'`/`'f'`, no 0/1.
- Solo se evalúan las `PENDIENTE` (`WHERE estado = 'PENDIENTE'`): así repetir la simulación no cambia nada (idempotencia del lado de la tablet).
- El `motivo` tiene que decir qué pasó (por ejemplo `stock insuficiente: producto 123`, `precio cambió: producto 45`).
- Una venta real solo existe cuando el servidor ejecuta `sp_crear_pedido`, que vuelve a revisar stock con `SELECT … FOR UPDATE`.

**Idempotencia real (parada 8, para la oración del C6):** la protección definitiva va **en el servidor**: una tabla `solicitud_movil (solicitud_uuid PRIMARY KEY, …)` y, en la **misma transacción** que crea el pedido, `INSERT … ON CONFLICT (solicitud_uuid) DO NOTHING`; si ya existía, no se crea otro pedido. El TP no pide implementarla.

**Estrategias de conflicto (parada 7):** precio → se pregunta al cliente; stock y bajas → decide el servidor; **nunca se decide por la hora del teléfono** (los relojes pueden estar mal). "Gana la última escritura" no sirve.

---

## 7. Los casos de prueba

| Caso | Qué se prepara | Resultado esperado | Dónde |
|---|---|---|---|
| C1 | Consultar el catálogo sin servidor | Se lee desde SQLite (`v_catalogo_disponible`) | 1.c |
| C2 | Un borrador; después se sube ese precio en la copia del servidor | `CONFLICTO`. El cliente acepta: se actualiza `precio_centavos_visto` y una **solicitud nueva** (otro UUID) da `SIMULADO_APROBADO` | 2.c |
| C3 | Un borrador por más unidades de las que quedan | `RECHAZADO`; el stock del servidor no se toca | 2.c |
| C4 | Un borrador con un producto que después se da de baja (`activo = false` en la copia) | `RECHAZADO`; al recargar el catálogo el producto ya no aparece en `v_catalogo_disponible`, pero **la fila queda** en `producto_cache` con `eliminado = 1` | 2.c |
| C5 | Un borrador sin cambios | `SIMULADO_APROBADO` (es simulación, no venta) | 2.c |
| C6 | Reenviar la misma solicitud (mismo UUID) | Error de clave primaria; repetir la simulación no reevalúa | 2.c |
| C7 | Cantidad 0 y producto inexistente | Error controlado (CHECK y FK); no quedan filas nuevas | 1.c |

**Flujo de cada caso del 2.c:** (1) borrador en SQLite → (2) cambio en `bd2_tp8` si corresponde → (3) `\copy` de una instantánea nueva → (4) `.import` + upsert al caché → (5) correr `semaforo.sql` → (6) `SELECT * FROM cola_sync` → (7) explicar en 1–2 oraciones.

**Consulta final en PostgreSQL:** correr **antes y después** de la simulación `SELECT count(*) FROM pedido;` y el stock de los productos usados (`SELECT id_producto, stock FROM producto WHERE id_producto IN (…)`), y mostrar que no cambiaron por la simulación. (Los cambios de C2 y C4 los hicimos a mano para preparar los casos: documentarlos aparte.)

**Productos fijos para los casos** (los completa quien haga el bloque B; todos usan los mismos):

| Uso | id_producto | nombre | precio | stock |
|---|---|---|---|---|
| C2 (precio que se sube) | | | | |
| C3 (stock bajo) | | | | |
| C4 (se da de baja) | | | | |
| C5 (sin cambios) | | | | |
| C1/C7 (pruebas) | | | | |

---

## 8. Integración y revisión (paradas 9 y 10)

**Mapa de los 3 motores (3.a):**

| Motor | Qué guarda | Quién manda | Unidades |
|---|---|---|---|
| PostgreSQL | Catálogo oficial, clientes, pedidos, stock | **Fuente de verdad**: decide precio, stock y ventas | 1 a 6 |
| MongoDB | Pedidos cerrados como documentos (base `foodstore`, colección `pedidos`, 8 pedidos con cliente y líneas embebidos, precio congelado, `Decimal128`, validador `$jsonSchema`) | Solo sobre esos documentos, no sobre el stock | 7 |
| SQLite | Copia del catálogo, borradores y cola de envío | Nadie le pide que decida: solo prepara | 8 |

Recorrido completo: PostgreSQL publica la instantánea → la tablet la guarda y arma borradores sin señal → al volver la señal se envían los pendientes → **PostgreSQL vuelve a validar stock, disponibilidad y precio en una transacción y solo él confirma la venta** → la tablet guarda la respuesta y actualiza el catálogo → MongoDB atiende su parte sin tocar stock ni ventas. En el TP la solicitud **solo se simula**.

**Riesgos (útiles para 3.b):** dos fuentes de verdad (U4); datos personales en el teléfono (U5); **restaurar un respaldo viejo**: las tablets quedan con datos "del futuro" y hay que volver a descargar el catálogo (U6); cambios en el esquema: la base de la tablet tiene versión (U4); confundir estados (U8).

**Code review en cinco pasos (3.c):**
1. Congelar: crear la rama `review-final`.
2. Revisar por partes con OpenCode en el **agente Plan** (analiza sin modificar), una unidad por vez.
3. Comprobar cada hallazgo en el motor: una consulta, un `EXPLAIN` o una prueba que falle.
4. Decidir y anotar cada hallazgo: aceptado, corregido o descartado, siempre con motivo.
5. Corregir en commits separados y volver a correr todo desde una base vacía.

| Revisá… | Preguntas |
|---|---|
| Integridad (U1, U3) | ¿Se descuenta stock sin validar? ¿Las transacciones se deshacen si algo falla? |
| Rendimiento (U2, U3) | ¿Los índices sirven a consultas que se midieron? |
| Esquema (U4) | ¿Las migraciones conservan los datos y tienen vuelta atrás? |
| Seguridad (U5) | ¿Roles con lo mínimo? ¿Contraseñas o datos reales en Git? |
| Mantenimiento (U6) | ¿Hay respaldo y restauración probada? |
| NoSQL (U7) | ¿La colección tiene sentido y no duplica la fuente oficial? |
| Móvil (U8) | ¿Las FK están activas? ¿Cada conflicto queda registrado? |

Los hallazgos tienen que ser **de nuestros propios scripts**. Repos: `belcalvo93/base-datos-2` (U1–U6) y `belcalvo93/BaseDatos2-MongoDB` (U7–U8).
Hallazgos ya verificados en cursadas anteriores (sirven de modelo o de entrada):
- U7: la IA propuso un **índice único** sobre `lineas.id_producto` para no repetir productos → **descartado**: en mongosh aceptó un pedido con el producto repetido y rechazó con E11000 otro pedido legítimo.
- U7: la IA propuso guardar totales como float → corregido a `Decimal128`.
- U6: el trigger del total del pedido cubría INSERT y UPDATE pero no DELETE (al borrar un detalle del pedido 2 no se recalculó) → corregido.
- Ejemplos del apunte para U8: "Hacé `UNIQUE` la columna `id_local` de la cola" → descartado (un borrador con conflicto de precio no podría reenviarse); "Usá la hora de la tablet para decidir qué vale" → descartado.

**Kiro → OpenCode:** (1) en Kiro se escriben `requirements.md`, `design.md`, `tasks.md`; (2) OpenCode con el agente **Build** genera los scripts a partir de las tareas; (3) el humano lee cada línea, la prueba en la copia y guarda respaldo; (4) se anota en la bitácora.

Formato EARS (ejemplos del apunte):
```
REQ-03  WHEN el precio actual es distinto del precio visto
        THE SYSTEM SHALL marcar el envío como CONFLICTO, mostrar los dos precios
        y pedir confirmación.                                    Se prueba con: C2
REQ-05  WHEN se reenvía un envío ya evaluado
        THE SYSTEM SHALL devolver el resultado guardado sin evaluarlo otra vez.
                                                                 Se prueba con: C6
```

**Bitácora (`docs/bitacora_ia.md`), formato por entrada:** fecha · quién · herramienta (Kiro / OpenCode Build / OpenCode Plan / otra) · qué se pidió · qué propuso · qué se aceptó · **qué se descartó y por qué** · cómo se comprobó.

---

## 9. Reparto del trabajo

**Fase 1 (arranca ya, hasta el jue 5/11):** Belén y Elías, porque su parte es la base de todo lo demás.
**Fase 2 (del 5/11 al lun 9/11):** Hernán y Bruno, sobre lo que dejó la fase 1.
**Cierre (10 y 11/11):** todos.

| Bloque | Quién | Qué hace | Necesita | Entrega |
|---|---|---|---|---|
| **A · Spec y base de la tablet** | **Belén** (fase 1) | **4.a** spec en Kiro (4 requisitos EARS que cubran los casos + `design.md` + `tasks.md`), **se hace primero** · **1.a** qué datos viajan · **1.b** `schema_sqlite.sql` (sección 5) · **1.c** `pruebas_sqlite.sql` (transacción, ROLLBACK, C1, C7) · checklist del profe (FK = 1, integrity_check, STRICT) | Nada | `docs/kiro/*`, `movil/schema_sqlite.sql`, `movil/pruebas_sqlite.sql`, texto de 1.a |
| **B · Instantánea y semáforo** | **Elías** (fase 1) | Copia `bd2_tp8` · verificar columnas (`\d`) · elegir y anotar los **productos fijos** (tabla de la sección 7) · vista `v_snapshot_movil` (2.a) · `\copy` + `.import` + upsert al caché · **2.b** `semaforo.sql` · **4.c** `README.md` con el orden para crear todo desde cero | La spec de A para el semáforo; el esquema de A para importar (la copia, la vista y los ids pueden arrancar ya) | `postgresql/10_snapshot_catalogo.sql`, `movil/servidor_snapshot.csv`, `movil/semaforo.sql`, `README.md` |
| **C · Casos y mapa** | **Hernán** (fase 2) | **2.c** los 5 casos C2–C6 con comando, resultado y explicación · consulta final de PostgreSQL (pedidos y stock sin cambios) · oración del C6 sobre idempotencia · **3.a** mapa de los 3 motores · **arma el `informe.pdf`** (máx. 6 páginas) | A y B terminados | `postgresql/casos_servidor.sql`, salidas de los casos, secciones 2.c y 3.a, `docs/informe.pdf` |
| **D · Revisión y mantenimiento** | **Bruno** (fase 2) | **3.c** code review con OpenCode (agente Plan) de todos los scripts, rama `review-final`, tabla de hallazgos, 3 desarrollados de 2 unidades, 1 descartado con fundamento · **3.b** agregado al plan de mantenimiento de la U6 · **4.b** consolida `bitacora_ia.md` y completa la `DUIA.md` | Los scripts de U1–U7 ya existen: **puede empezar antes**; los de U8 se suman cuando A y B terminen | Secciones 3.b y 3.c del informe, `docs/bitacora_ia.md`, `docs/DUIA.md` |

**Para todos:**
- Cada uno anota en la bitácora **sus propias** entradas de IA (mínimo una por persona) y se las pasa a Bruno.
- Cada uno trabaja en **su rama** (`tp8-belen`, `tp8-elias`, `tp8-hernan`, `tp8-bruno`) y hace PR a `main`.
- Cierre (10–11/11): todos corren el README desde una base vacía en su compu, revisan el informe y se pone la etiqueta `tp8`.
- **Antes de la defensa, cada uno tiene que poder explicar los scripts de los otros**: leerlos y probarlos.

---

## 10. Defensa

La consigna habla de 10 minutos; el apunte, de **15**. Prepararse para la versión del apunte:
1. El mapa de la capa de datos: qué vive dónde y quién manda.
2. Una demostración: **crear la base de la tablet desde cero** y correr **un caso que elige la cátedra** (hay que tener los 7 listos).
3. Una decisión de diseño y la alternativa que descartaron (por ejemplo: upsert con lápida vs. borrar y recargar el caché; índice parcial vs. `UNIQUE` en `id_local`).
4. Un hallazgo de la IA que aceptaron y uno que descartaron.

---

## 11. Pendientes del grupo

1. Confirmar en el aula virtual: fecha exacta de entrega, si se sube PDF, zip o link con etiqueta, y si hay clase el 2/11.
2. Conseguir la **plantilla de la DUIA** de la cátedra (bloque D).
3. Conseguir el texto del **plan de mantenimiento de la U6** (bloque D).
4. Ver si en el campus está el **kit de la cátedra** (`kit_u8_campus`, `simulador_sync.py`). Es opcional; sirve para comparar.
5. Cada integrante: verificar SQLite ≥ 3.37, instalar el CLI `sqlite3` y tener Kiro y OpenCode funcionando.
