#!/usr/bin/env python3
"""Plot derived KPI CSVs into experiment comparison charts."""

from __future__ import annotations

import argparse
import csv
import pathlib
from collections import defaultdict

import matplotlib.pyplot as plt


def load_rows(path: pathlib.Path) -> list[dict[str, str]]:
    with path.open("r", newline="", encoding="utf-8") as handle:
        return list(csv.DictReader(handle))


def safe_float(value: str) -> float | None:
    try:
        return float(value)
    except ValueError:
        return None


def slugify(value: str) -> str:
    return value.replace("/", "_").replace(" ", "_")


def main() -> int:
    parser = argparse.ArgumentParser(description="Plot KPI comparisons from CSV.")
    parser.add_argument("--input", default="results/summary/kpis.csv", help="KPI CSV file")
    parser.add_argument("--output-dir", default="results/plots", help="Directory for PNG plots")
    args = parser.parse_args()

    rows = load_rows(pathlib.Path(args.input))
    output_dir = pathlib.Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    grouped: dict[tuple[str, str], list[tuple[str, float, str]]] = defaultdict(list)
    for row in rows:
        value = safe_float(row["value"])
        if value is None:
            continue
        grouped[(row["service"], row["metric"])].append((row["config"], value, row["unit"]))

    for (service, metric), values in grouped.items():
        values.sort(key=lambda item: item[0])
        labels = [item[0] for item in values]
        y_values = [item[1] for item in values]
        unit = values[0][2]

        plt.figure(figsize=(9, 4.8))
        plt.bar(labels, y_values, color="#2A4D69")
        plt.title(f"{service} {metric}")
        plt.ylabel(unit)
        plt.xticks(rotation=20, ha="right")
        plt.tight_layout()
        plt.savefig(output_dir / f"{slugify(service)}_{slugify(metric)}.png", dpi=150)
        plt.close()

    print(f"Generated {len(grouped)} plot files in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
