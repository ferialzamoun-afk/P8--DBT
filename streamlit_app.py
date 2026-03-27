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
OUTPUTS_DIR = BASE_DIR / "outputs"

st.title("Dashboard P8 - Representativite Etudiants OC vs INSEE")
st.caption("Analyse des ecarts region, genre et age a partir des exports produits par dbt + Snowflake.")

try:
    df_region = load_csv(OUTPUTS_DIR / "pbi_region_repr.csv")
    df_women = load_csv(OUTPUTS_DIR / "pbi_women_oc_vs_insee.csv")
    df_trend = load_csv(OUTPUTS_DIR / "pbi_trend_etu_year_total.csv")
    df_age = load_csv(OUTPUTS_DIR / "pbi_repartition_age_oc.csv")
    df_heat = load_csv(OUTPUTS_DIR / "pbi_heat_region_gender.csv")
except FileNotFoundError as err:
    st.error(str(err))
    st.stop()

# Type normalization
if "YEAR_PATH_STARTED" in df_trend.columns:
    df_trend["YEAR_PATH_STARTED"] = pd.to_numeric(df_trend["YEAR_PATH_STARTED"], errors="coerce")
if "YEAR" in df_women.columns:
    df_women["YEAR"] = pd.to_numeric(df_women["YEAR"], errors="coerce")

for col in ["NB_ETUDIANTS", "value_oc", "total_oc", "value_insee", "total_insee", "part_f_oc", "part_f_insee"]:
    if col in df_women.columns:
        df_women[col] = pd.to_numeric(df_women[col], errors="coerce")
for col in ["NB_ETUDIANTS", "part_oc", "part_insee", "ecart_points"]:
    if col in df_region.columns:
        df_region[col] = pd.to_numeric(df_region[col], errors="coerce")
for col in ["NB_ETUDIANTS"]:
    if col in df_trend.columns:
        df_trend[col] = pd.to_numeric(df_trend[col], errors="coerce")
for col in ["NB_ETUDIANTS"]:
    if col in df_age.columns:
        df_age[col] = pd.to_numeric(df_age[col], errors="coerce")
for col in ["ecart_points"]:
    if col in df_heat.columns:
        df_heat[col] = pd.to_numeric(df_heat[col], errors="coerce")

# Sidebar filters
st.sidebar.header("Filtres")
available_years = sorted([int(y) for y in df_trend["YEAR_PATH_STARTED"].dropna().unique().tolist()])
default_years = available_years[-2:] if len(available_years) > 1 else available_years
selected_years = st.sidebar.multiselect(
    "Annees",
    options=available_years,
    default=default_years,
)

available_regions = sorted([r for r in df_region["REGION"].dropna().unique().tolist()])
selected_regions = st.sidebar.multiselect(
    "Regions",
    options=available_regions,
    default=available_regions,
)

# Filtered datasets
trend_filtered = df_trend.copy()
if selected_years:
    trend_filtered = trend_filtered[trend_filtered["YEAR_PATH_STARTED"].isin(selected_years)]

women_filtered = df_women.copy()
if selected_years:
    women_filtered = women_filtered[women_filtered["YEAR"].isin(selected_years)]

region_filtered = df_region.copy()
if selected_regions:
    region_filtered = region_filtered[region_filtered["REGION"].isin(selected_regions)]

heat_filtered = df_heat.copy()
if selected_regions:
    heat_filtered = heat_filtered[heat_filtered["REGION"].isin(selected_regions)]

# KPIs
kpi_total_students = trend_filtered["NB_ETUDIANTS"].sum(skipna=True)
kpi_latest_year = int(trend_filtered["YEAR_PATH_STARTED"].max()) if not trend_filtered.empty else None
kpi_latest_students = (
    trend_filtered.loc[trend_filtered["YEAR_PATH_STARTED"] == kpi_latest_year, "NB_ETUDIANTS"].sum(skipna=True)
    if kpi_latest_year is not None
    else 0
)

if not women_filtered.empty:
    women_filtered = women_filtered.copy()
    women_filtered["gap_f_points"] = (women_filtered["part_f_oc"] - women_filtered["part_f_insee"]) * 100
    kpi_gap_women = women_filtered["gap_f_points"].mean(skipna=True)
else:
    kpi_gap_women = 0.0

kpi_region_over = 0
if "surrepresentation" in region_filtered.columns:
    kpi_region_over = (region_filtered["surrepresentation"] == "Sur-representee").sum()

c1, c2, c3, c4 = st.columns(4)
c1.metric("Etudiants OC (selection)", format_int(kpi_total_students))
c2.metric("Derniere annee", str(kpi_latest_year) if kpi_latest_year else "n/a")
c3.metric("Etudiants derniere annee", format_int(kpi_latest_students))
c4.metric("Ecart moyen femmes OC vs INSEE", format_pct(kpi_gap_women))

st.divider()

# Charts row 1
left1, right1 = st.columns(2)

with left1:
    st.subheader("Tendance annuelle des etudiants OC")
    chart_trend = px.line(
        trend_filtered.sort_values("YEAR_PATH_STARTED"),
        x="YEAR_PATH_STARTED",
        y="NB_ETUDIANTS",
        markers=True,
        labels={"YEAR_PATH_STARTED": "Annee", "NB_ETUDIANTS": "Nb etudiants"},
        title="Evolution des effectifs OC",
    )
    chart_trend.update_layout(height=420)
    st.plotly_chart(chart_trend, use_container_width=True)

with right1:
    st.subheader("Part des femmes: OC vs INSEE")
    women_plot = women_filtered.copy()
    if not women_plot.empty:
        women_plot["part_f_oc_pct"] = women_plot["part_f_oc"] * 100
        women_plot["part_f_insee_pct"] = women_plot["part_f_insee"] * 100
        women_long = women_plot.melt(
            id_vars=["YEAR"],
            value_vars=["part_f_oc_pct", "part_f_insee_pct"],
            var_name="Serie",
            value_name="Pct",
        )
        women_long["Serie"] = women_long["Serie"].map(
            {"part_f_oc_pct": "Femmes OC", "part_f_insee_pct": "Femmes INSEE"}
        )
        chart_women = px.line(
            women_long.sort_values("YEAR"),
            x="YEAR",
            y="Pct",
            color="Serie",
            markers=True,
            labels={"YEAR": "Annee", "Pct": "% femmes"},
            title="Comparaison de la representation feminine",
        )
        chart_women.update_layout(height=420)
        st.plotly_chart(chart_women, use_container_width=True)
    else:
        st.info("Pas de donnees disponibles pour la selection courante.")

# Charts row 2
left2, right2 = st.columns(2)

with left2:
    st.subheader("Repartition OC par tranche age")
    age_plot = df_age.sort_values("NB_ETUDIANTS", ascending=True)
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
    st.subheader("Sur/sous representation regionale")
    region_plot = region_filtered.sort_values("ecart_points", ascending=True)
    chart_region = px.bar(
        region_plot,
        x="ecart_points",
        y="REGION",
        color="surrepresentation",
        orientation="h",
        labels={"ecart_points": "Ecart (points)", "REGION": "Region", "surrepresentation": "Statut"},
        title="Ecart entre part OC et part INSEE",
    )
    chart_region.update_layout(height=420)
    st.plotly_chart(chart_region, use_container_width=True)

st.subheader("Heatmap des ecarts par region et genre")
if not heat_filtered.empty:
    heat_pivot = heat_filtered.pivot_table(
        index="REGION",
        columns="GENDER",
        values="ecart_points",
        aggfunc="mean",
    )
    chart_heat = px.imshow(
        heat_pivot,
        aspect="auto",
        labels={"x": "Genre", "y": "Region", "color": "Ecart points"},
        title="Ecart OC vs INSEE (points)",
        color_continuous_scale="RdBu",
    )
    chart_heat.update_layout(height=500)
    st.plotly_chart(chart_heat, use_container_width=True)
else:
    st.info("Pas de donnees heatmap disponibles pour la selection courante.")

st.subheader("Table detaillee (region)")
st.dataframe(
    region_filtered[["REGION", "NB_ETUDIANTS", "part_oc", "part_insee", "ecart_points", "surrepresentation"]]
    .sort_values("ecart_points", ascending=False)
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

st.caption("Sources: outputs/pbi_region_repr.csv, outputs/pbi_women_oc_vs_insee.csv, outputs/pbi_trend_etu_year_total.csv, outputs/pbi_repartition_age_oc.csv, outputs/pbi_heat_region_gender.csv")
