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

> ### *Respuesta de la IA:*
>
> Para el escenario descrito en **Food Store**, donde el patrón de acceso preponderante es la lectura de pedidos completos y se requiere consistencia histórica, la mejor estrategia es un **modelo documental autocontenido mediante embebido (embedding)** dentro de una única colección `pedidos`.
>
> #### 1. Estructura recomendada del documento
> ```json
> {
>   "_id": 1,
>   "fecha": "2026-08-01T13:15:00Z",
>   "forma_pago": "EFECTIVO",
>   "cliente": {
>     "id_cliente": 1,
>     "nombre": "Ana Gutiérrez",
>     "email": "ana.gutierrez@example.com"
>   },
>   "lineas": [
>     {
>       "id_producto": 1,
>       "nombre": "Pan de campo 1kg",
>       "cantidad": 2,
>       "precio_unitario": 2200.00,
>       "subtotal": 4400.00
>     }
>   ],
>   "total": 4400.00
> }
> ```
>
> #### 2. Justificación de Embebido vs. Referencia
> * **Cliente (Embebido 1:1 parcial):** Conviene embeber una copia denormalizada con los atributos de lectura frecuente (`id_cliente`, `nombre`, `email`). Al emitir una factura o detalle, se evita un `$lookup` costoso. La tabla maestra de clientes se mantiene en su propia colección para modificaciones de perfil.
> * **Líneas de detalle (Embebido 1:N en arreglo):** La relación pedido-líneas tiene una cardinalidad baja y acotada (típicamente entre 1 y 20 renglones). Embeber las líneas dentro del arreglo `lineas` garantiza **localidad de datos** y **atomicidad a nivel de documento**.
>
> #### 3. Integridad de precios y cantidades
> * **Precio congelado (R4):** Al momento de insertar el pedido, la aplicación debe consultar el catálogo relacional y persistir el valor en `precio_unitario`. Al guardarse como un valor escalar dentro del subdocumento, queda automáticamente desacoplado de las variaciones del catálogo de productos.
> * **Restricción de producto único en el pedido:** Para replicar la restricción `UNIQUE (id_pedido, id_producto)` de PostgreSQL, en MongoDB se debe crear un **índice único sobre el campo embebido**:
>   `db.pedidos.createIndex({ "lineas.id_producto": 1 }, { unique: true })`.
> * **Cálculo de subtotal y total:** Se aconseja guardar los campos `subtotal` en cada línea y `total` en la raíz del documento calculados con números estándar de punto flotante para acelerar las lecturas en dashboards y reportes de facturación.

---

## 3. Contraste Crítico con la Documentación Oficial de MongoDB y el Diseño del Equipo

A continuación se analizan críticamente dos afirmaciones específicas brindadas por la IA, confrontándolas con la documentación técnica oficial de MongoDB y con la implementación real del proyecto.

---

### Contraste 1: Restricción de unicidad de productos dentro de un pedido
* **Afirmación de la IA:**  
  *"Para replicar la restricción UNIQUE(id_pedido, id_producto), en MongoDB se debe crear un índice único sobre el campo embebido: `db.pedidos.createIndex({ "lineas.id_producto": 1 }, { unique: true })`."*

* **Contraste con la Documentación Oficial de MongoDB:**  
  * **Veredicto:** **FALSO / ALUCINACIÓN TÉCNICA CRÍTICA.**
  * **Fundamento oficial:** Según la documentación oficial de MongoDB (*Indexes -> Multikey Indexes -> Unique Multikey Indexes*):  
    > *"A unique index on an array field enforces that no two documents in the collection have the same value for the indexed array field. It does NOT enforce uniqueness among the elements of an array within a single document."*
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
  * **Veredicto:** **INCORRECTO / MALA PRÁCTICA EN MODELADO FINANCIERO.**
  * **Fundamento oficial:**
    1. **Pérdida de precisión monetaria:** La documentación oficial de MongoDB en la sección *Model Monetary Data* desaconseja enfáticamente utilizar tipos de coma flotante estándar de 64 bits (IEEE 754 `double` o `Number` genérico de JavaScript) debido a los errores acumulativos de redondeo binario (por ejemplo, `0.1 + 0.2 = 0.30000000000000004`). MongoDB especifica explícitamente el uso del tipo BSON **`Decimal128`** (`NumberDecimal`), que implementa el estándar IEEE 754-2008 de aritmética decimal de 128 bits con 34 dígitos de precisión.
    2. **Riesgo de anomalía y desincronización (Inconsistencia de datos):** Guardar `subtotal` y `total` precalculados dentro del documento reintroduce redundancia innecesaria. Si una aplicación externa o una actualización parcial modifica la `cantidad` sin actualizar el `total`, el documento entra en estado corrupto e inconsistente.
  * **Solución real implementada por el equipo:**  
    En `consultas_mongodb.js`:
    - Todos los precios históricos (`precio_unitario`) se persisten con tipado estricto `NumberDecimal("...")`.
    - No se guardan ni `subtotal` ni `total` en el almacenamiento físico BSON (siguiendo el principio de Tercera Forma Normal adaptado a colecciones documentales).
    - Los totales se computan en tiempo de lectura mediante el Aggregation Framework (`$sum` sobre el `$map` de `$multiply`), garantizando consistencia absoluta y coincidencia matemática al centavo con PostgreSQL (`SUM(cantidad * precio_unitario) = $82.471,78`).

---

## 4. Conclusiones del ejercicio con IA

1. La IA es una excelente herramienta para sugerir la estructura inicial de documentos (el embebido de `cliente` y `lineas` fue acertado para optimizar el patrón de acceso y aislar el precio histórico R4).
2. Sin embargo, la IA presenta **alucinaciones conceptuales peligrosas** en temas de restricciones e integridad interna de arreglos (confundiendo la semántica de un índice multikey). Sin una contrastación rigurosa con la documentación oficial del motor, la recomendación de la IA hubiera provocado una falla catastrófica en el sistema de ventas.
