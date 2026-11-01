// ============================================================================
// TP7 — Consigna 7: evidencia de laboratorio para el contraste de la IA.
// Afirmación de la IA: db.pedidos.createIndex({ "lineas.id_producto": 1 },
// { unique: true }) replica UNIQUE(id_pedido, id_producto).
// Se prueba en una colección aparte (prueba_indice_ia); no toca "pedidos".
// Ejecutar con: mongosh --quiet --file prueba_indice_unico_ia.js
// ============================================================================
db = db.getSiblingDB("foodstore");
db.prueba_indice_ia.drop();
db.prueba_indice_ia.createIndex({ "lineas.id_producto": 1 }, { unique: true });
print("Índice creado: " + JSON.stringify(db.prueba_indice_ia.getIndexes()[1].key) + " unique=true");

// Prueba 1: un pedido con el mismo producto repetido en dos líneas.
// Si el índice replicara la regla, debería rechazarlo.
try {
  db.prueba_indice_ia.insertOne({
    _id: 1,
    lineas: [ { id_producto: 1, cantidad: 1 }, { id_producto: 1, cantidad: 2 } ]
  });
  print("Prueba 1: ACEPTADO -> el índice NO impide repetir el producto dentro del mismo pedido");
} catch (e) {
  print("Prueba 1: rechazado (código " + e.code + ")");
}

// Prueba 2: dos pedidos distintos que compran el mismo producto (caso normal).
// Debería aceptarse; si el índice lo rechaza, bloquea ventas legítimas.
try {
  db.prueba_indice_ia.insertOne({ _id: 2, lineas: [ { id_producto: 1, cantidad: 3 } ] });
  print("Prueba 2: aceptado");
} catch (e) {
  print("Prueba 2: RECHAZADO -> el índice impide que otro pedido compre el mismo producto (código " + e.code + ")");
}

db.prueba_indice_ia.drop();
print("Colección de prueba eliminada.");
