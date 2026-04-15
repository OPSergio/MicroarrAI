# 🤖 Machine Learning

## Introducción

El módulo de Machine Learning (ML) construye modelos predictivos usando los candidatos identificados en el análisis DEG. Este módulo ofrece algoritmos supervisados y no supervisados para clasificación, validación cruzada y selección de features óptimas.

---

## 1. Aprendizaje Supervisado vs. No Supervisado

### 1.1 Supervised Learning

**Definición:**  
Aprende de datos etiquetados para predecir clases de nuevas muestras.

**Requisitos:**
- Metadata con variable objetivo (ej. Group: Control/Disease)
- Etiquetas confiables y balanceadas

**Aplicaciones:**
- Clasificación diagnóstica
- Predicción de respuesta a tratamiento
- Estratificación de pacientes

### 1.2 Unsupervised Learning

**Definición:**  
Descubre patrones y agrupaciones sin etiquetas previas.

**Aplicaciones:**
- Descubrimiento de subtipos
- Detección de outliers
- Reducción de dimensionalidad

---

## 2. Algoritmos Supervisados

### 2.1 Random Forest (RF)

#### Base Teórica

**Concepto:**  
Ensemble de árboles de decisión que vota por clasificación mayoritaria.

**Algoritmo:**
1. Bootstrap sampling (con reemplazo) de datos
2. Entrenar árbol en cada bootstrap sample
3. En cada nodo, seleccionar subconjunto aleatorio de features
4. Crecer árbol sin poda
5. Votar entre todos los árboles

**Hiperparámetros en el Launcher:**

- **ntree (Number of Trees)**
  - Default: 500
  - Rango típico: 100-1000
  - ↑ ntree → ↑ estabilidad, ↑ tiempo
  - Recomendación: 500 suficiente para mayoría de casos

- **mtry (Features per Split)**
  - Default: √(número de features)
  - Para clasificación: √p
  - Para regresión: p/3
  - ↓ mtry → ↑ diversidad, ↓ correlación entre árboles

- **nodesize (Min Samples per Leaf)**
  - Default: 1 (clasificación), 5 (regresión)
  - ↑ nodesize → ↓ overfitting, ↑ bias
  - Recomendación: 5-10 para datos pequeños

#### Feature Importance

**Mean Decrease in Gini (MDG):**  
Mide reducción promedio de impureza al usar ese feature.

**Fórmula:**
$$Gini = 1 - \sum_{i=1}^{C} p_i^2$$

**Interpretación:**
- Valores altos → feature discriminativo
- Ranking de péptidos por importancia

**Mean Decrease in Accuracy (MDA):**  
Mide caída de accuracy al permutar ese feature.

**Ventajas de RF:**
- ✅ Robusto a overfitting
- ✅ Maneja correlaciones entre features
- ✅ No requiere normalización
- ✅ Proporciona importance metrics

**Desventajas:**
- ❌ "Black box" (difícil interpretar predicción individual)
- ❌ Sesgado hacia features con más categorías

---

### 2.2 Support Vector Machine (SVM)

#### Base Teórica

**Concepto:**  
Encuentra el hiperplano óptimo que maximiza el margen entre clases.

**Objetivo:**  
Maximizar distancia entre hiperplano y puntos más cercanos (support vectors).

**Formulación:**
$$\min_{w,b} \frac{1}{2} ||w||^2 + C \sum_{i=1}^{n} \xi_i$$

Sujeto a: $y_i(w \cdot x_i + b) \geq 1 - \xi_i$

Donde:
- **w**: vector normal al hiperplano
- **C**: parámetro de penalización
- **ξ**: variables de holgura (slack)

#### Kernels Disponibles

**Linear Kernel**
$$K(x_i, x_j) = x_i \cdot x_j$$

**Cuándo usar:**
- ✅ Datos linealmente separables
- ✅ Muchas features vs. pocas muestras (p >> n)
- ✅ Interpretabilidad importante

**Polynomial Kernel**
$$K(x_i, x_j) = (\gamma x_i \cdot x_j + r)^d$$

**Parámetros:**
- **degree (d)**: típ. 2-5
- **gamma (γ)**: escala de influencia
- **coef0 (r)**: término independiente

**Cuándo usar:**
- ✅ Relaciones polinómicas entre features
- ⚠️ Riesgo de overfitting con d alto

**Radial Basis Function (RBF / Gaussian)**
$$K(x_i, x_j) = \exp(-\gamma ||x_i - x_j||^2)$$

**Parámetro:**
- **gamma (γ)**: inverso del radio de influencia
  - ↓ γ → decisión boundary más suave
  - ↑ γ → decisión boundary más compleja

**Cuándo usar:**
- ✅ Default para mayoría de problemas
- ✅ Relaciones no lineales desconocidas
- ✅ Clases con distribuciones complejas

**Sigmoid Kernel**
$$K(x_i, x_j) = \tanh(\gamma x_i \cdot x_j + r)$$

**Cuándo usar:**
- ✅ Simula redes neuronales
- ⚠️ Raramente superior a RBF

#### Hiperparámetros en el Launcher

- **C (Cost Parameter)**
  - Default: 1
  - Rango: 0.01 - 100
  - ↑ C → ↓ training error, ↑ riesgo overfitting
  - ↓ C → ↑ margen, ↑ generalización
  - Recomendación: Grid search [0.1, 1, 10]

- **gamma (solo RBF/Poly)**
  - Default: 1/(nº features)
  - Rango: 0.001 - 1
  - ↑ gamma → fit más ajustado a training
  - Recomendación: [0.001, 0.01, 0.1]

**Ventajas de SVM:**
- ✅ Efectivo en espacios de alta dimensión
- ✅ Eficiente con memory (solo usa support vectors)
- ✅ Versátil con kernels

**Desventajas:**
- ❌ Sensible a escalado de features (requiere normalización)
- ❌ Difícil elegir kernel/parámetros óptimos
- ❌ Costoso computacionalmente con n grande

---

### 2.3 K-Nearest Neighbors (KNN)

#### Base Teórica

**Concepto:**  
Clasifica una muestra por votación mayoritaria de sus k vecinos más cercanos.

**Algoritmo:**
1. Calcular distancia a todas las muestras de training
2. Seleccionar k más cercanos
3. Votar por clase mayoritaria

**Métricas de Distancia:**

**Euclidean (Default)**
$$d(x, y) = \sqrt{\sum_{i=1}^{p} (x_i - y_i)^2}$$

**Manhattan**
$$d(x, y) = \sum_{i=1}^{p} |x_i - y_i|$$

**Minkowski (Generalización)**
$$d(x, y) = \left(\sum_{i=1}^{p} |x_i - y_i|^q\right)^{1/q}$$

#### Hiperparámetros en el Launcher

- **k (Number of Neighbors)**
  - Default: 5
  - Rango: 1 - √n
  - ↓ k → ↑ complejidad, ↑ variance
  - ↑ k → ↑ smoothing, ↑ bias
  - Regla empírica: k = √n, debe ser impar (evitar empates)
  - Recomendación: Probar [3, 5, 7, 9]

**Ventajas de KNN:**
- ✅ Simple e intuitivo
- ✅ No requiere training (lazy learner)
- ✅ Efectivo con boundaries complejas

**Desventajas:**
- ❌ Muy sensible a escalado (requiere normalización)
- ❌ Lento en predicción con datasets grandes
- ❌ Sufre "curse of dimensionality"
- ❌ Requiere seleccionar k óptimo

---

### 2.4 Naive Bayes

#### Base Teórica

**Teorema de Bayes:**
$$P(C|X) = \frac{P(X|C) \times P(C)}{P(X)}$$

**Asunción "Naive":**  
Features son condicionalmente independientes dada la clase.

$$P(X|C) = \prod_{i=1}^{p} P(x_i|C)$$

**Clasificación:**  
Asigna clase con mayor probabilidad posterior.

$$\hat{C} = \arg\max_{C} P(C) \prod_{i=1}^{p} P(x_i|C)$$

#### Variantes

**Gaussian Naive Bayes** (para features continuos)
$$P(x_i|C) = \frac{1}{\sqrt{2\pi\sigma_C^2}} \exp\left(-\frac{(x_i - \mu_C)^2}{2\sigma_C^2}\right)$$

**Multinomial Naive Bayes** (para conteos/frecuencias)

**Bernoulli Naive Bayes** (para features binarios)

**Ventajas de Naive Bayes:**
- ✅ Muy rápido (training y predicción)
- ✅ Efectivo con alta dimensionalidad
- ✅ Robusto a features irrelevantes
- ✅ Probabilidades calibradas

**Desventajas:**
- ❌ Asunción de independencia raramente cierta
- ❌ Puede ser superado por modelos más complejos

---

### 2.5 Gradient Boosting

#### Base Teórica

**Concepto:**  
Construye modelo aditivo de manera secuencial, donde cada nuevo estimador corrige errores de anteriores.

**Algoritmo:**
1. Iniciar con predicción constante F₀(x)
2. Para m = 1 a M:
   - Calcular residuos: $r_{im} = y_i - F_{m-1}(x_i)$
   - Fit base learner h_m(x) a residuos
   - Actualizar: $F_m(x) = F_{m-1}(x) + \nu \times h_m(x)$

**Fórmula final:**
$$F_M(x) = F_0(x) + \nu \sum_{m=1}^{M} h_m(x)$$

#### Hiperparámetros en el Launcher

- **n_estimators (Number of Boosting Rounds)**
  - Default: 100
  - Rango: 50-500
  - ↑ n → mejor fit, riesgo overfitting
  - Recomendación: Usar con learning rate bajo

- **learning_rate (ν, Shrinkage)**
  - Default: 0.1
  - Rango: 0.01-0.3
  - ↓ learning rate → requiere ↑ n_estimators
  - Trade-off: lr × n = constante
  - Recomendación: 0.01-0.1 con early stopping

- **max_depth**
  - Default: 3
  - Rango: 2-8
  - ↑ depth → ↑ complejidad, ↑ overfitting
  - Recomendación: 3-5 para datos pequeños

**Ventajas de Gradient Boosting:**
- ✅ Uno de los mejores algoritmos en competencias
- ✅ Maneja features heterogéneos
- ✅ Captura interacciones complejas

**Desventajas:**
- ❌ Propenso a overfitting
- ❌ Sensible a outliers
- ❌ Más lento que Random Forest

---

## 3. Feature Selection: RFE

### 3.1 Recursive Feature Elimination

**Objetivo:**  
Identificar subconjunto óptimo de features que maximiza performance.

**Algoritmo:**
1. Entrenar modelo con todas las features
2. Rankear features por importancia
3. Eliminar feature(s) menos importante(s)
4. Repetir hasta alcanzar número deseado
5. Seleccionar subset con mejor CV score

**Implementación en MicroarrAI:**
- Compatible con RF, SVM, Gradient Boosting
- CV interno para evitar overfitting
- Output: péptidos óptimos rankeados

### 3.2 Parámetros RFE

**Number of Features to Select**
- Default: 10
- Depende de aplicación:
  - Panel diagnóstico: 5-15 péptidos
  - Investigación exploratoria: 20-50

**CV Folds**
- Default: 5-fold CV
- ↑ folds → más robusto, ↑ tiempo

**Step Size**
- Default: 1 (elimina 1 feature por ronda)
- Step > 1: más rápido pero menos preciso

### 3.3 Interpretación RFE

**Output:**
- **Ranking**: Orden de importancia
- **CV Scores**: Accuracy para cada subset size
- **Optimal Features**: Subset con max score

**Gráfico:**  
CV Accuracy vs. Number of Features

**Interpretación:**
- Plateau → más features no mejoran
- Overfitting → descenso con muchas features

---

## 4. Validación Cruzada (Cross-Validation)

### 4.1 K-Fold Cross-Validation

**Método:**
1. Dividir datos en K folds (típ. K=5 o 10)
2. Para cada fold i:
   - Training: K-1 folds
   - Validation: fold i
3. Promediar métricas de K iteraciones

**Ventajas:**
- ✅ Usa todos los datos para training y testing
- ✅ Reduce varianza de estimación
- ✅ Detecta overfitting

**Elección de K:**
- **K=5**: Balanceado, recomendado para n<100
- **K=10**: Más robusto, mayor tiempo
- **Leave-One-Out (K=n)**: Máxima robustez, costoso

### 4.2 Stratified K-Fold

**Modificación:**  
Mantiene proporción de clases en cada fold.

**Cuándo usar:**
- ✅ Clases desbalanceadas
- ✅ Dataset pequeño
- ✅ Default para clasificación

### 4.3 Repeated K-Fold

**Método:**  
Repite K-Fold CV múltiples veces con diferentes particiones.

**Ventajas:**
- Estimación más robusta
- Intervalos de confianza

**Recomendación:**  
5-fold × 3 repeticiones para datos pequeños

---

## 5. Métricas de Evaluación

### 5.1 Confusion Matrix

**Estructura:**
```
                Predicted
              Pos    Neg
Actual  Pos   TP     FN
        Neg   FP     TN
```

**Definiciones:**
- **TP**: True Positives (correcto positivo)
- **TN**: True Negatives (correcto negativo)
- **FP**: False Positives (falso alarma)
- **FN**: False Negatives (miss)

### 5.2 Accuracy

**Fórmula:**
$$Accuracy = \frac{TP + TN}{TP + TN + FP + FN}$$

**Limitación:**  
Engañosa con clases desbalanceadas.

**Ejemplo:**
- 95% negativos → accuracy 95% prediciendo siempre negativo

### 5.3 Precision & Recall

**Precision (Positive Predictive Value):**
$$Precision = \frac{TP}{TP + FP}$$

**Interpretación:**  
De los clasificados como positivos, ¿cuántos son realmente positivos?

**Recall (Sensitivity, TPR):**
$$Recall = \frac{TP}{TP + FN}$$

**Interpretación:**  
De los realmente positivos, ¿cuántos fueron detectados?

**Trade-off:**  
↑ Precision → ↓ Recall (y viceversa)

### 5.4 F1-Score

**Fórmula:**
$$F1 = 2 \times \frac{Precision \times Recall}{Precision + Recall}$$

**Interpretación:**  
Media armónica de Precision y Recall.

**Cuándo usar:**
- ✅ Clases desbalanceadas
- ✅ Queremos balance entre Precision/Recall

### 5.5 Specificity

**Fórmula:**
$$Specificity = \frac{TN}{TN + FP}$$

**Interpretación:**  
De los realmente negativos, ¿cuántos fueron correctamente clasificados?

### 5.6 AUC-ROC

**Ya explicado en módulo DEG.**

**Ventaja en ML:**  
Métrica independiente de umbral de clasificación.

**Uso en MicroarrAI:**
- Evaluar performance de cada modelo
- Comparar algoritmos
- Seleccionar modelo final

---

## 6. Algoritmos No Supervisados

### 6.1 K-Means Clustering

**Objetivo:**  
Particionar n muestras en k clusters minimizando varianza intra-cluster.

**Algoritmo:**
1. Inicializar k centroides aleatoriamente
2. Asignar cada muestra al centroide más cercano
3. Recalcular centroides como media de muestras asignadas
4. Repetir 2-3 hasta convergencia

**Función objetivo:**
$$\min \sum_{i=1}^{k} \sum_{x \in C_i} ||x - \mu_i||^2$$

**Elección de k:**
- **Elbow Method**: Busca "codo" en gráfico de varianza vs. k
- **Silhouette Score**: Mide cohesión y separación
- **Gap Statistic**: Compara con distribución nula

**Limitaciones:**
- Requiere especificar k a priori
- Sensible a inicialización (ejecutar múltiples veces)
- Asume clusters esféricos

### 6.2 Hierarchical Clustering

**Tipos:**

**Agglomerative (bottom-up):**
1. Cada muestra es un cluster
2. Merge clusters más cercanos iterativamente
3. Repetir hasta tener 1 cluster

**Divisive (top-down):**
1. Todas las muestras en 1 cluster
2. Split recursivamente

**Linkage Methods:**

- **Complete**: $\max d(a,b), a \in A, b \in B$
- **Single**: $\min d(a,b), a \in A, b \in B$
- **Average**: media de todas las distancias
- **Ward**: minimiza varianza intra-cluster

**Output: Dendrogram**  
Árbol que muestra fusiones progresivas.

**Ventajas:**
- ✅ No requiere especificar k
- ✅ Dendrograma interpretable
- ✅ Determinístico

### 6.3 PCA (Principal Component Analysis)

**Objetivo:**  
Reducir dimensionalidad proyectando datos en ejes de máxima varianza.

**Algoritmo:**
1. Centrar datos (restar media)
2. Calcular matriz de covarianza
3. Obtener eigenvectors/eigenvalues
4. Ordenar por eigenvalue decreciente
5. Proyectar en top k eigenvectors

**Componentes Principales:**
- **PC1**: dirección de máxima varianza
- **PC2**: dirección ortogonal de 2ª máxima varianza
- etc.

**Varianza Explicada:**
$$\text{Var Explained}_k = \frac{\sum_{i=1}^{k} \lambda_i}{\sum_{i=1}^{p} \lambda_i}$$

**Interpretación:**
- PC1+PC2 típicamente explican 40-70% varianza
- Scree plot: elegir k donde varianza incremental <5%

**Aplicaciones:**
- Visualización 2D/3D de datos alta dimensión
- Detección de outliers
- Pre-procesamiento antes de clustering

### 6.4 t-SNE

**t-Distributed Stochastic Neighbor Embedding**

**Objetivo:**  
Visualización no lineal que preserva estructura local.

**Ventajas sobre PCA:**
- ✅ Captura relaciones no lineales
- ✅ Preserva clusters complejos

**Limitaciones:**
- ❌ No determinístico (diferentes corridas → diferentes plots)
- ❌ Perplexity parameter crítico
- ❌ Solo para visualización (no para reducción dimensional en pipeline)

**Parámetro: Perplexity**
- Default: 30
- Rango: 5-50
- ↓ perplexity → enfoque en estructura local
- ↑ perplexity → enfoque en estructura global

---

## 7. Guía de Selección de Modelo

### 7.1 Flowchart de Decisión

```
¿Tienes labels (grupos)?
│
├─ NO → Unsupervised
│   ├─ Explorar agrupaciones → K-Means, Hierarchical
│   └─ Visualizar → PCA, t-SNE
│
└─ SÍ → Supervised
    │
    ├─ ¿Clases balanceadas?
    │   ├─ NO → Random Forest, SVM (ajustar weights)
    │   └─ SÍ → Cualquier modelo
    │
    ├─ ¿Relación lineal?
    │   ├─ SÍ → SVM linear, Naive Bayes
    │   └─ NO → SVM RBF, RF, GBM
    │
    ├─ ¿Muchas features (p >> n)?
    │   ├─ SÍ → SVM, RF + RFE
    │   └─ NO → Cualquier modelo
    │
    └─ ¿Interpretabilidad importante?
        ├─ SÍ → Random Forest (feature importance)
        └─ NO → Gradient Boosting (mejor accuracy)
```

### 7.2 Recomendaciones por Escenario

**Datos pequeños (n<50):**
- Random Forest (robusto a overfitting)
- Naive Bayes (simple, pocas suposiciones)
- SVM linear

**Datos desbalanceados:**
- Random Forest (sampsize parameter)
- SVM con class_weight
- RFE para feature selection

**Alta dimensionalidad (p>100):**
- SVM + RFE
- Random Forest
- Gradient Boosting

**Máxima accuracy:**
- Gradient Boosting
- Random Forest
- Ensemble de modelos

**Interpretabilidad:**
- Random Forest (feature importance)
- SVM linear (coeficientes)
- Naive Bayes (probabilidades)

---

## 8. Flujo de Trabajo Recomendado

### Pipeline Completo ML

```
1. Importar datos → Desde módulo DEG (top candidatos)

2. Split data → Train/Test (típ. 70/30 o 80/20)

3. Exploratorio (Unsupervised):
   a) PCA → Visualizar separación grupos
   b) Hierarchical clustering → Validar metadata

4. Feature Selection (opcional):
   a) RFE con Random Forest
   b) Seleccionar top 10-20 péptidos

5. Model Training:
   a) Probar 3-5 algoritmos
   b) Tune hiperparámetros con grid search
   c) 5-fold Stratified CV

6. Evaluation:
   a) Comparar AUC-ROC
   b) Revisar Confusion Matrix
   c) Analizar Feature Importance

7. Final Model:
   a) Reentrenar con todos los datos
   b) Exportar modelo
   c) Test en cohorte independiente

8. Interpretación:
   a) Identificar péptidos clave
   b) Validar biológicamente
   c) Diseñar ensayo diagnóstico
```

---

## 9. Troubleshooting

### Problema: Overfitting (Train >> Test accuracy)
**Soluciones:**
- Reducir complejidad modelo (↓ mtry, ↓ max_depth)
- Aplicar RFE (menos features)
- Aumentar regularización (↑ C en SVM)
- Más datos o data augmentation

### Problema: Underfitting (Baja accuracy en ambos)
**Soluciones:**
- Aumentar complejidad (↑ n_estimators, ↑ depth)
- Probar kernels no lineales (RBF)
- Feature engineering (interacciones)
- Verificar normalización

### Problema: AUC inconsistente entre CV folds
**Soluciones:**
- Repeated CV para estabilizar
- Verificar clases balanceadas en folds
- Más datos
- Ensemble averaging

### Problema: Todos los modelos fallan
**Soluciones:**
- Revisar calidad de datos (preprocesado)
- Verificar si problema es realmente predictivo
- Considerar más features (volver a DEG)
- Análisis exploratorio profundo (PCA, t-SNE)

---

## 10. Mejores Prácticas

### 10.1 Data Splitting

**Estrategia recomendada:**
```
- Training: 70%
- Validation: 15% (tuning hiperparámetros)
- Test: 15% (evaluación final, NO tocar hasta final)
```

**Alternativa con CV:**
```
- Training + CV: 80%
- Test (hold-out): 20%
```

### 10.2 Reproducibilidad

**Set seeds:**
- Random Forest: set.seed()
- SVM, KNN: reproducibles por naturaleza
- K-Means: set.seed() antes de inicialización

**Documentar:**
- Versión de librerías
- Hiperparámetros exactos
- Random seeds usados

### 10.3 Reporting

**Incluir:**
- Confusion matrix
- AUC-ROC con IC 95%
- Feature importance plot
- CV scores (media ± SD)
- Hiperparámetros finales

---

## 11. Próximos Pasos

### 11.1 Validación Externa

**Cohorte independiente:**
- Diferentes pacientes
- Mismo protocolo experimental
- Test definitivo de generalización

### 11.2 Ensambles

**Combinación de modelos:**
- Voting (mayoritario)
- Stacking (meta-modelo)
- Blending

### 11.3 Calibración de Probabilidades

**Métodos:**
- Platt scaling
- Isotonic regression

**Beneficio:**  
Probabilidades más confiables para toma de decisiones clínicas.

---

## 12. Referencias Científicas

- **Random Forest**: Breiman (2001) *Machine Learning*
- **SVM**: Cortes & Vapnik (1995) *Machine Learning*
- **Gradient Boosting**: Friedman (2001) *Annals of Statistics*
- **RFE**: Guyon et al. (2002) *Machine Learning*
- **Cross-Validation**: Kohavi (1995) *IJCAI*

---

**¡Felicidades!** Has completado el pipeline completo de MicroarrAI: desde datos brutos hasta modelos predictivos robustos. Los modelos entrenados aquí pueden ser base para ensayos diagnósticos clínicos tras validación adecuada.
