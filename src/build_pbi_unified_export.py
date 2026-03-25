from __future__ import annotations

from pathlib import Path
import pandas as pd


BASE = Path(__file__).resolve().parents[1]
OUT = BASE / "outputs"


def load_csv(name: str) -> pd.DataFrame:
    path = OUT / name
    if not path.exists():
        return pd.DataFrame()
    return pd.read_csv(path)


def as_int_or_na(value):
    try:
        if pd.isna(value):
            return pd.NA
        return int(value)
    except Exception:
        return pd.NA


def add_rows(df: pd.DataFrame, page: str, visual: str, metric: str, source: str, unit: str,
             x_col: str, x_value_col: str, y_value_col: str,
             year_col: str | None = None, region_col: str | None = None,
             gender_col: str | None = None, age_col: str | None = None,
             series_col: str | None = None) -> pd.DataFrame:
    if df.empty:
        return pd.DataFrame()

    out = pd.DataFrame({
        "page": page,
        "visual": visual,
        "metric": metric,
        "source": source,
        "unit": unit,
        "x_field": x_col,
        "x_value": df[x_value_col].astype(str),
        "value": pd.to_numeric(df[y_value_col], errors="coerce"),
    })

    out["year"] = pd.NA
    if year_col and year_col in df.columns:
        out["year"] = df[year_col].map(as_int_or_na)

    out["region"] = pd.NA
    if region_col and region_col in df.columns:
        out["region"] = df[region_col].astype(str)

    out["gender"] = pd.NA
    if gender_col and gender_col in df.columns:
        out["gender"] = df[gender_col].astype(str)

    out["age_group"] = pd.NA
    if age_col and age_col in df.columns:
        out["age_group"] = df[age_col].astype(str)

    out["series"] = metric
    if series_col and series_col in df.columns:
        out["series"] = df[series_col].astype(str)

    return out[[
        "page", "visual", "metric", "series", "source", "unit",
        "x_field", "x_value", "year", "region", "gender", "age_group", "value"
    ]]


def build_unified() -> pd.DataFrame:
    frames: list[pd.DataFrame] = []

    trend_total = load_csv("pbi_trend_etu_year_total.csv")
    frames.append(
        add_rows(
            trend_total,
            page="Synthese",
            visual="Evolution nombre etudiants OC",
            metric="Nombre etudiants",
            source="OC",
            unit="effectif",
            x_col="Annee",
            x_value_col="YEAR_PATH_STARTED",
            y_value_col="NB_ETUDIANTS",
            year_col="YEAR_PATH_STARTED",
        )
    )

    women = load_csv("pbi_women_oc_vs_insee.csv")
    if not women.empty:
        women_oc = women.copy()
        women_oc["series"] = "Part femmes OC"
        frames.append(
            add_rows(
                women_oc,
                page="Synthese",
                visual="Evolution repartition femmes OC vs INSEE",
                metric="Part femmes",
                source="OC",
                unit="ratio",
                x_col="Annee",
                x_value_col="YEAR",
                y_value_col="part_f_oc",
                year_col="YEAR",
                gender_col="GENDER",
                series_col="series",
            )
        )

        women_insee = women.copy()
        women_insee["series"] = "Part femmes INSEE"
        frames.append(
            add_rows(
                women_insee,
                page="Synthese",
                visual="Evolution repartition femmes OC vs INSEE",
                metric="Part femmes",
                source="INSEE",
                unit="ratio",
                x_col="Annee",
                x_value_col="YEAR",
                y_value_col="part_f_insee",
                year_col="YEAR",
                gender_col="GENDER",
                series_col="series",
            )
        )

        women_gap = women.copy()
        women_gap["gap_points"] = (women_gap["part_f_oc"] - women_gap["part_f_insee"]) * 100
        women_gap["series"] = "Ecart femmes OC vs INSEE"
        frames.append(
            add_rows(
                women_gap,
                page="Synthese",
                visual="Ecart femmes OC vs INSEE par annee",
                metric="Ecart femmes",
                source="OC_vs_INSEE",
                unit="points",
                x_col="Annee",
                x_value_col="YEAR",
                y_value_col="gap_points",
                year_col="YEAR",
                gender_col="GENDER",
                series_col="series",
            )
        )

    genre = load_csv("pbi_repartition_genre_oc_all.csv")
    frames.append(
        add_rows(
            genre,
            page="Genre et age",
            visual="Repartition genre OC",
            metric="Nombre etudiants",
            source="OC",
            unit="effectif",
            x_col="Genre",
            x_value_col="GENDER",
            y_value_col="NB_ETUDIANTS",
            gender_col="GENDER",
        )
    )

    age = load_csv("pbi_repartition_age_oc.csv")
    frames.append(
        add_rows(
            age,
            page="Genre et age",
            visual="Repartition age OC",
            metric="Nombre etudiants",
            source="OC",
            unit="effectif",
            x_col="Tranche age",
            x_value_col="AGE_GROUP",
            y_value_col="NB_ETUDIANTS",
            age_col="AGE_GROUP",
        )
    )

    trend_age = load_csv("pbi_trend_etu_age_year.csv")
    if not trend_age.empty:
        trend_age = trend_age.copy()
        trend_age["series"] = trend_age["AGE_GROUP"].astype(str)
        frames.append(
            add_rows(
                trend_age,
                page="Genre et age",
                visual="Evolution etudiants par age et annee",
                metric="Nombre etudiants",
                source="OC",
                unit="effectif",
                x_col="Annee",
                x_value_col="YEAR_PATH_STARTED",
                y_value_col="NB_ETUDIANTS",
                year_col="YEAR_PATH_STARTED",
                age_col="AGE_GROUP",
                series_col="series",
            )
        )

    region = load_csv("pbi_repartition_region_oc.csv")
    frames.append(
        add_rows(
            region,
            page="Territoires",
            visual="Repartition region OC",
            metric="Nombre etudiants",
            source="OC",
            unit="effectif",
            x_col="Region",
            x_value_col="REGION",
            y_value_col="NB_ETUDIANTS",
            region_col="REGION",
        )
    )

    repr_df = load_csv("pbi_region_repr.csv")
    if not repr_df.empty:
        repr_part = repr_df.copy()
        repr_part["series"] = "Part OC"
        frames.append(
            add_rows(
                repr_part,
                page="Territoires",
                visual="Part OC vs INSEE par region",
                metric="Part regionale",
                source="OC",
                unit="ratio",
                x_col="Region",
                x_value_col="REGION",
                y_value_col="part_oc",
                region_col="REGION",
                series_col="series",
            )
        )

        repr_insee = repr_df.copy()
        repr_insee["series"] = "Part INSEE"
        frames.append(
            add_rows(
                repr_insee,
                page="Territoires",
                visual="Part OC vs INSEE par region",
                metric="Part regionale",
                source="INSEE",
                unit="ratio",
                x_col="Region",
                x_value_col="REGION",
                y_value_col="part_insee",
                region_col="REGION",
                series_col="series",
            )
        )

        repr_gap = repr_df.copy()
        repr_gap["series"] = "Ecart OC vs INSEE"
        frames.append(
            add_rows(
                repr_gap,
                page="Territoires",
                visual="Ecart OC vs INSEE par region",
                metric="Ecart regional",
                source="OC_vs_INSEE",
                unit="points",
                x_col="Region",
                x_value_col="REGION",
                y_value_col="ecart_points",
                region_col="REGION",
                series_col="series",
            )
        )

    heat = load_csv("pbi_heat_region_gender.csv")
    frames.append(
        add_rows(
            heat,
            page="Territoires",
            visual="Heatmap ecart region genre",
            metric="Ecart regional genre",
            source="OC_vs_INSEE",
            unit="points",
            x_col="Region",
            x_value_col="REGION",
            y_value_col="ecart_points",
            region_col="REGION",
            gender_col="GENDER",
            series_col="GENDER",
        )
    )

    final = pd.concat([f for f in frames if not f.empty], ignore_index=True)
    final["year"] = pd.array(final["year"], dtype="Int64")
    final["value"] = pd.to_numeric(final["value"], errors="coerce")

    final = final.sort_values(
        ["page", "visual", "metric", "series", "year", "region", "gender", "age_group"],
        na_position="last",
    ).reset_index(drop=True)

    return final


def write_outputs(df: pd.DataFrame) -> None:
    out_csv = OUT / "pbi_dashboard_unifie.csv"
    out_pbi = OUT / "pbi_dashboard_unifie_pbi.csv"

    df.to_csv(out_csv, index=False, encoding="utf-8")
    df.to_csv(out_pbi, index=False, encoding="utf-8-sig", sep=";", decimal=",")

    print(f"OK: {out_csv} ({len(df)} lignes)")
    print(f"OK: {out_pbi} ({len(df)} lignes)")


if __name__ == "__main__":
    unified = build_unified()
    if unified.empty:
        raise SystemExit("Aucune donnee disponible pour produire le CSV unifie.")
    write_outputs(unified)
