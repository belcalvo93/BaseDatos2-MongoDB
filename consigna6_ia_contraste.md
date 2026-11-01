# Consigna 6: Consulta a Inteligencia Artificial y Análisis de Contraste Técnico

**Trabajo Práctico N.º 7 — Migración a MongoDB (Food Store)**  
**Alumno responsable:** Hernán Gonzalez  
**Integrantes:** Bruno Fiouchetta, Elías Tello, Belén Calvo, Hernán Gonzalez  

---

## 1. Contexto y Formulación de la Consulta (Prompt)

Para cumplir estrictamente con la consigna, la consulta a la IA debió incluir de forma explícita tres requerimientos:
1. **Modelo actual de origen:** Base relacional normalizada en PostgreSQL con cuatro tablas intervinientes (`pedido`, `detalle_pedido`, `cliente` y `producto`).
2. **Patrón de acceso principal:** Consulta recurrente del pedido completo en una única operación (lectura integral de cabecera, cliente y líneas).
3. **Coherencia e integridad de datos:** Mantenimiento de la regla de precio histórico congelado (R4), control para evitar duplicados de productos en un mismo pedido y consistencia en el cálculo de totales.

### Prompt ejecutado:

```text
Actuá como un arquitecto senior de bases de datos. Estamos migrando el subsistema de pedidos de la aplicación "Food Store" desde PostgreSQL hacia MongoDB.

En nuestro modelo relacional de origen disponemos de cuatro tablas normalizadas (3FN):
1. `pedido`: con id_pedido (PK), fecha, forma_pago y id_cliente (FK).
2. `detalle_pedido`: con id_detalle (PK), id_pedido (FK), id_producto (FK), cantidad (CHECK > 0) y precio_unitario (CHECK >= 0), junto con una restricción `UNIQUE (id_pedido, id_producto)`.
3. `cliente`: con id_cliente (PK), nombre, apellido y email.
4. `producto`: con id_producto (PK), nombre, precio (precio actual de catálogo) y categoría.

Reglas y requisitos del sistema:
- Patrón de acceso frecuente: La operación crítica del negocio es consultar el pedido completo (cabecera, datos de contacto del cliente y todas las líneas de detalle con su subtotal y total) para visualización inmediata en pantalla y comprobantes.
- Regla de integridad R4: El `precio_unitario` de cada línea debe quedar "congelado" con el precio histórico pactado al momento de emitir el pedido, sin verse afectado por actualizaciones futuras en la tabla `producto`.
- Unicidad: Un mismo producto no puede aparecer repetido en más de una línea dentro del mismo pedido.
- Consistencia: No deben producirse descuadres entre las cantidades vendidas, los precios de las líneas y el total final.

¿Qué diseño de documento en MongoDB recomendás para la colección `pedidos`? Explicá qué conviene embeber o referenciar, cómo garantizar la integridad de precios y cantidades, y cómo manejar las restricciones para evitar inconsistencias.
```

---

## 2. Respuesta generada por la Inteligencia Artificial

- Recomienda una colección "pedidos" con cliente embebido (copia parcial: id, nombre, email) y líneas embebidas en un arreglo, por el acceso frecuente al pedido completo.

- Para el precio histórico (R4), copiar precio_unitario al documento al momento de la venta.

- Para no repetir un producto en el mismo pedido, propone `db.pedidos.createIndex({ "lineas.id_producto": 1 }, { unique: true })`.

- Propone guardar subtotal por línea y total del pedido como números de punto flotante para acelerar lecturas.

---

## 3. Contraste Crítico con la Documentación Oficial de MongoDB y el Diseño del Equipo

A continuación se analizan críticamente dos afirmaciones específicas brindadas por la IA, confrontándolas con la documentación técnica oficial de MongoDB y con la implementación real del proyecto.

---

### Contraste 1: Restricción de unicidad de productos dentro de un pedido
* **Afirmación de la IA:**  
  *"Para replicar la restricción UNIQUE(id_pedido, id_producto), en MongoDB se debe crear un índice único sobre el campo embebido: `db.pedidos.createIndex({ "lineas.id_producto": 1 }, { unique: true })`."*

* **Contraste con la Documentación Oficial de MongoDB:**  
  * **Veredicto:** **FALSO / ALUCINACIÓN TÉCNICA CRÍTICA.**
  * **Fundamento oficial:** La documentación oficial (Unique Indexes, sección 'Unique Constraint Across Separate Documents': https://www.mongodb.com/docs/manual/core/index-unique/) indica que un índice único impide que documentos distintos tengan el mismo valor, y que en un índice multikey un mismo documento puede repetir valores dentro de su arreglo.
  * **Evidencia de laboratorio:** Se probó en mongosh (prueba_indice_unico_ia.js, salida en evidencias/salida_prueba_indice_unico_ia.txt) sobre una colección aparte: Prueba 1, un pedido con el producto 1 repetido en dos líneas fue ACEPTADO (el índice no impide el duplicado interno). Prueba 2, un segundo pedido con el producto 1 fue RECHAZADO con error E11000 (el índice bloquea ventas legítimas). Se confirman las dos consecuencias descriptas.
  * **Consecuencia del error:** Si se aplicara la recomendación literal de la IA:
    1. **Falso positivo de integridad:** Un pedido individual podría contener `lineas: [{id_producto: 1}, {id_producto: 1}]` sin que el índice único lo impida, violando la regla de negocio.
    2. **Bloqueo masivo del sistema:** Como el índice único multikey aplica **entre documentos de la colección**, una vez que el cliente del pedido 1 compre el `id_producto: 1`, **ningún otro pedido en toda la historia de la base de datos podría volver a comprar el producto 1**, arrojando el error `E11000 duplicate key error collection`.
  * **Solución real implementada por el equipo (Elías):**  
    En MongoDB, la restricción de que un arreglo no contenga elementos duplicados en un mismo documento no se logra con índices, sino mediante **Schema Validation** combinando `$jsonSchema` y una expresión `$expr` con `$setUnion`:
    ```javascript
    {
      $expr: {
        $eq: [
          { $size: "$lineas.id_producto" },
          { $size: { $setUnion: ["$lineas.id_producto", []] } }
        ]
      }
    }
    ```
    Si la longitud del arreglo original es distinta a la del conjunto sin repetidos (`$setUnion`), el motor rechaza la inserción a nivel atómico con código de error de validación.

---

### Contraste 2: Precisión monetaria y persistencia de totales precalculados
* **Afirmación de la IA:**  
  *"Se aconseja guardar los campos `subtotal` en cada línea y `total` en la raíz calculados con números estándar de punto flotante para acelerar las lecturas en dashboards y reportes."*

* **Contraste con la Documentación Oficial y Decisiones de Arquitectura:**  
  * **Veredicto:** **PARCIALMENTE CORRECTA.**
  * **Lo incorrecto:** usar punto flotante. La documentación oficial (Model Monetary Data: https://www.mongodb.com/docs/manual/tutorial/model-monetary-data/) recomienda Decimal128 para valores monetarios por los errores de redondeo binario. Por eso precio_unitario y total se guardan como NumberDecimal.
  * **Lo correcto:** guardar el total es válido como redundancia controlada, siempre que tenga un mecanismo de verificación. Como MongoDB no tiene triggers, la coherencia la garantiza la aplicación: el total se calcula en PostgreSQL antes de guardar (SUM(cantidad * precio_unitario)) y se audita con un aggregate que busca pedidos con total distinto de la suma de líneas. Resultado: 0 documentos (evidencias/salida_migracion_y_verificacion.txt). El subtotal por línea no se guarda: se calcula con $multiply.

---

## 4. Conclusiones del ejercicio con IA

1. La IA es una excelente herramienta para sugerir la estructura inicial de documentos (el embebido de `cliente` y `lineas` fue acertado para optimizar el patrón de acceso y aislar el precio histórico R4).
2. Sin embargo, la IA presenta **alucinaciones conceptuales peligrosas** en temas de restricciones e integridad interna de arreglos (confundiendo la semántica de un índice multikey). Sin una contrastación rigurosa con la documentación oficial del motor, la recomendación de la IA hubiera provocado una falla catastrófica en el sistema de ventas.
