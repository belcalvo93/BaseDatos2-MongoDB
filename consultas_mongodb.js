// ============================================================================
// Trabajo Práctico N.º 7 — Migración a MongoDB (Food Store)
// Archivo: consultas_mongodb.js  (ejecutar con: mongosh --file consultas_mongodb.js)
//
// Parte 1 — Consignas 2 y 3 (Elías Tello): base, colección, migración y reglas.
// Parte 2 — Consigna 4 (Belén): consultas a–d, más abajo en este mismo archivo.
//
// Origen de los datos: base PostgreSQL bd2_tp3, pedidos 1, 2, 3, 4, 5, 59428 y
// 74364 (selección de la Consigna 1, ver seleccion_pedidos.sql). Los documentos
// se generaron con un SELECT de solo lectura; no se tocó ningún ID, importe,
// cantidad ni forma de pago.
// ============================================================================

// ----------------------------------------------------------------------------
// CONSIGNA 3 — Reglas de integridad que se conservan en la migración
// ----------------------------------------------------------------------------
// R1. Precio histórico congelado (regla R4 de Food Store).
//     Cada línea guarda el precio_unitario de detalle_pedido, NO el precio
//     actual de producto. Ejemplo verificable: el producto 1 (Pan de campo 1kg)
//     se vendió a 2200.00 en el pedido 1 y a 2500.00 en los pedidos 59428 y
//     74364, aunque hoy producto.precio = 2500.00. Los montos se guardan como
//     Decimal128 (NumberDecimal) para no perder centavos por redondeo binario.
//     En la colección lo exige el validador: precio_unitario decimal y >= 0,
//     cantidad entera y > 0 (mismos CHECK que en PostgreSQL).
//
// R2. Un producto no se repite dentro del mismo pedido.
//     En PostgreSQL lo garantiza UNIQUE (id_pedido, id_producto) en
//     detalle_pedido. En MongoDB un índice único no sirve para esto (compara
//     entre documentos, no dentro del mismo arreglo), así que el validador
//     compara la cantidad de id_producto de "lineas" con la cantidad de
//     id_producto distintos ($setUnion). Si hay un repetido, el insert falla.
//
// Además se conservan los identificadores de origen: _id = id_pedido,
// cliente.id_cliente e lineas[].id_producto, para poder comparar con PostgreSQL.
//
// Qué se embebió y por qué (en lugar de colecciones separadas):
//   - cliente (objeto embebido): relación 1:1 desde el pedido; se guardan solo
//     los datos esenciales (id, nombre, email) para mostrar el pedido sin un
//     join. El maestro de clientes sigue siendo la tabla cliente.
//   - lineas (arreglo embebido): las líneas no existen fuera de su pedido
//     (en PostgreSQL se borran en cascada), siempre se leen junto con él y
//     son pocas (entre 2 y 6 por pedido), así que el documento no crece sin
//     límite. Así un pedido completo se lee en una sola operación.
//   - nombre del producto dentro de la línea: es una copia del momento de la
//     venta, igual que el precio; el catálogo (precio actual, categoría, stock)
//     no se copia y se referencia por id_producto.
//   - Subtotal y total NO se guardan: se calculan con $multiply y $sum, igual
//     que en PostgreSQL (3FN), para que no puedan contradecir a las líneas.
//   Criterio de la documentación oficial de MongoDB: embeber datos que se
//   consultan juntos y tienen relación de contención / uno-a-pocos
//   (https://www.mongodb.com/docs/manual/data-modeling/embedding/).
//
// Nota: pedido no tiene columna "estado"; se usa forma_pago
// (EFECTIVO / TARJETA / TRANSFERENCIA) como campo equivalente (decisión de
// diseño del equipo, documentada en modelo_documental.md).
//
// Corrección de codificación: en bd2_tp3 el apellido del cliente 1 está
// guardado como "GutiÃ©rrez" (la "é" en UTF-8 se leyó como Latin-1 al cargar).
// En la migración se corrigió a "Gutiérrez" con
//   convert_from(convert_to(apellido, 'LATIN1'), 'UTF8')
// aplicado solo a textos con "Ã". No cambia IDs, cantidades ni importes.
// bd2_tp3 no se modificó.
// ============================================================================

// ----------------------------------------------------------------------------
// CONSIGNA 2 — Base y colección
// ----------------------------------------------------------------------------
db = db.getSiblingDB("foodstore");

// Se borra y se vuelve a crear para que el script se pueda correr varias veces.
db.pedidos.drop();

db.createCollection("pedidos", {
  validator: {
    $and: [
      {
        $jsonSchema: {
          bsonType: "object",
          required: ["_id", "fecha", "forma_pago", "cliente", "lineas"],
          properties: {
            _id: { bsonType: ["int", "long"] },
            fecha: { bsonType: "date" },
            forma_pago: { enum: ["EFECTIVO", "TARJETA", "TRANSFERENCIA"] },
            cliente: {
              bsonType: "object",
              required: ["id_cliente", "nombre"],
              properties: {
                id_cliente: { bsonType: ["int", "long"] },
                nombre: { bsonType: "string" },
                email: { bsonType: "string" }
              }
            },
            lineas: {
              bsonType: "array",
              minItems: 1,
              items: {
                bsonType: "object",
                required: ["id_producto", "nombre", "cantidad", "precio_unitario"],
                properties: {
                  id_producto: { bsonType: ["int", "long"] },
                  nombre: { bsonType: "string" },
                  cantidad: { bsonType: "int", minimum: 1 },
                  precio_unitario: { bsonType: "decimal", minimum: 0 }
                }
              }
            }
          }
        }
      },
      // R2: ningún id_producto repetido dentro del mismo pedido.
      {
        $expr: {
          $eq: [
            { $size: "$lineas.id_producto" },
            { $size: { $setUnion: ["$lineas.id_producto", []] } }
          ]
        }
      }
    ]
  },
  validationLevel: "strict",
  validationAction: "error"
});

// ----------------------------------------------------------------------------
// CONSIGNA 2 — Migración de los 7 pedidos (29 líneas)
// ----------------------------------------------------------------------------
db.pedidos.insertMany([
  {
    _id: 1,
    fecha: ISODate("2026-08-01T13:15:00.000Z"),
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: 1, nombre: "Ana Gutiérrez", email: "ana.gutierrez@example.com" },
    lineas: [
      { id_producto: 1, nombre: "Pan de campo 1kg", cantidad: 2, precio_unitario: NumberDecimal("2200.00") },
      { id_producto: 5, nombre: "Leche entera 1L", cantidad: 1, precio_unitario: NumberDecimal("1650.00") },
      { id_producto: 66076, nombre: "Producto 31065", cantidad: 1, precio_unitario: NumberDecimal("860.75") },
      { id_producto: 72206, nombre: "Producto 37195", cantidad: 3, precio_unitario: NumberDecimal("746.65") },
      { id_producto: 83667, nombre: "Producto 48656", cantidad: 3, precio_unitario: NumberDecimal("279.07") }
    ]
  },
  {
    _id: 2,
    fecha: ISODate("2026-08-03T21:40:00.000Z"),
    forma_pago: "TARJETA",
    cliente: { id_cliente: 2, nombre: "Bruno Salinas", email: "bruno.salinas@example.com" },
    lineas: [
      { id_producto: 3, nombre: "Agua mineral 2L", cantidad: 3, precio_unitario: NumberDecimal("1400.00") },
      { id_producto: 7, nombre: "Yerba mate 1kg", cantidad: 1, precio_unitario: NumberDecimal("6800.00") },
      { id_producto: 38558, nombre: "Producto 3547", cantidad: 3, precio_unitario: NumberDecimal("328.07") },
      { id_producto: 51872, nombre: "Producto 16861", cantidad: 4, precio_unitario: NumberDecimal("906.37") },
      { id_producto: 66351, nombre: "Producto 31340", cantidad: 3, precio_unitario: NumberDecimal("556.04") },
      { id_producto: 69939, nombre: "Producto 34928", cantidad: 3, precio_unitario: NumberDecimal("586.18") }
    ]
  },
  {
    _id: 3,
    fecha: ISODate("2026-08-07T12:05:00.000Z"),
    forma_pago: "TRANSFERENCIA",
    cliente: { id_cliente: 1, nombre: "Ana Gutiérrez", email: "ana.gutierrez@example.com" },
    lineas: [
      { id_producto: 2, nombre: "Medialunas x6", cantidad: 2, precio_unitario: NumberDecimal("3200.00") },
      { id_producto: 6, nombre: "Queso cremoso 500g", cantidad: 1, precio_unitario: NumberDecimal("7600.00") },
      { id_producto: 67973, nombre: "Producto 32962", cantidad: 2, precio_unitario: NumberDecimal("376.55") },
      { id_producto: 71591, nombre: "Producto 36580", cantidad: 1, precio_unitario: NumberDecimal("529.53") },
      { id_producto: 71682, nombre: "Producto 36671", cantidad: 1, precio_unitario: NumberDecimal("149.07") },
      { id_producto: 72234, nombre: "Producto 37223", cantidad: 1, precio_unitario: NumberDecimal("21.92") }
    ]
  },
  {
    _id: 4,
    fecha: ISODate("2026-08-12T23:30:00.000Z"),
    forma_pago: "TARJETA",
    cliente: { id_cliente: 3, nombre: "Carla Medina", email: "carla.medina@example.com" },
    lineas: [
      { id_producto: 8, nombre: "Aceite girasol 900ml", cantidad: 1, precio_unitario: NumberDecimal("4100.00") },
      { id_producto: 9, nombre: "Fideos secos 500g", cantidad: 4, precio_unitario: NumberDecimal("1950.00") },
      { id_producto: 66290, nombre: "Producto 31279", cantidad: 2, precio_unitario: NumberDecimal("470.10") },
      { id_producto: 68909, nombre: "Producto 33898", cantidad: 4, precio_unitario: NumberDecimal("243.39") },
      { id_producto: 81323, nombre: "Producto 46312", cantidad: 4, precio_unitario: NumberDecimal("711.07") }
    ]
  },
  {
    _id: 5,
    fecha: ISODate("2026-08-18T15:00:00.000Z"),
    forma_pago: "EFECTIVO",
    cliente: { id_cliente: 4, nombre: "Diego Ferrari", email: "diego.ferrari@example.com" },
    lineas: [
      { id_producto: 4, nombre: "Gaseosa cola 2.25L", cantidad: 1, precio_unitario: NumberDecimal("3900.00") },
      { id_producto: 75467, nombre: "Producto 40456", cantidad: 1, precio_unitario: NumberDecimal("281.07") },
      { id_producto: 80098, nombre: "Producto 45087", cantidad: 2, precio_unitario: NumberDecimal("56.29") }
    ]
  },
  {
    _id: 59428,
    fecha: ISODate("2025-05-08T10:01:17.854Z"),
    forma_pago: "TRANSFERENCIA",
    cliente: { id_cliente: 22903, nombre: "Nombre4898 Apellido4898", email: "cliente4898@mail.com" },
    lineas: [
      { id_producto: 1, nombre: "Pan de campo 1kg", cantidad: 3, precio_unitario: NumberDecimal("2500.00") },
      { id_producto: 64780, nombre: "Producto 29769", cantidad: 2, precio_unitario: NumberDecimal("26.29") }
    ]
  },
  {
    _id: 74364,
    fecha: ISODate("2026-02-27T12:13:59.787Z"),
    forma_pago: "TARJETA",
    cliente: { id_cliente: 24222, nombre: "Nombre6217 Apellido6217", email: "cliente6217@mail.com" },
    lineas: [
      { id_producto: 1, nombre: "Pan de campo 1kg", cantidad: 3, precio_unitario: NumberDecimal("2500.00") },
      { id_producto: 35739, nombre: "Producto 728", cantidad: 3, precio_unitario: NumberDecimal("663.21") }
    ]
  }
]);

// ----------------------------------------------------------------------------
// CONSIGNA 2 — Verificación contra PostgreSQL
// Cantidad de líneas y total por pedido. Debe coincidir con la consulta 2 de
// seleccion_pedidos.sql.
// ----------------------------------------------------------------------------
print("Documentos en foodstore.pedidos: " + db.pedidos.countDocuments());

db.pedidos.aggregate([
  {
    $project: {
      _id: 1,
      forma_pago: 1,
      cantidad_lineas: { $size: "$lineas" },
      total_pedido: {
        $sum: {
          $map: {
            input: "$lineas",
            as: "l",
            in: { $multiply: ["$$l.cantidad", "$$l.precio_unitario"] }
          }
        }
      }
    }
  },
  { $sort: { _id: 1 } }
]).forEach(d => print(d._id + " | " + d.forma_pago + " | lineas=" + d.cantidad_lineas + " | total=" + d.total_pedido));

// Prueba de R2: insertar un pedido con un producto repetido debe fallar.
try {
  db.pedidos.insertOne({
    _id: 999999, fecha: new Date(), forma_pago: "EFECTIVO",
    cliente: { id_cliente: 1, nombre: "Prueba" },
    lineas: [
      { id_producto: 1, nombre: "Pan de campo 1kg", cantidad: 1, precio_unitario: NumberDecimal("2500.00") },
      { id_producto: 1, nombre: "Pan de campo 1kg", cantidad: 2, precio_unitario: NumberDecimal("2500.00") }
    ]
  });
  print("ERROR: se aceptó un producto repetido");
} catch (e) {
  print("OK R2: rechazado el pedido con producto repetido (código " + e.code + ": " + e.message + ")");
}
