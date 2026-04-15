# 📊 Preprocesado de Datos

## Introducción

El módulo de preprocesado es el primer paso crítico en el análisis de datos de microarrays de péptidos. Esta fase transforma datos brutos en matrices normalizadas listas para análisis estadístico y de machine learning.

---

## 1. Modos de Entrada

### 1.1 Modo RAW (GenePix)

**¿Cuándo usar?**  
Cuando tienes archivos CSV directamente desde el escáner GenePix.

**Ventajas:**
- Control total sobre el proceso de normalización
- Acceso a métricas de calidad crudas
- Eliminación de backgrounds personalizables
- Detección automática de duplicados técnicos

**Proceso:**
1. El sistema detecta automáticamente el header de GenePix
2. Extrae IDs de analitos y limpia nombres
3. Aplica normalizaciones seleccionadas en cascada
4. Genera métricas de calidad en tiempo real

### 1.2 Modo Processed Matrix

**¿Cuándo usar?**  
Cuando ya tienes datos pre-normalizados de otra fuente.

**Ventajas:**
- Inicio rápido para datos ya procesados
- Compatible con matrices de otras plataformas
- Salta directamente al análisis estadístico

**Formato esperado:**
```
Analyte,Sample1,Sample2,Sample3,...
Peptide_001,1234.5,2345.6,3456.7,...
Peptide_002,876.4,987.5,1098.6,...
```

---

## 2. Configuración de Controles

### 2.1 Controles Positivos y Negativos

**Base científica:**  
Los controles permiten evaluar la calidad del experimento y normalizar la señal específica vs. ruido de fondo.

**Configuración:**
- **Controles Positivos**: Péptidos con señal esperada alta (ej. anticuerpos de control)
- **Controles Negativos**: Péptidos sin señal esperada (ej. buffer, péptidos irrelevantes)
- **Formato**: Usa prefijos o nombres exactos separados por comas

**Ejemplo:**
```
Positivos: POS_, CTRL_POS, IgG_control
Negativos: NEG_, CTRL_NEG, Buffer
```

### 2.2 Clasificación de Muestras

**Propósito:**  
Define grupos experimentales para análisis comparativos (DEG, ML supervisado).

**Metadata requerida:**
- **Group**: Condición experimental (ej. Control, Treatment, Disease)
- **Sample_ID**: Identificador único
- Columnas adicionales opcionales para análisis estratificado

---

## 3. Detección de Duplicados

### 3.1 Duplicados Técnicos

**Definición:**  
El mismo péptido impreso múltiples veces en el array (replicados spot).

**Estrategias de consolidación:**

#### Media (Recomendado)
- **Ventaja**: Robusta a outliers moderados
- **Cuándo usar**: Datos con distribución normal
- **Fórmula**: $\bar{x} = \frac{1}{n}\sum_{i=1}^{n} x_i$

#### Mediana
- **Ventaja**: Muy robusta a outliers extremos
- **Cuándo usar**: Datos con valores aberrantes sospechosos
- **Fórmula**: $M = x_{(n+1)/2}$ si n es impar

#### Suma
- **Ventaja**: Preserva señal acumulativa
- **Cuándo usar**: Análisis de señal total (raramente recomendado)

**Nota:** La media es el método estándar en literatura de microarrays.

---

## 4. Normalización de Datos

### 4.1 Normalización por Log

**Base matemática:**  
Transforma datos mediante logaritmo para estabilizar varianza y linealizar relaciones.

**Opciones disponibles:**

#### Log2 (Recomendado para microarrays)
- **Fórmula**: $y = \log_2(x)$
- **Ventaja**: Fold-changes simétricos (2x up = -2x down)
- **Interpretación directa de cambios de expresión**

#### Log10
- **Fórmula**: $y = \log_{10}(x)$
- **Ventaja**: Escalas familiares (órdenes de magnitud)

#### Natural Log (ln)
- **Fórmula**: $y = \ln(x)$
- **Ventaja**: Propiedades matemáticas para modelos estadísticos

**Pseudo-count:**  
Se añade automáticamente +1 a valores ≤0 para evitar log(0) = -∞.

### 4.2 Z-Score Normalization

**Definición:**  
Estandariza cada muestra a media=0 y desviación estándar=1.

**Fórmula:**  
$$z = \frac{x - \mu}{\sigma}$$

**Cuándo aplicar:**
- ✅ Comparar muestras con escalas diferentes
- ✅ Antes de clustering o PCA
- ✅ Machine learning (SVM, KNN)

**Precaución:**  
⚠️ Puede distorsionar diferencias biológicas reales si se aplica incorrectamente.

### 4.3 Quantile Normalization

**Principio:**  
Iguala las distribuciones de todas las muestras, asumiendo que la mayoría de péptidos no cambian.

**Algoritmo:**
1. Ordena valores de cada muestra
2. Reemplaza cada valor por la media de su rango
3. Reordena a posiciones originales

**Cuándo usar:**
- ✅ Comparaciones entre múltiples arrays
- ✅ Batch effects evidentes
- ✅ Análisis DEG estricto

**Limitación:**  
Asume que cambios globales son artifacts, no biología real.

### 4.4 Median Centering

**Método:**  
Centra cada muestra restando su mediana.

**Fórmula:**  
$$x_{norm} = x - \text{median}(X)$$

**Cuándo usar:**
- ✅ Corrección de offsets entre experimentos
- ✅ Datos con distribuciones ya similares
- ✅ Alternativa suave a quantile normalization

---

## 5. Control de Calidad (QC)

### 5.1 Coeficiente de Variación (CV)

**Definición:**  
Medida de dispersión relativa de los controles.

**Fórmula:**  
$$CV = \frac{\sigma}{\mu} \times 100\%$$

**Interpretación:**
- **CV < 10%**: Excelente reproducibilidad
- **CV 10-20%**: Aceptable para microarrays
- **CV > 20%**: Revisar experimento

### 5.2 Signal-to-Noise Ratio (SNR)

**Definición:**  
Relación entre señal específica y ruido de fondo.

**Fórmula:**  
$$SNR = \frac{\mu_{positivos} - \mu_{negativos}}{\sigma_{negativos}}$$

**Interpretación:**
- **SNR > 3**: Buena separación señal/ruido
- **SNR 1-3**: Marginal, considerar replicados
- **SNR < 1**: Experimento fallido

### 5.3 Visualizaciones QC

#### Boxplots por Muestra
- Evalúa distribuciones y outliers
- Verifica efectividad de normalización

#### Heatmap de Correlación
- Identifica muestras problemáticas
- Detecta batch effects

#### PCA Plot
- Explora variabilidad entre muestras
- Detecta clusters inesperados

---

## 6. Flujo de Trabajo Recomendado

### Pipeline Estándar

```
1. Input Mode → RAW
2. Load GenePix Files → Automatic detection
3. Define Controls → Positive/Negative patterns
4. Sample Classification → Upload metadata
5. Duplicate Handling → Mean
6. Normalization Steps:
   a) Log2 Transform
   b) Quantile Normalization
   c) Median Centering (opcional)
7. QC Check → CV, SNR, PCA
8. Export → Proceed to DEG Analysis
```

### Pipeline para Datos Pequeños (<50 péptidos)

```
1. Input Mode → RAW
2. Normalization:
   a) Log2 Transform
   b) Median Centering (sin quantile)
3. QC manual con boxplots
```

---

## 7. Troubleshooting

### Problema: CV muy alto
**Soluciones:**
- Verificar controles positivos/negativos
- Revisar duplicados técnicos outliers
- Considerar remover muestras problemáticas

### Problema: SNR bajo
**Soluciones:**
- Aumentar concentración de suero
- Revisar condiciones de incubación
- Verificar controles negativos (¿contaminación?)

### Problema: Batch effects en PCA
**Soluciones:**
- Aplicar quantile normalization
- Usar ComBat (requiere metadata de batch)
- Estratificar análisis por batch

---

## 8. Referencias Científicas

- **Quantile Normalization**: Bolstad et al. (2003) *Bioinformatics*
- **Z-Score**: Cheadle et al. (2003) *J Mol Diagn*
- **CV thresholds**: Kammila et al. (2008) *BMC Genomics*
- **Log transformation**: Quackenbush (2002) *Nat Genet*

---

**Siguiente paso:** Una vez completado el preprocesado, procede al módulo **DEG & Candidate Selection** para identificar péptidos diferenciales.
