#!/usr/bin/env python3
"""Parse OMNeT++ scalar/vector files and derive experiment KPIs."""

from __future__ import annotations

import argparse
import csv
import math
import pathlib
import re
import shlex
from dataclasses import dataclass, field


@dataclass
class RunContext:
    run_id: str = ""
    attrs: dict[str, str] = field(default_factory=dict)


@dataclass
class VectorSeries:
    source_file: str
    run_id: str
    config: str
    module: str
    metric: str
    values: list[float] = field(default_factory=list)


def parse_scalar_file(path: pathlib.Path) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    ctx = RunContext()

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            parts = shlex.split(line)
            record_type = parts[0]

            if record_type == "run" and len(parts) >= 2:
                ctx = RunContext(run_id=parts[1], attrs={})
                continue

            if record_type == "attr" and len(parts) >= 3:
                ctx.attrs[parts[1]] = " ".join(parts[2:])
                continue

            if record_type != "scalar" or len(parts) < 4:
                continue

            rows.append(
                {
                    "source_file": str(path),
                    "run_id": ctx.run_id,
                    "config": ctx.attrs.get("configname", path.stem),
                    "module": parts[1],
                    "metric": parts[2],
                    "value": parts[3],
                }
            )

    return rows


def parse_vector_file(path: pathlib.Path) -> list[VectorSeries]:
    ctx = RunContext()
    vectors: dict[str, VectorSeries] = {}

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line or line.startswith("#"):
                continue

            parts = shlex.split(line)
            record_type = parts[0]

            if record_type == "run" and len(parts) >= 2:
                ctx = RunContext(run_id=parts[1], attrs={})
                continue

            if record_type == "attr" and len(parts) >= 3:
                ctx.attrs[parts[1]] = " ".join(parts[2:])
                continue

            if record_type == "vector" and len(parts) >= 4:
                vector_id = parts[1]
                vectors[vector_id] = VectorSeries(
                    source_file=str(path),
                    run_id=ctx.run_id,
                    config=ctx.attrs.get("configname", path.stem),
                    module=parts[2],
                    metric=parts[3],
                )
                continue

            if not record_type.isdigit():
                continue

            vector = vectors.get(record_type)
            if vector is None or len(parts) < 2:
                continue

            try:
                value = float(parts[-1])
            except ValueError:
                continue
            vector.values.append(value)

    return list(vectors.values())


def write_csv(path: pathlib.Path, rows: list[dict[str, object]], columns: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def safe_float(value: str) -> float | None:
    try:
        parsed = float(value)
    except ValueError:
        return None
    if not math.isfinite(parsed):
        return None
    return parsed


def module_matches(pattern: str, module: str) -> bool:
    return re.fullmatch(pattern, module) is not None


def scalar_mean(
    scalar_rows: list[dict[str, str]],
    config: str,
    module_pattern: str,
    metric_substring: str,
    metric_suffix: str | None = None,
) -> float | None:
    values: list[float] = []
    for row in scalar_rows:
        if row["config"] != config:
            continue
        if not module_matches(module_pattern, row["module"]):
            continue
        if metric_substring not in row["metric"]:
            continue
        if metric_suffix and not row["metric"].endswith(metric_suffix):
            continue
        value = safe_float(row["value"])
        if value is not None:
            values.append(value)

    if not values:
        return None
    return sum(values) / len(values)


def vector_count_total(
    vector_rows: list[VectorSeries],
    config: str,
    module_pattern: str,
    metric_substring: str,
) -> int:
    total = 0
    for row in vector_rows:
        if row.config != config:
            continue
        if not module_matches(module_pattern, row.module):
            continue
        if metric_substring not in row.metric:
            continue
        total += len(row.values)
    return total


def serving_cell_handover_stats(vector_rows: list[VectorSeries], config: str) -> tuple[int, float, int]:
    counts: list[int] = []
    for row in vector_rows:
        if row.config != config:
            continue
        if not module_matches(r"(?:.*\.)?car\[\d+\]\.cellularNic\.nrPhy", row.module):
            continue
        if "servingCell" not in row.metric:
            continue
        if len(row.values) < 2:
            counts.append(0)
            continue

        handovers = 0
        last = row.values[0]
        for value in row.values[1:]:
            if value != last:
                handovers += 1
                last = value
        counts.append(handovers)

    if not counts:
        return (0, 0.0, 0)
    return (sum(counts), sum(counts) / len(counts), len(counts))


def derive_kpis(
    scalar_rows: list[dict[str, str]],
    vector_rows: list[VectorSeries],
) -> list[dict[str, object]]:
    configs = sorted({row["config"] for row in scalar_rows} | {row.config for row in vector_rows})
    kpis: list[dict[str, object]] = []

    def add(config: str, service: str, metric: str, value: float | int | None, unit: str) -> None:
        if value is None:
            return
        kpis.append(
            {
                "config": config,
                "service": service,
                "metric": metric,
                "value": value,
                "unit": unit,
            }
        )

    for config in configs:
        mec_app_pattern = r"(?:.*\.)?car\[\d+\]\.app\[\d+\]"

        safety_thr = scalar_mean(
            scalar_rows,
            config,
            r"(?:.*\.)?edgeServer\.app\[\d+\]",
            "cbrReceivedThroughput",
            ":mean",
        )
        safety_delay = scalar_mean(
            scalar_rows,
            config,
            r"(?:.*\.)?edgeServer\.app\[\d+\]",
            "cbrFrameDelay",
            ":mean",
        )
        safety_sent = vector_count_total(vector_rows, config, r"(?:.*\.)?car\[\d+\]\.app\[0\]", "cbrSentPkt")
        safety_recv = vector_count_total(vector_rows, config, r"(?:.*\.)?edgeServer\.app\[\d+\]", "cbrRcvdPkt")
        safety_pdr = (safety_recv / safety_sent) if safety_sent else None

        telemetry_thr = scalar_mean(
            scalar_rows,
            config,
            r"(?:.*\.)?cloudServer\.app\[\d+\]",
            "cbrReceivedThroughput",
            ":mean",
        )
        telemetry_delay = scalar_mean(
            scalar_rows,
            config,
            r"(?:.*\.)?cloudServer\.app\[\d+\]",
            "cbrFrameDelay",
            ":mean",
        )
        telemetry_sent = vector_count_total(vector_rows, config, r"(?:.*\.)?car\[\d+\]\.app\[1\]", "cbrSentPkt")
        telemetry_recv = vector_count_total(vector_rows, config, r"(?:.*\.)?cloudServer\.app\[\d+\]", "cbrRcvdPkt")
        telemetry_pdr = (telemetry_recv / telemetry_sent) if telemetry_sent else None

        downlink_delay = scalar_mean(
            scalar_rows,
            config,
            r"(?:.*\.)?car\[\d+\]\.app\[2\]",
            "burstPktDelay",
            ":mean",
        )
        downlink_sent = vector_count_total(vector_rows, config, r"(?:.*\.)?videoServer\.app\[\d+\]", "burstSentPkt")
        downlink_recv = vector_count_total(vector_rows, config, r"(?:.*\.)?car\[\d+\]\.app\[2\]", "burstRcvdPkt")
        downlink_pdr = (downlink_recv / downlink_sent) if downlink_sent else None

        mec_response_time = scalar_mean(
            scalar_rows,
            config,
            mec_app_pattern,
            "responseTime",
            ":mean",
        )
        mec_processing_time = scalar_mean(
            scalar_rows,
            config,
            mec_app_pattern,
            "processingTime",
            ":mean",
        )
        mec_service_time = scalar_mean(
            scalar_rows,
            config,
            mec_app_pattern,
            "serviceResponseTime",
            ":mean",
        )
        mec_uplink_time = scalar_mean(
            scalar_rows,
            config,
            mec_app_pattern,
            "upLinkTime",
            ":mean",
        )
        mec_downlink_time = scalar_mean(
            scalar_rows,
            config,
            mec_app_pattern,
            "downLinkTime",
            ":mean",
        )
        mec_completed_requests = vector_count_total(
            vector_rows,
            config,
            mec_app_pattern,
            "responseTime",
        )

        handover_total, handover_mean, vehicles_seen = serving_cell_handover_stats(vector_rows, config)

        add(config, "safety_ul", "throughput", safety_thr, "Bps")
        add(config, "safety_ul", "delay", safety_delay, "s")
        add(config, "safety_ul", "delivery_ratio", safety_pdr, "ratio")

        add(config, "telemetry_ul", "throughput", telemetry_thr, "Bps")
        add(config, "telemetry_ul", "delay", telemetry_delay, "s")
        add(config, "telemetry_ul", "delivery_ratio", telemetry_pdr, "ratio")

        add(config, "burst_dl", "delay", downlink_delay, "s")
        add(config, "burst_dl", "delivery_ratio", downlink_pdr, "ratio")

        add(config, "mec_rr", "response_time", mec_response_time, "s")
        add(config, "mec_rr", "processing_time", mec_processing_time, "s")
        add(config, "mec_rr", "service_response_time", mec_service_time, "s")
        add(config, "mec_rr", "uplink_time", mec_uplink_time, "s")
        add(config, "mec_rr", "downlink_time", mec_downlink_time, "s")
        add(config, "mec_rr", "completed_requests", mec_completed_requests, "count")

        add(config, "mobility", "handover_total", handover_total, "count")
        add(config, "mobility", "handover_mean_per_vehicle", handover_mean, "count")
        add(config, "mobility", "vehicles_seen", vehicles_seen, "count")

    return kpis


def vector_summary_rows(vector_rows: list[VectorSeries]) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for row in vector_rows:
        change_count = 0
        if row.values:
            last = row.values[0]
            for value in row.values[1:]:
                if value != last:
                    change_count += 1
                    last = value
        rows.append(
            {
                "source_file": row.source_file,
                "run_id": row.run_id,
                "config": row.config,
                "module": row.module,
                "metric": row.metric,
                "sample_count": len(row.values),
                "change_count": change_count,
            }
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Parse OMNeT++ scalar/vector files and derive KPIs.")
    parser.add_argument("--input-dir", default="results/raw", help="Directory tree containing result files")
    parser.add_argument(
        "--config",
        action="append",
        default=[],
        help="Restrict parsing outputs to selected OMNeT++ config names. Repeat as needed.",
    )
    parser.add_argument("--output", default="results/summary/scalars.csv", help="Raw scalar CSV output")
    parser.add_argument(
        "--vector-summary-output",
        default="results/summary/vector_summary.csv",
        help="Vector summary CSV output",
    )
    parser.add_argument("--kpi-output", default="results/summary/kpis.csv", help="Derived KPI CSV output")
    args = parser.parse_args()

    input_dir = pathlib.Path(args.input_dir)
    scalar_files = sorted(input_dir.rglob("*.sca"))
    vector_files = sorted(input_dir.rglob("*.vec"))

    scalar_rows: list[dict[str, str]] = []
    for scalar_file in scalar_files:
        scalar_rows.extend(parse_scalar_file(scalar_file))

    vector_rows: list[VectorSeries] = []
    for vector_file in vector_files:
        vector_rows.extend(parse_vector_file(vector_file))

    if args.config:
        selected_configs = set(args.config)
        scalar_rows = [row for row in scalar_rows if row["config"] in selected_configs]
        vector_rows = [row for row in vector_rows if row.config in selected_configs]

    write_csv(
        pathlib.Path(args.output),
        scalar_rows,
        ["source_file", "run_id", "config", "module", "metric", "value"],
    )

    vector_summary = vector_summary_rows(vector_rows)
    write_csv(
        pathlib.Path(args.vector_summary_output),
        vector_summary,
        ["source_file", "run_id", "config", "module", "metric", "sample_count", "change_count"],
    )

    kpis = derive_kpis(scalar_rows, vector_rows)
    write_csv(pathlib.Path(args.kpi_output), kpis, ["config", "service", "metric", "value", "unit"])

    print(f"Parsed {len(scalar_files)} scalar files and {len(vector_files)} vector files")
    print(f"Wrote {len(scalar_rows)} scalar rows to {args.output}")
    print(f"Wrote {len(vector_summary)} vector summary rows to {args.vector_summary_output}")
    print(f"Wrote {len(kpis)} KPI rows to {args.kpi_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
