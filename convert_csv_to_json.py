#!/usr/bin/env python3
"""One-time script to convert units CSV files to enriched JSON format."""

import csv
import json
import os

ROOT = os.path.dirname(os.path.abspath(__file__))
UNITS_DIR = os.path.join(ROOT, "units")


def convert_unit_conversions():
    csv_path = os.path.join(UNITS_DIR, "unit_conversions.csv")
    json_path = os.path.join(UNITS_DIR, "unit_conversions.json")

    rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "conceptId1": int(row["omop_concept_id_1"]),
                "conceptName1": "",
                "unitConceptId1": int(row["unit_concept_id_1"]),
                "unitName1": "",
                "conversionFactor": float(row["conversion_factor"]),
                "conceptId2": int(row["omop_concept_id_2"]),
                "conceptName2": "",
                "unitConceptId2": int(row["unit_concept_id_2"]),
                "unitName2": ""
            })

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)

    print(f"Converted {len(rows)} unit conversions -> {json_path}")


def convert_recommended_units():
    csv_path = os.path.join(UNITS_DIR, "recommended_units.csv")
    json_path = os.path.join(UNITS_DIR, "recommended_units.json")

    rows = []
    with open(csv_path, "r", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            rows.append({
                "conceptId": int(row["concept_id"]),
                "conceptName": "",
                "conceptCode": "",
                "vocabularyId": "",
                "domainId": "",
                "recommendedUnitConceptId": int(row["recommended_unit_concept_id"]),
                "recommendedUnitName": "",
                "recommendedUnitCode": "",
                "recommendedUnitVocabularyId": ""
            })

    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(rows, f, ensure_ascii=False, indent=2)

    print(f"Converted {len(rows)} recommended units -> {json_path}")


if __name__ == "__main__":
    convert_unit_conversions()
    convert_recommended_units()
