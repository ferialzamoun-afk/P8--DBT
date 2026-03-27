from pathlib import Path

import pandas as pd
import plotly.express as px
import streamlit as st


st.set_page_config(
    page_title="P8 - Dashboard OC vs INSEE",
    page_icon="📊",
    layout="wide",
)


@st.cache_data
def load_csv(csv_path: Path) -> pd.DataFrame:
    if not csv_path.exists():
        raise FileNotFoundError(f"Fichier introuvable: {csv_path}")
    return pd.read_csv(csv_path)


def format_int(value: float) -> str:
    try:
        return f"{int(round(float(value), 0)):,}".replace(",", " ")
    except Exception:
        return "0"


def format_pct(value: float) -> str:
    try:
        return f"{float(value):.2f}%"
    except Exception:
        return "0.00%"



BASE_DIR = Path(__file__).resolve().parent
EXPORTS_DIR = BASE_DIR / "exports"

st.title("Dashboard P8 - Représentativité Étudiants OC vs INSEE")
st.caption("Toutes les analyses sont issues du fichier unique exports/fct_export_unifie.csv généré par dbt.")

try:
    df_unified = load_csv(EXPORTS_DIR / "fct_export_unifie.csv")
except FileNotFoundError as err:
    st.error(str(err))
    st.stop()

# Normalisation des types
cols_to_numeric = [
    "NB_ETUDIANTS",
    "NB_INSCRITS_TOUS_GENRES",
    "POPULATION_INSEE",
    "NB_DEPARTMENTS",
    "TOTAL_ETU_REGION",
    "TOTAL_INSEE_REGION",
    "PCT_FEMMES_ETU",
    "PCT_FEMMES_INSEE",
    "GAP_FEMMES_PCT",
]
for col in cols_to_numeric:
    if col in df_unified.columns:
        df_unified[col] = pd.to_numeric(df_unified[col], errors="coerce")

# Filtres dynamiques
available_years = sorted([int(y) for y in df_unified["YEAR"].dropna().unique().tolist()])
default_years = available_years[-2:] if len(available_years) > 1 else available_years
selected_years = st.sidebar.multiselect(
    "Années",
    options=available_years,
    default=default_years,
)

available_regions = sorted([r for r in df_unified["REGION"].dropna().unique().tolist()])
selected_regions = st.sidebar.multiselect(
    "Régions",
    options=available_regions,
    default=available_regions,
)


# Découpage des vues à partir du CSV unique (adapté aux colonnes existantes)
df_trend = df_unified.copy()
df_women = df_unified.copy()
df_region = df_unified.copy()
df_age = df_unified.copy()

# Application des filtres
trend_filtered = df_trend[df_trend["YEAR"].isin(selected_years)] if selected_years else df_trend
women_filtered = df_women[df_women["YEAR"].isin(selected_years)] if selected_years else df_women
region_filtered = df_region[df_region["REGION"].isin(selected_regions)] if selected_regions else df_region



# KPIs
kpi_total_students = trend_filtered["NB_ETUDIANTS"].sum(skipna=True)
kpi_latest_year = int(trend_filtered["YEAR"].max()) if not trend_filtered.empty else None
kpi_latest_students = (
    trend_filtered.loc[trend_filtered["YEAR"] == kpi_latest_year, "NB_ETUDIANTS"].sum(skipna=True)
    if kpi_latest_year is not None
    else 0
)


if not women_filtered.empty:
    kpi_gap_women = women_filtered["GAP_FEMMES_PCT"].mean(skipna=True)
else:
    kpi_gap_women = 0.0


# La colonne 'surrepresentation' n'existe pas dans le CSV, donc on ne calcule pas ce KPI
kpi_region_over = None

c1, c2, c3, c4 = st.columns(4)
c1.metric("Etudiants OC (selection)", format_int(kpi_total_students))
c2.metric("Dernière année", str(kpi_latest_year) if kpi_latest_year else "n/a")
c3.metric("Etudiants dernière année", format_int(kpi_latest_students))
c4.metric("Ecart moyen femmes OC vs INSEE", format_pct(kpi_gap_women))

st.divider()

# Charts row 1
left1, right1 = st.columns(2)

with left1:
    st.subheader("Tendance annuelle des etudiants OC")
    # Agréger par année pour éviter les doublons
    trend_agg = trend_filtered.groupby("YEAR", as_index=False)["NB_ETUDIANTS"].sum().drop_duplicates(subset=["YEAR"])
    trend_agg = trend_agg.sort_values("YEAR")
    trend_agg["YEAR"] = pd.to_numeric(trend_agg["YEAR"], errors="coerce").astype('Int64')
    chart_trend = px.line(
        trend_agg,
        x="YEAR",
        y="NB_ETUDIANTS",
        markers=True,
        labels={"YEAR": "Annee", "NB_ETUDIANTS": "Nb etudiants"},
        title="Evolution des effectifs OC",
    )
    chart_trend.update_layout(height=420, xaxis_tickformat='d')
    st.plotly_chart(chart_trend, use_container_width=True)

with right1:
    st.subheader("Part des femmes: OC vs INSEE")
    women_plot = women_filtered.copy()
    if not women_plot.empty:
        women_plot["YEAR"] = pd.to_numeric(women_plot["YEAR"], errors="coerce").astype('Int64')
        # Agréger par année (moyenne des pourcentages)
        women_agg = women_plot.groupby("YEAR", as_index=False)[["PCT_FEMMES_ETU", "PCT_FEMMES_INSEE"]].mean().drop_duplicates(subset=["YEAR"])
        women_agg = women_agg.sort_values("YEAR")
        women_long = women_agg.melt(
            id_vars=["YEAR"],
            value_vars=["PCT_FEMMES_ETU", "PCT_FEMMES_INSEE"],
            var_name="Serie",
            value_name="Pct",
        )
        women_long["Serie"] = women_long["Serie"].map(
            {"PCT_FEMMES_ETU": "Femmes OC", "PCT_FEMMES_INSEE": "Femmes INSEE"}
        )
        chart_women = px.line(
            women_long,
            x="YEAR",
            y="Pct",
            color="Serie",
            markers=True,
            labels={"YEAR": "Annee", "Pct": "% femmes"},
            title="Comparaison de la representation feminine",
        )
        chart_women.update_layout(height=420, xaxis_tickformat='d')
        st.plotly_chart(chart_women, use_container_width=True)
    else:
        st.info("Pas de donnees disponibles pour la selection courante.")

# Charts row 2
left2, right2 = st.columns(2)

with left2:
    st.subheader("Repartition OC par tranche age")
    age_plot = df_age.sort_values("NB_ETUDIANTS", ascending=False)
    chart_age = px.bar(
        age_plot,
        x="NB_ETUDIANTS",
        y="AGE_GROUP",
        orientation="h",
        labels={"NB_ETUDIANTS": "Nb etudiants", "AGE_GROUP": "Tranche age"},
        title="Distribution des etudiants par age",
    )
    chart_age.update_layout(height=420)
    st.plotly_chart(chart_age, use_container_width=True)

with right2:

    st.subheader("Ecart femmes OC vs INSEE par région")
    region_plot = region_filtered.sort_values("GAP_FEMMES_PCT", ascending=False)
    chart_region = px.bar(
        region_plot,
        x="GAP_FEMMES_PCT",
        y="REGION",
        orientation="h",
        labels={"GAP_FEMMES_PCT": "Ecart femmes (%)", "REGION": "Region"},
        title="Ecart femmes OC vs INSEE par région",
    )
    chart_region.update_layout(height=420)
    st.plotly_chart(chart_region, use_container_width=True)


# Section heatmap supprimée car les colonnes nécessaires n'existent pas dans le CSV


st.subheader("Table detaillee (region)")
st.dataframe(
    region_filtered[["REGION", "NB_ETUDIANTS", "NB_INSCRITS_TOUS_GENRES", "POPULATION_INSEE", "PCT_FEMMES_ETU", "PCT_FEMMES_INSEE", "GAP_FEMMES_PCT"]]
    .sort_values("GAP_FEMMES_PCT", ascending=False)
    .reset_index(drop=True),
    use_container_width=True,
)

# Export for user
csv_export = region_filtered.to_csv(index=False).encode("utf-8")
st.download_button(
    label="Telecharger la table region filtree (CSV)",
    data=csv_export,
    file_name="dashboard_region_filtre.csv",
    mime="text/csv",
)

st.caption("Source unique : exports/fct_export_unifie.csv (généré par dbt)")
