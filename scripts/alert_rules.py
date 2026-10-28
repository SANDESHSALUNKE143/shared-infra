"""Render Prometheus alert rules from the line, spike, and pause templates."""

from __future__ import annotations

import re
from pathlib import Path

try:
    from jinja2 import Environment, FileSystemLoader, StrictUndefined
except ImportError as error:
    raise SystemExit("Install python3-jinja2 to render alert rules.") from error

ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_DIR = ROOT / "prometheus" / "alert-templates"

DURATION = re.compile(r"^[1-9][0-9]*[smhd]$")
COUNT = re.compile(r"^[1-9][0-9]*$")
NUMBER = re.compile(r"^(?:0|[1-9][0-9]*)(?:\.[0-9]+)?$")

DEFAULTS = {
    "ALERT_TARGET_DOWN_FOR": "2m",
    "ALERT_QUEUE_DEPTH": "1000",
    "ALERT_QUEUE_FOR": "10m",
    "ALERT_DISK_FREE_RATIO": "0.15",
    "ALERT_DISK_FOR": "10m",
    "ALERT_ES_YELLOW_FOR": "5m",
    "ALERT_ES_RED_FOR": "1m",
    "ALERT_INDEX_PAUSE_FOR": "15m",
    "ALERT_POISON_SPIKE_MULTIPLIER": "5",
    "ALERT_POISON_SPIKE_FOR": "10m",
    "ALERT_POISON_SPIKE_WINDOW": "5m",
    "ALERT_POISON_SPIKE_BASELINE": "1h",
    "ALERT_POISON_SPIKE_MIN_RATE": "0.01",
}


def setting(values: dict[str, str], key: str, pattern: re.Pattern[str]) -> str:
    raw = values.get(key, "").strip() or DEFAULTS[key]
    if pattern.fullmatch(raw) is None:
        raise SystemExit(f"{key} must match {pattern.pattern}, got {raw!r}.")
    return raw


def promql(value: str) -> str:
    text = value.strip("\n")
    if "\n" not in text:
        return text
    body = "\n".join(f"          {line}" for line in text.splitlines())
    return f"|\n{body}"


def alert_context(values: dict[str, str]) -> dict[str, str]:
    queue_depth = setting(values, "ALERT_QUEUE_DEPTH", COUNT)
    disk_free = setting(values, "ALERT_DISK_FREE_RATIO", NUMBER)
    free = float(disk_free)
    if not 0 < free < 1:
        raise SystemExit(f"ALERT_DISK_FREE_RATIO must be between 0 and 1, got {disk_free!r}.")
    full_percent = round((1 - free) * 100)
    pause_for = setting(values, "ALERT_INDEX_PAUSE_FOR", DURATION)
    multiplier = setting(values, "ALERT_POISON_SPIKE_MULTIPLIER", NUMBER)
    return {
        "target_down_for": setting(values, "ALERT_TARGET_DOWN_FOR", DURATION),
        "target_down_summary": "{{ $labels.job }} on {{ $labels.instance }} is down",
        "queue_for": setting(values, "ALERT_QUEUE_FOR", DURATION),
        "queue_expr": f"log_queue_depth > {queue_depth}",
        "queue_summary": f"The application log queue has more than {queue_depth} messages",
        "disk_for": setting(values, "ALERT_DISK_FOR", DURATION),
        "disk_expr": (
            "(\n"
            '  node_filesystem_avail_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|aufs",mountpoint!~"/var/lib/docker.*"}\n'
            "  /\n"
            '  node_filesystem_size_bytes{fstype!~"tmpfs|overlay|squashfs|ramfs|aufs",mountpoint!~"/var/lib/docker.*"}\n'
            f") < {disk_free}"
        ),
        "disk_summary": f"Filesystem {{{{ $labels.mountpoint }}}} is over {full_percent} percent full",
        "es_yellow_for": setting(values, "ALERT_ES_YELLOW_FOR", DURATION),
        "es_red_for": setting(values, "ALERT_ES_RED_FOR", DURATION),
        "index_pause_for": pause_for,
        "index_pause_expr": f"log_queue_depth > 0 and rate(log_worker_indexed_total[{pause_for}]) == 0",
        "poison_window": setting(values, "ALERT_POISON_SPIKE_WINDOW", DURATION),
        "poison_baseline": setting(values, "ALERT_POISON_SPIKE_BASELINE", DURATION),
        "poison_multiplier": multiplier,
        "poison_min_rate": setting(values, "ALERT_POISON_SPIKE_MIN_RATE", NUMBER),
        "poison_for": setting(values, "ALERT_POISON_SPIKE_FOR", DURATION),
        "poison_summary": f"Poisoned log events are more than {multiplier} times the recent baseline",
    }


def render_alerts(values: dict[str, str], template_dir: Path = TEMPLATE_DIR) -> str:
    environment = Environment(
        loader=FileSystemLoader(template_dir),
        autoescape=False,
        undefined=StrictUndefined,
        keep_trailing_newline=True,
    )
    environment.filters["promql"] = promql
    return environment.get_template("alerts.yml.j2").render(**alert_context(values))
