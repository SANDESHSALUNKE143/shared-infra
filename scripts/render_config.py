"""Fill generated config files from .env before Compose starts."""

from __future__ import annotations

import base64
from pathlib import Path

from alert_rules import render_alerts
from export_env import parse_env

ROOT = Path(__file__).resolve().parents[1]


def require(values: dict[str, str], key: str) -> str:
    value = values.get(key, "").strip()
    if not value:
        raise SystemExit(f"{key} is empty in .env")
    return value


def write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")
    path.chmod(0o644)


def main() -> None:
    env_path = ROOT / ".env"
    if not env_path.is_file():
        raise SystemExit("Missing .env. Run scripts/init-env.sh first.")
    values = parse_env(env_path.read_text(encoding="utf-8"))

    public = values.get("LANGFUSE_INIT_PROJECT_PUBLIC_KEY", "").strip()
    secret = values.get("LANGFUSE_INIT_PROJECT_SECRET_KEY", "").strip()
    if public and secret:
        token = base64.b64encode(f"{public}:{secret}".encode("utf-8")).decode("ascii")
        header = f"Basic {token}"
        values["LANGFUSE_OTLP_AUTH_HEADER"] = header
        lines = []
        seen = False
        for raw in env_path.read_text(encoding="utf-8").splitlines():
            if raw.startswith("LANGFUSE_OTLP_AUTH_HEADER="):
                lines.append(f"LANGFUSE_OTLP_AUTH_HEADER='{header}'")
                seen = True
            else:
                lines.append(raw)
        if not seen:
            lines.append(f"LANGFUSE_OTLP_AUTH_HEADER='{header}'")
        env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        env_path.chmod(0o600)

    env_name = require(values, "ENV_NAME")
    require(values, "PUBLIC_HOST")
    if values["PUBLIC_HOST"].startswith("http://") or values["PUBLIC_HOST"].startswith("https://"):
        raise SystemExit("PUBLIC_HOST must be a hostname or IP, without a scheme.")

    prometheus = (ROOT / "prometheus" / "prometheus.yml.tpl").read_text(encoding="utf-8")
    write(ROOT / "prometheus" / "prometheus.yml", prometheus.replace("__ENV_NAME__", env_name))
    write(ROOT / "prometheus" / "alerts.yml", render_alerts(values))

    datasources = (ROOT / "grafana" / "provisioning" / "datasources" / "datasources.yml.tpl").read_text(
        encoding="utf-8"
    )
    write(
        ROOT / "grafana" / "provisioning" / "datasources" / "datasources.yml",
        datasources.replace("__LOGS_READER_PASSWORD__", require(values, "LOGS_READER_PASSWORD")),
    )

    webhook = values.get("ALERT_WEBHOOK_URL", "").strip()
    webhook_yaml = ""
    if webhook:
        escaped = webhook.replace("\\", "\\\\").replace('"', '\\"')
        webhook_yaml = (
            "    webhook_configs:\n"
            f'      - url: "{escaped}"\n'
            "        send_resolved: true\n"
        )
    alertmanager = (ROOT / "alertmanager" / "alertmanager.yml.tpl").read_text(encoding="utf-8")
    write(
        ROOT / "alertmanager" / "alertmanager.yml",
        alertmanager.replace("__WEBHOOK__\n", webhook_yaml),
    )

    retention = values.get("LOKI_RETENTION_PERIOD", "168h").strip() or "168h"
    loki = (ROOT / "loki" / "loki.yml.tpl").read_text(encoding="utf-8")
    write(ROOT / "loki" / "loki.yml", loki.replace("__LOKI_RETENTION_PERIOD__", retention))


if __name__ == "__main__":
    main()
