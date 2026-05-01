# 📚 MicroarrAI - Guía de Usuario Completa

## Bienvenido a MicroarrAI

Esta plataforma integra el análisis completo de datos de microarrays de péptidos, desde el preprocesado de datos brutos hasta la construcción de modelos predictivos de machine learning.

---

## 🎯 Objetivos de esta Documentación

### 1. **How-to-Use Guide**
Guía paso a paso para usuarios que desean analizar sus datos sin necesidad de conocimientos profundos de programación.

### 2. **Fundamentos Científicos**
Explicación de la base estadística y científica detrás de cada método, para usuarios que desean comprender la teoría.

---

## 📖 Contenido

### [1. Preprocesado de Datos](01_preprocessing.md)

**Temas cubiertos:**
- Modos de entrada (RAW vs. Processed)
- Configuración de controles positivos/negativos
- Detección y manejo de duplicados técnicos
- Métodos de normalización:
  - Log transformation
  - Z-score
  - Quantile normalization
  - Median centering
- Control de calidad (CV, SNR)
- Visualizaciones QC
- Troubleshooting

**¿Para quién?**
- Usuarios iniciando análisis desde archivos GenePix
- Investigadores que necesitan normalizar datos
- Equipos evaluando calidad de experimentos

**Tiempo estimado:** 15-20 minutos de lectura

---

### [2. Análisis DEG y Selección de Candidatos](02_deg_analysis.md)

**Temas cubiertos:**
- Tests estadísticos:
  - t-test, ANOVA
  - Wilcoxon, Kruskal-Wallis
- Corrección por múltiples comparaciones:
  - Bonferroni
  - Benjamini-Hochberg (FDR)
  - Holm-Bonferroni
- Fold Change analysis
- AUC (Area Under the Curve)
- Estratificación de candidatos
- Visualizaciones (Volcano plots, MA plots, Heatmaps)
- Validación estadística

**¿Para quién?**
- Investigadores identificando biomarcadores
- Usuarios con datos preprocesados
- Equipos realizando estudios case-control

**Tiempo estimado:** 20-25 minutos de lectura

---

### [3. Machine Learning](03_machine_learning.md)

**Temas cubiertos:**
- Aprendizaje supervisado vs. no supervisado
- Algoritmos supervisados:
  - Random Forest
  - Support Vector Machine (SVM)
  - K-Nearest Neighbors (KNN)
  - Naive Bayes
  - Gradient Boosting
- Feature Selection (RFE)
- Validación cruzada (K-Fold, Stratified)
- Métricas de evaluación:
  - Accuracy, Precision, Recall
  - F1-Score, AUC-ROC
  - Confusion Matrix
- Algoritmos no supervisados:
  - K-Means Clustering
  - Hierarchical Clustering
  - PCA, t-SNE
- Guía de selección de modelos
- Troubleshooting

**¿Para quién?**
- Usuarios construyendo modelos predictivos
- Investigadores validando biomarcadores
- Equipos desarrollando ensayos diagnósticos

**Tiempo estimado:** 30-35 minutos de lectura

---

## 🚀 Flujo de Trabajo Completo

```
┌─────────────────────────────────────────────────────────────┐
│                    1. PREPROCESADO                          │
│  • Carga de datos RAW (GenePix) o matrices procesadas      │
│  • Normalización (Log2, Quantile, etc.)                    │
│  • Control de calidad (CV, SNR, PCA)                       │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│              2. ANÁLISIS DEG & CANDIDATOS                   │
│  • Tests estadísticos (t-test, ANOVA, etc.)                │
│  • Corrección FDR                                           │
│  • Cálculo de Fold Changes y AUC                           │
│  • Selección de top candidatos                             │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
┌─────────────────────────────────────────────────────────────┐
│               3. MACHINE LEARNING                           │
│  • Feature selection (RFE)                                  │
│  • Entrenamiento de modelos (RF, SVM, etc.)                │
│  • Validación cruzada                                       │
│  • Evaluación y selección de modelo óptimo                 │
└─────────────────┬───────────────────────────────────────────┘
                  │
                  ▼
              🎉 RESULTADOS
          (Panel de biomarcadores)
```

---

## 💡 Consejos Rápidos

### Para Principiantes

1. **Empieza con el preprocesado estándar:**
   - Log2 transform → Quantile normalization → Median centering
   
2. **Usa defaults sensatos:**
   - FDR correction (Benjamini-Hochberg)
   - Random Forest con 500 trees
   - 5-fold cross-validation

3. **Visualiza siempre tus datos:**
   - PCA para detectar outliers
   - Boxplots para verificar normalización
   - Volcano plots para ver candidatos

### Para Usuarios Avanzados

1. **Optimiza hiperparámetros:**
   - Grid search para SVM (C, gamma)
   - Tune mtry en Random Forest
   
2. **Combina modelos:**
   - Ensemble de RF + SVM + GBM
   - Voting o stacking

3. **Valida rigurosamente:**
   - Repeated cross-validation
   - Cohortes independientes
   - Bootstrap confidence intervals

---

## 📊 Datasets de Ejemplo

**Pequeño (n<50, p<100):**
- Random Forest o Naive Bayes
- RFE para reducir a 10-20 features
- 5-fold CV

**Mediano (n=50-200, p=100-500):**
- SVM RBF o Random Forest
- Quantile normalization
- 10-fold CV

**Grande (n>200, p>500):**
- Gradient Boosting
- RFE agresivo (step > 1)
- Train/Validation/Test split

---

## 🔧 Solución de Problemas Comunes

### Mi experimento tiene bajo SNR
**Ver:** [Preprocesado - Sección 7](01_preprocessing.md#7-troubleshooting)

### No encuentro péptidos significativos
**Ver:** [DEG Analysis - Sección 10](02_deg_analysis.md#10-troubleshooting)

### Mis modelos hacen overfitting
**Ver:** [Machine Learning - Sección 9](03_machine_learning.md#9-troubleshooting)

---

## 📚 Recursos Adicionales

### Lecturas Recomendadas

1. **Microarray Analysis:**
   - Quackenbush (2002) - "Microarray data normalization and transformation"
   - Smyth (2004) - "Linear models and empirical Bayes methods"

2. **Machine Learning:**
   - Hastie et al. (2009) - "The Elements of Statistical Learning"
   - Kuhn & Johnson (2013) - "Applied Predictive Modeling"

3. **Biomarker Discovery:**
   - Pepe et al. (2008) - "Limitations of the odds ratio"
   - Ransohoff (2004) - "Rules of evidence for cancer biomarkers"

### Tutoriales Externos

- **Cross-Validation:** [scikit-learn User Guide](https://scikit-learn.org/)
- **ROC Analysis:** Fawcett (2006) *Pattern Recognition Letters*
- **Random Forests:** Breiman's original paper (2001)

---

## 👥 Equipo y Contacto

**Desarrolladores:**
- Sergio Olmos Piñero
- Val Fernández Lanza
- Javier Martínez-Botas
- Belén de la Hoz Caballer
- Miguel Ángel Sicilia Urban

**Versión:** 1.0  
**Última actualización:** Enero 2026

---

## 🆘 ¿Necesitas Ayuda?

Si encuentras errores, tienes sugerencias o necesitas soporte:

1. Revisa esta documentación completa
2. Consulta las secciones de Troubleshooting
3. Contacta al equipo de desarrollo

---

**¡Bienvenido a MicroarrAI!** 🎉  
Esperamos que esta plataforma potencie tu investigación en biomarcadores de péptidos.
