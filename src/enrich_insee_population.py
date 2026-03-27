"""Enrichit le CSV INSEE avec les informations géographiques (region, DROM)"""
import csv
from pathlib import Path

# Mapping complet : code département -> (code région, nom région, is_drom, drom_group)
DEPT_TO_REGION = {
    # Île-de-France (11)
    "75": (11, "Île-de-France", 0, None),
    "77": (11, "Île-de-France", 0, None),
    "78": (11, "Île-de-France", 0, None),
    "91": (11, "Île-de-France", 0, None),
    "92": (11, "Île-de-France", 0, None),
    "93": (11, "Île-de-France", 0, None),
    "94": (11, "Île-de-France", 0, None),
    "95": (11, "Île-de-France", 0, None),
    # Centre-Val de Loire (24)
    "18": (24, "Centre-Val de Loire", 0, None),
    "28": (24, "Centre-Val de Loire", 0, None),
    "36": (24, "Centre-Val de Loire", 0, None),
    "37": (24, "Centre-Val de Loire", 0, None),
    "41": (24, "Centre-Val de Loire", 0, None),
    "45": (24, "Centre-Val de Loire", 0, None),
    # Bourgogne-Franche-Comté (27)
    "21": (27, "Bourgogne-Franche-Comté", 0, None),
    "58": (27, "Bourgogne-Franche-Comté", 0, None),
    "71": (27, "Bourgogne-Franche-Comté", 0, None),
    "89": (27, "Bourgogne-Franche-Comté", 0, None),
    "25": (27, "Bourgogne-Franche-Comté", 0, None),
    "39": (27, "Bourgogne-Franche-Comté", 0, None),
    "70": (27, "Bourgogne-Franche-Comté", 0, None),
    "90": (27, "Bourgogne-Franche-Comté", 0, None),
    # Normandie (28)
    "14": (28, "Normandie", 0, None),
    "27": (28, "Normandie", 0, None),
    "50": (28, "Normandie", 0, None),
    "61": (28, "Normandie", 0, None),
    "76": (28, "Normandie", 0, None),
    # Hauts-de-France (32)
    "02": (32, "Hauts-de-France", 0, None),
    "59": (32, "Hauts-de-France", 0, None),
    "60": (32, "Hauts-de-France", 0, None),
    "62": (32, "Hauts-de-France", 0, None),
    "80": (32, "Hauts-de-France", 0, None),
    # Grand Est (44)
    "08": (44, "Grand Est", 0, None),
    "10": (44, "Grand Est", 0, None),
    "51": (44, "Grand Est", 0, None),
    "52": (44, "Grand Est", 0, None),
    "54": (44, "Grand Est", 0, None),
    "55": (44, "Grand Est", 0, None),
    "57": (44, "Grand Est", 0, None),
    "67": (44, "Grand Est", 0, None),
    "68": (44, "Grand Est", 0, None),
    "88": (44, "Grand Est", 0, None),
    # Pays de la Loire (52)
    "44": (52, "Pays de la Loire", 0, None),
    "49": (52, "Pays de la Loire", 0, None),
    "53": (52, "Pays de la Loire", 0, None),
    "72": (52, "Pays de la Loire", 0, None),
    "85": (52, "Pays de la Loire", 0, None),
    # Bretagne (53)
    "22": (53, "Bretagne", 0, None),
    "29": (53, "Bretagne", 0, None),
    "35": (53, "Bretagne", 0, None),
    "56": (53, "Bretagne", 0, None),
    # Nouvelle-Aquitaine (75)
    "16": (75, "Nouvelle-Aquitaine", 0, None),
    "17": (75, "Nouvelle-Aquitaine", 0, None),
    "19": (75, "Nouvelle-Aquitaine", 0, None),
    "23": (75, "Nouvelle-Aquitaine", 0, None),
    "24": (75, "Nouvelle-Aquitaine", 0, None),
    "33": (75, "Nouvelle-Aquitaine", 0, None),
    "40": (75, "Nouvelle-Aquitaine", 0, None),
    "47": (75, "Nouvelle-Aquitaine", 0, None),
    "64": (75, "Nouvelle-Aquitaine", 0, None),
    "79": (75, "Nouvelle-Aquitaine", 0, None),
    "86": (75, "Nouvelle-Aquitaine", 0, None),
    "87": (75, "Nouvelle-Aquitaine", 0, None),
    # Occitanie (76)
    "09": (76, "Occitanie", 0, None),
    "11": (76, "Occitanie", 0, None),
    "12": (76, "Occitanie", 0, None),
    "30": (76, "Occitanie", 0, None),
    "31": (76, "Occitanie", 0, None),
    "32": (76, "Occitanie", 0, None),
    "34": (76, "Occitanie", 0, None),
    "46": (76, "Occitanie", 0, None),
    "48": (76, "Occitanie", 0, None),
    "65": (76, "Occitanie", 0, None),
    "66": (76, "Occitanie", 0, None),
    "81": (76, "Occitanie", 0, None),
    "82": (76, "Occitanie", 0, None),
    # Auvergne-Rhône-Alpes (84)
    "01": (84, "Auvergne-Rhône-Alpes", 0, None),
    "03": (84, "Auvergne-Rhône-Alpes", 0, None),
    "04": (84, "Auvergne-Rhône-Alpes", 0, None),
    "07": (84, "Auvergne-Rhône-Alpes", 0, None),
    "15": (84, "Auvergne-Rhône-Alpes", 0, None),
    "26": (84, "Auvergne-Rhône-Alpes", 0, None),
    "38": (84, "Auvergne-Rhône-Alpes", 0, None),
    "42": (84, "Auvergne-Rhône-Alpes", 0, None),
    "43": (84, "Auvergne-Rhône-Alpes", 0, None),
    "63": (84, "Auvergne-Rhône-Alpes", 0, None),
    "69": (84, "Auvergne-Rhône-Alpes", 0, None),
    "73": (84, "Auvergne-Rhône-Alpes", 0, None),
    "74": (84, "Auvergne-Rhône-Alpes", 0, None),
    # Provence-Alpes-Côte d'Azur (93)
    "04": (93, "Provence-Alpes-Côte d'Azur", 0, None),
    "05": (93, "Provence-Alpes-Côte d'Azur", 0, None),
    "06": (93, "Provence-Alpes-Côte d'Azur", 0, None),
    "13": (93, "Provence-Alpes-Côte d'Azur", 0, None),
    "83": (93, "Provence-Alpes-Côte d'Azur", 0, None),
    "84": (93, "Provence-Alpes-Côte d'Azur", 0, None),
    # Corse (94)
    "2A": (94, "Corse", 0, None),
    "2B": (94, "Corse", 0, None),
    # DROM - region_name standardisé à "DROM"
    "971": (971, "DROM", 1, "Guadeloupe"),
    "972": (972, "DROM", 1, "Martinique"),
    "973": (973, "DROM", 1, "Guyane"),
    "974": (974, "DROM", 1, "La Réunion"),
    "976": (976, "DROM", 1, "Mayotte"),
}

input_path = Path(__file__).with_name("insee_population_departements_wide_2022_2025.csv")
output_path = Path(__file__).with_name("insee_population_enrichi.csv")

# Lire le CSV et enrichir
rows_read = 0
rows_enriched = 0

with input_path.open("r", encoding="utf-8") as infile, output_path.open("w", encoding="utf-8", newline="") as outfile:
    reader = csv.DictReader(infile)
    fieldnames = reader.fieldnames + ["region_code", "region_name", "is_drom", "drom_group"]
    writer = csv.DictWriter(outfile, fieldnames=fieldnames)
    writer.writeheader()
    
    for row in reader:
        rows_read += 1
        dept_code = row["department_code"]
        
        if dept_code in DEPT_TO_REGION:
            region_code, region_name, is_drom, drom_group = DEPT_TO_REGION[dept_code]
            row["region_code"] = region_code
            row["region_name"] = region_name
            row["is_drom"] = is_drom
            row["drom_group"] = drom_group if drom_group else ""
            rows_enriched += 1
        else:
            print(f"⚠️  Département non trouvé: {dept_code}")
            row["region_code"] = ""
            row["region_name"] = ""
            row["is_drom"] = ""
            row["drom_group"] = ""
        
        writer.writerow(row)

print(f"\n✅ Enrichissement terminé:")
print(f"  Lignes lues: {rows_read}")
print(f"  Lignes enrichies: {rows_enriched}")
print(f"  Fichier de sortie: {output_path}")
