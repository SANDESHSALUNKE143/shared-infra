"""Enqueue one sample event and delete it after Elasticsearch has the document."""

from __future__ import annotations

import json
import os
import sys
import time
from datetime import datetime, timezone

from elasticsearch import Elasticsearch


def main() -> None:
    connection = os.environ.get("AZURE_STORAGE_CONNECTION_STRING", "").strip()
    if not connection:
        raise SystemExit("AZURE_STORAGE_CONNECTION_STRING is empty.")
    from azure.storage.queue import QueueClient

    queue_name = os.environ.get("AZURE_QUEUE_NAME", "app-logs").strip() or "app-logs"
    queue = QueueClient.from_connection_string(connection, queue_name)
    now = datetime.now(timezone.utc)
    timestamp = now.strftime("%Y-%m-%dT%H:%M:%S.") + f"{now.microsecond // 1000:03d}Z"
    event = {
        "schema_version": 1,
        "timestamp": timestamp,
        "level": "INFO",
        "message": "shared-infra check",
        "application": "shared-infra",
        "environment": "check",
    }
    sent = queue.send_message(json.dumps(event, separators=(",", ":")))
    es = Elasticsearch(
        os.environ.get("ELASTICSEARCH_URL", "http://elasticsearch:9200"),
        basic_auth=(
            os.environ.get("ELASTICSEARCH_USERNAME", "logs_writer"),
            os.environ["ELASTICSEARCH_PASSWORD"],
        ),
    )
    index = "logs-check"
    for _attempt in range(60):
        if es.exists(index=index, id=sent.id):
            es.delete(index=index, id=sent.id)
            print("ok log round-trip")
            return
        time.sleep(2)
    raise SystemExit(f"failed log round-trip; document {sent.id} did not appear in {index}")


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception as exc:
        print(f"failed log round-trip: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
