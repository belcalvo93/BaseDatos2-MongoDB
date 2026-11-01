# BaseDatos2-MongoDB

Base de Datos II — UTN · Proyecto Food Store
Repositorio de los TP 7 (MongoDB) y TP 8 (SQLite). Los TP anteriores están en el repo relacional `base-datos-2` (y archivados acá en la etiqueta `archivo-tps-sql`).

**Integrantes:** Bruno Fiouchetta, Elías Tello, Belén Calvo, Hernán González

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
