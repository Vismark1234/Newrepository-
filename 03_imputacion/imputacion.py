"""Pipeline básico de imputación: ajustar únicamente con entrenamiento."""
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.impute import SimpleImputer
from sklearn.pipeline import Pipeline

def crear_imputador(X_entrenamiento: pd.DataFrame):
    """Devuelve un transformador sin ajustar, con estrategias por tipo."""
    numericas = X_entrenamiento.select_dtypes(include="number").columns.tolist()
    categoricas = [c for c in X_entrenamiento.columns if c not in numericas]
    pasos = []
    if numericas:
        pasos.append(("numericas", SimpleImputer(strategy="median", add_indicator=True), numericas))
    if categoricas:
        pasos.append(("categoricas", Pipeline([
            ("imputar", SimpleImputer(strategy="most_frequent"))
        ]), categoricas))
    if not pasos:
        raise ValueError("No hay columnas para imputar")
    return ColumnTransformer(pasos, remainder="drop", verbose_feature_names_out=True)

# Ejemplo:
# imputador = crear_imputador(X_train)
# X_train_imputado = imputador.fit_transform(X_train)
# X_test_imputado = imputador.transform(X_test)
