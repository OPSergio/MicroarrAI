# 🧬 Análisis DEG y Selección de Candidatos

## Introducción

El módulo de análisis estadístico identifica péptidos diferencialmente expresados (DEG) entre grupos experimentales y selecciona candidatos con potencial diagnóstico/terapéutico basándose en significancia estadística y capacidad discriminativa.

---

## 1. Análisis de Expresión Diferencial (DEG)

### 1.1 Test t de Student

**Base estadística:**  
Compara medias de dos grupos independientes bajo supuesto de normalidad.

**Hipótesis:**
- **H₀**: μ₁ = μ₂ (sin diferencia)
- **H₁**: μ₁ ≠ μ₂ (hay diferencia)

**Fórmula:**  
$$t = \frac{\bar{x}_1 - \bar{x}_2}{s_p \sqrt{\frac{1}{n_1} + \frac{1}{n_2}}}$$

Donde $s_p$ es la desviación estándar pooled.

**Cuándo usar:**
- ✅ Dos grupos (ej. Control vs. Treatment)
- ✅ Datos aproximadamente normales (tras log-transform)
- ✅ Varianzas similares entre grupos

**Interpretación:**
- **p-value < 0.05**: Diferencia significativa
- **|t| > 2**: Efecto moderado a fuerte

### 1.2 ANOVA (Analysis of Variance)

**Base estadística:**  
Compara medias de 3+ grupos simultáneamente.

**Hipótesis:**
- **H₀**: μ₁ = μ₂ = ... = μₖ (todas las medias iguales)
- **H₁**: Al menos una media difiere

**Fórmula (F-statistic):**  
$$F = \frac{MS_{between}}{MS_{within}} = \frac{\frac{SS_{between}}{k-1}}{\frac{SS_{within}}{N-k}}$$

**Cuándo usar:**
- ✅ 3+ grupos experimentales
- ✅ Análisis global de variabilidad
- ✅ Antes de tests post-hoc

**Post-hoc tests (si F significativo):**
- Tukey HSD: Comparaciones pareadas conservadoras
- Bonferroni: Control estricto de error tipo I

### 1.3 Wilcoxon Rank-Sum Test (Mann-Whitney U)

**Base estadística:**  
Test no paramétrico que compara medianas sin asumir normalidad.

**Principio:**
1. Rankea todos los valores combinados
2. Suma ranks de cada grupo
3. Evalúa si sumas difieren significativamente

**Cuándo usar:**
- ✅ Datos no normales (incluso tras transformación)
- ✅ Muestras pequeñas (n < 30)
- ✅ Outliers extremos presentes
- ✅ Datos ordinales

**Limitación:**  
Menor poder estadístico que t-test si datos son normales.

### 1.4 Kruskal-Wallis Test

**Base estadística:**  
Extensión no paramétrica de ANOVA para 3+ grupos.

**Hipótesis:**
- **H₀**: Todas las distribuciones son iguales
- **H₁**: Al menos una distribución difiere

**Estadístico H:**  
$$H = \frac{12}{N(N+1)} \sum_{i=1}^{k} \frac{R_i^2}{n_i} - 3(N+1)$$

**Cuándo usar:**
- ✅ 3+ grupos no normales
- ✅ Alternativa robusta a ANOVA

---

## 2. Corrección por Múltiples Comparaciones

### Problema del Testing Múltiple

Al testear miles de péptidos simultáneamente:

**Ejemplo:**  
- 1000 péptidos × α=0.05 → 50 falsos positivos esperados

### 2.1 Bonferroni Correction

**Método:**  
Ajusta umbral de p-value dividiendo por número de tests.

**Fórmula:**  
$$\alpha_{adjusted} = \frac{\alpha}{m}$$

Donde m = número de tests.

**Ejemplo:**  
- m = 1000 péptidos, α = 0.05
- α_adjusted = 0.05/1000 = 0.00005

**Ventajas:**
- ✅ Control estricto de FWER (Family-Wise Error Rate)
- ✅ Simple de interpretar

**Desventajas:**
- ❌ Muy conservador (baja sensibilidad)
- ❌ Asume tests independientes

### 2.2 Benjamini-Hochberg (FDR)

**Método:**  
Controla la proporción esperada de falsos positivos (FDR).

**Algoritmo:**
1. Ordena p-values: p₁ ≤ p₂ ≤ ... ≤ pₘ
2. Encuentra máximo i donde: $p_i \leq \frac{i}{m} \times \alpha$
3. Rechaza H₀ para tests 1 a i

**Ejemplo:**  
- α = 0.05 (5% FDR)
- Significa: ~5% de péptidos "significativos" son falsos positivos

**Ventajas:**
- ✅ Menos conservador que Bonferroni
- ✅ Equilibrio sensibilidad/especificidad
- ✅ Estándar en bioinformática

**Recomendación:**  
🌟 **Método preferido para análisis de microarrays**

### 2.3 Holm-Bonferroni

**Método:**  
Versión secuencial step-down de Bonferroni.

**Algoritmo:**
1. Ordena p-values
2. Test 1: requiere p ≤ α/m
3. Test 2: requiere p ≤ α/(m-1)
4. ...y así sucesivamente

**Ventaja:**
- Más potente que Bonferroni estándar
- Controla FWER

---

## 3. Fold Change Analysis

### 3.1 Definición

**Fold Change (FC):**  
Ratio de expresión media entre grupos.

**Fórmula (datos log2):**  
$$FC = 2^{(\bar{x}_{group1} - \bar{x}_{group2})}$$

**Fórmula (datos lineales):**  
$$FC = \frac{\bar{x}_{group1}}{\bar{x}_{group2}}$$

### 3.2 Log2 Fold Change (L2FC)

**Ventaja de log2:**  
Cambios simétricos up/down.

**Interpretación:**
- **L2FC = +1**: 2× más expresado en grupo1
- **L2FC = -1**: 2× menos expresado (0.5×)
- **L2FC = +2**: 4× más expresado
- **L2FC = -2**: 4× menos expresado (0.25×)

### 3.3 Umbrales Comunes

**Péptidos diferenciales:**
- **|L2FC| > 1**: Cambio de 2× (estándar)
- **|L2FC| > 1.5**: Cambio de ~3× (conservador)

**Filtro combinado típico:**
```
Candidatos = |L2FC| > 1 AND adjusted p-value < 0.05
```

---

## 4. AUC (Area Under the Curve)

### 4.1 ROC Curve

**Definición:**  
Curva ROC (Receiver Operating Characteristic) grafica sensibilidad vs. (1-especificidad).

**Componentes:**
- **Sensibilidad (TPR)**: $\frac{TP}{TP + FN}$
- **Especificidad**: $\frac{TN}{TN + FP}$
- **1-Especificidad (FPR)**: $\frac{FP}{FP + TN}$

### 4.2 Interpretación de AUC

**Valores:**
- **AUC = 1.0**: Clasificador perfecto
- **AUC = 0.9-1.0**: Excelente
- **AUC = 0.8-0.9**: Bueno
- **AUC = 0.7-0.8**: Aceptable
- **AUC = 0.5-0.7**: Pobre
- **AUC = 0.5**: Clasificación aleatoria

**Significado biológico:**  
AUC es la probabilidad de que un péptido asigne un score mayor a un caso verdadero positivo que a un negativo.

### 4.3 Selección de Candidatos por AUC

**Umbral típico:**
```
Candidatos potenciales: AUC > 0.70
Buenos biomarcadores: AUC > 0.80
Biomarcadores excelentes: AUC > 0.90
```

**Combinación con estadística:**
```
Top Candidates = AUC > 0.80 AND adj.p < 0.05 AND |L2FC| > 1
```

---

## 5. Estratificación de Candidatos

### 5.1 Niveles de Evidencia

**Tier 1 (Máxima prioridad):**
- AUC > 0.85
- adj.p < 0.01
- |L2FC| > 1.5

**Tier 2 (Alta prioridad):**
- AUC > 0.75
- adj.p < 0.05
- |L2FC| > 1

**Tier 3 (Moderada prioridad):**
- AUC > 0.70
- adj.p < 0.05
- |L2FC| > 0.5

### 5.2 Ranking Multi-Criterio

**Score compuesto:**
$$Score = w_1 \times AUC + w_2 \times (-\log_{10}(p)) + w_3 \times |L2FC|$$

**Pesos sugeridos (ejemplo):**
- w₁ = 0.5 (AUC, capacidad discriminativa)
- w₂ = 0.3 (significancia estadística)
- w₃ = 0.2 (magnitud de cambio)

---

## 6. Visualizaciones Clave

### 6.1 Volcano Plot

**Ejes:**
- X: Log2 Fold Change
- Y: -log10(p-value)

**Interpretación:**
- **Cuadrante superior derecho**: Up-regulated + significativo
- **Cuadrante superior izquierdo**: Down-regulated + significativo
- **Zona central**: No significativo

**Código conceptual:**
```r
plot(log2FC, -log10(p.value))
abline(h = -log10(0.05), col = "red")  # Umbral p-value
abline(v = c(-1, 1), col = "blue")     # Umbral FC
```

### 6.2 MA Plot

**Ejes:**
- X: A = log2(media expresión)
- Y: M = log2(FC)

**Utilidad:**
- Detecta bias dependiente de intensidad
- Visualiza normalización

### 6.3 Heatmap de Top Candidatos

**Configuración:**
- Filas: Top péptidos (por AUC o p-value)
- Columnas: Muestras
- Clustering jerárquico automático

**Interpretación:**
- Bloques claros/oscuros → separación grupos
- Clustering → validación de clasificación

---

## 7. Validación Estadística

### 7.1 Power Analysis

**Pregunta:**  
¿Tengo suficientes muestras para detectar diferencias reales?

**Factores:**
- **α**: Nivel de significancia (típ. 0.05)
- **β**: Error tipo II (típ. 0.2)
- **Power**: 1-β (típ. 0.8 = 80%)
- **Effect size**: Cohen's d

**Recomendación:**  
Mínimo n=5 por grupo para detectar FC > 2×

### 7.2 Bootstrap Resampling

**Método:**  
Re-muestrea con reemplazo para estimar robustez de estadísticos.

**Aplicación:**
- Calcular CI de AUC
- Validar estabilidad de fold changes
- Evaluar reproducibilidad de rankings

---

## 8. Flujo de Trabajo Recomendado

### Pipeline Estándar DEG

```
1. Preprocesado → Datos normalizados
2. Definir comparaciones → Grupos experimentales
3. Elegir test estadístico:
   - 2 grupos normales → t-test
   - 2 grupos no normales → Wilcoxon
   - 3+ grupos normales → ANOVA
   - 3+ grupos no normales → Kruskal-Wallis
4. Calcular p-values
5. Ajustar por múltiples tests → Benjamini-Hochberg
6. Calcular Fold Changes
7. Calcular AUC para cada péptido
8. Filtrar candidatos:
   - adj.p < 0.05
   - |L2FC| > 1
   - AUC > 0.70
9. Rankear por score compuesto
10. Visualizar → Volcano, Heatmap, ROC
11. Exportar top candidatos → ML module
```

---

## 9. Consideraciones Biológicas

### 9.1 Validación Experimental

**Criterios para validación:**
1. Seleccionar top 10-20 candidatos
2. Confirmar en cohorte independiente
3. Ensayos ortogonales (ELISA, Western blot)

### 9.2 Contexto Clínico

**Interpretación:**
- AUC alto no garantiza utilidad clínica
- Considerar prevalencia de enfermedad
- Evaluar costo-beneficio de diagnóstico

### 9.3 Combinaciones de Péptidos

**Hipótesis:**  
Paneles multi-péptido pueden superar biomarcadores individuales.

**Método:**
- Exportar top N candidatos a módulo ML
- Entrenar modelos con múltiples features
- Evaluar AUC del modelo combinado

---

## 10. Troubleshooting

### Problema: Ningún péptido significativo
**Soluciones:**
- Revisar poder estadístico (n suficiente?)
- Verificar normalización (batch effects?)
- Ajustar umbrales (explorar p < 0.1)
- Usar tests no paramétricos si outliers

### Problema: Demasiados significativos
**Soluciones:**
- Aplicar corrección FDR más estricta
- Aumentar umbral de FC (|L2FC| > 1.5)
- Filtrar por AUC > 0.80

### Problema: AUC inconsistente con p-value
**Explicación:**
- p-value: significancia de diferencia
- AUC: capacidad discriminativa
- Posible diferencia significativa pero overlap grande

---

## 11. Referencias Científicas

- **FDR**: Benjamini & Hochberg (1995) *J R Stat Soc B*
- **Volcano plots**: Cui & Churchill (2003) *Genome Biol*
- **AUC interpretation**: Hanley & McNeil (1982) *Radiology*
- **Fold change**: Tusher et al. (2001) *PNAS*

---

**Siguiente paso:** Exporta tus candidatos seleccionados al módulo **Machine Learning** para construir modelos predictivos robustos y evaluar su capacidad de generalización.
