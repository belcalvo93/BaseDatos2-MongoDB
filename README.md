# BaseDatos2-MongoDB

Base de Datos II — UTN · Proyecto Food Store
Repositorio de los TP 7 (MongoDB) y TP 8 (SQLite). Los TP 1 a 6 completos están en el repo relacional [`base-datos-2`](https://github.com/belcalvo93/base-datos-2). La etiqueta `archivo-tps-sql` de este repo guarda solo una copia de los TP 1 a 3.

**Integrantes:** Bruno Fiouchetta, Elías Tello, Belén Calvo, Hernán González

**TPI Parcial II:** índice de los 14 objetivos con su evidencia en [matriz_objetivos.md](https://github.com/belcalvo93/base-datos-2/blob/main/docs/tpi_parcial2/matriz_objetivos.md) (repositorio relacional).

## TP 7 — Migración de pedidos de PostgreSQL a MongoDB

Se migraron 8 pedidos de `bd2_tp3` (30 líneas) a la colección `foodstore.pedidos`, con cliente y líneas embebidos, `_id` = `id_pedido` y montos en `Decimal128`.

| Archivo | Contenido | Consigna |
|---|---|---|
| `modelo_documental.md` | Tablas y claves de origen, esquema del documento, selección de pedidos | 1 |
| `seleccion_pedidos.sql` | Consultas de solo lectura que extraen los pedidos y arman el JSON | 1 |
| `consultas_mongodb.js` | Colección con validador, `insertMany`, reglas de integridad, verificación y consultas a–d | 2, 3, 4 |
| `consultas_postgresql.sql` | Consultas equivalentes en PostgreSQL | 5 |
| `consigna5_tabla_comparativa.md` | Tabla PostgreSQL vs MongoDB y diferencias detectadas | 5 |
| `consigna6_ia_contraste.md` | Prompt a la IA y contraste de dos afirmaciones | 6, 7 |
| `prueba_indice_unico_ia.js` | Prueba de laboratorio del índice único propuesto por la IA | 7 |
| `evidencias/` | Salidas de ejecución de los scripts | — |

### Cómo reproducirlo

Requisitos: PostgreSQL 16 con la base `bd2_tp3`, MongoDB Server y `mongosh`.

```bash
psql -U postgres -d bd2_tp3 -f seleccion_pedidos.sql     # datos de origen
mongosh --quiet --file consultas_mongodb.js              # migración, verificación y consultas a–d
psql -U postgres -d bd2_tp3 -f consultas_postgresql.sql  # consultas equivalentes
mongosh --quiet --file prueba_indice_unico_ia.js         # prueba del índice de la IA
```

`consultas_mongodb.js` borra y recrea la colección, así que se puede correr varias veces. La verificación `total = suma de líneas` debe dar 0 pedidos descuadrados.

## TP 8 — SQLite (la base de la tablet)

El food truck vende en una feria sin señal. La tablet guarda en SQLite una copia del catálogo, arma borradores sin conexión y, al volver la señal, se **simula** la sincronización con PostgreSQL con un semáforo (rojo `RECHAZADO`, amarillo `CONFLICTO`, verde `SIMULADO_APROBADO`). **El móvil propone, el servidor dispone:** la tablet nunca cambia precio, stock ni ventas, y `SIMULADO_APROBADO` no es una venta.

Todo está en [`food-store/`](food-store/). El orden para crear todo desde cero está en [`food-store/README.md`](food-store/README.md).

| Entregable | Archivo | Consigna |
|---|---|---|
| Qué datos viajan | `food-store/docs/1a_datos_que_viajan.md` | 1.a |
| Esquema SQLite (6 tablas STRICT) | `food-store/movil/schema_sqlite.sql` | 1.b |
| Pruebas (COMMIT, ROLLBACK, subtotal, C1, C7) | `food-store/movil/pruebas_sqlite.sql` | 1.c |
| Vista de la instantánea y CSV | `food-store/postgresql/10_snapshot_catalogo.sql`, `food-store/movil/servidor_snapshot.csv`, `food-store/movil/importar_catalogo.sql` | 2.a |
| Semáforo con registro de evaluaciones | `food-store/movil/semaforo.sql` | 2.b |
| Casos C2–C6 y consulta final | `food-store/postgresql/casos_servidor.sql`, `food-store/movil/casos_sqlite.sql`, `food-store/postgresql/consulta_final.sql`, `food-store/docs/2c_casos_y_3a_mapa.md` | 2.c |
| Mapa de los 3 motores | `food-store/docs/2c_casos_y_3a_mapa.md` | 3.a |
| Plan de mantenimiento | `food-store/docs/3b_plan_mantenimiento.md` | 3.b |
| Code review con IA e inventario U1–U8 | `food-store/docs/3c_code_review_ia.md`, `food-store/docs/inventario_scripts_u1_u8.md` | 3.c |
| Spec en Kiro (6 requisitos EARS) | `.kiro/specs/tp8-tablet/` (copia en `food-store/docs/kiro/`) | 4.a |
| Bitácora de IA y DUIA | `food-store/docs/bitacora_ia.md`, `food-store/docs/DUIA.md` | 4.b |
| Evidencias de ejecución | `food-store/evidencias/` | — |
| Informe (máx. 6 páginas) | `food-store/docs/informe.pdf` | — |

**Etiquetas:** `tp8` es la versión entregada y corregida por el profesor; `tp8-v2` es la versión con las correcciones (C3 con el stock que baja en el servidor, C6 que devuelve el resultado guardado, registro de evaluaciones, consulta con subtotal, inventario U1–U8 y 6 requisitos EARS).

