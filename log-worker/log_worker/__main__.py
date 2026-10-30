"""Long-running consumer. Serves /health and /metrics on port 8080."""

from __future__ import annotations

import logging
import os
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

from elasticsearch import Elasticsearch
from elasticsearch.helpers import bulk
from prometheus_client import Counter, Gauge, generate_latest

from log_worker.worker import POISON_AFTER, HandleResult, Prepared, QueueMessage, handle_messages

LOG = logging.getLogger("log-worker")
QUEUE_DEPTH = Gauge("log_queue_depth", "Approximate messages waiting in the application log queue")
INDEXED = Counter("log_worker_indexed_total", "Events indexed into Elasticsearch")
POISONED = Counter("log_worker_poison_total", "Events moved to the poison queue")

STATE = {"healthy": False}


def elasticsearch_reachable(client: Elasticsearch) -> bool:
    """The writer role cannot call cluster APIs, so HEAD / is 403. 401 is a bad password."""
    try:
        client.perform_request("HEAD", "/")
        return True
    except Exception as exc:
        status = getattr(exc, "status_code", None)
        if status is None:
            status = getattr(getattr(exc, "meta", None), "status", None)
        return status == 403


def _int_env(name: str, default: int) -> int:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return default
    return int(raw)


def receive_batch(queue: Any, size: int, visibility: int, wait_seconds: float) -> list[Any]:
    """Collect up to ``size`` messages, waiting at most ``wait_seconds`` to fill the batch."""
    found: list[Any] = []
    deadline = time.monotonic() + wait_seconds
    while len(found) < size:
        remaining = size - len(found)
        page = queue.receive_messages(messages_per_page=remaining, visibility_timeout=visibility)
        got: list[Any] = []
        for chunk in page.by_page():
            got.extend(chunk)
            break
        if not got:
            if time.monotonic() >= deadline:
                break
            time.sleep(min(0.5, max(0.0, deadline - time.monotonic())))
            continue
        found.extend(got)
        if time.monotonic() >= deadline:
            break
    return found[:size]


def as_message(raw: Any) -> QueueMessage:
    return QueueMessage(
        id=raw.id,
        content=raw.content,
        dequeue_count=int(raw.dequeue_count or 1),
        pop_receipt=raw.pop_receipt,
    )


def failed_ids(errors: list[dict[str, Any]]) -> set[str]:
    failed: set[str] = set()
    for item in errors:
        action = item.get("index") or item.get("create") or {}
        message_id = action.get("_id")
        if message_id:
            failed.add(str(message_id))
    return failed


def make_indexer(es: Elasticsearch):
    def indexer(batch: list[tuple[QueueMessage, Prepared]]) -> set[str]:
        actions = []
        for message, prepared in batch:
            actions.append(
                {
                    "_op_type": "index",
                    "_index": prepared.index,
                    "_id": message.id,
                    "_source": prepared.document,
                }
            )
        _ok, errors = bulk(es, actions, raise_on_error=False, stats_only=False)
        return failed_ids(errors)

    return indexer


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/health"):
            if STATE["healthy"]:
                body = b"ok"
                code = 200
            else:
                body = b"unhealthy"
                code = 503
            self.send_response(code)
            self.send_header("Content-Type", "text/plain")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return
        if self.path.startswith("/metrics"):
            payload = generate_latest()
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; version=0.0.4")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return
        self.send_error(404)

    def log_message(self, fmt: str, *args: object) -> None:
        return


def ensure_queue(service: Any, name: str) -> Any:
    from azure.core.exceptions import ResourceExistsError

    client = service.get_queue_client(name)
    try:
        client.create_queue()
    except ResourceExistsError:
        pass
    return client


def update_depth(queue: Any) -> None:
    properties = queue.get_queue_properties()
    count = properties.approximate_message_count
    QUEUE_DEPTH.set(0 if count is None else count)


def run_once(
    queue: Any,
    poison: Any,
    es: Elasticsearch,
    batch_size: int,
    visibility: int,
    wait_seconds: float,
    poison_after: int,
) -> HandleResult:
    update_depth(queue)
    raw_messages = receive_batch(queue, batch_size, visibility, wait_seconds)
    messages = [as_message(item) for item in raw_messages]
    by_id = {item.id: item for item in raw_messages}

    def poison_sender(message: QueueMessage) -> None:
        poison.send_message(message.content)

    result = handle_messages(messages, make_indexer(es), poison_sender, poison_after)
    for message in result.deleted:
        raw = by_id[message.id]
        queue.delete_message(raw.id, raw.pop_receipt)
    return result


def main() -> None:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    connection = os.environ.get("AZURE_STORAGE_CONNECTION_STRING", "").strip()
    if not connection:
        raise SystemExit("AZURE_STORAGE_CONNECTION_STRING is empty. Refusing to start.")

    from azure.storage.queue import QueueServiceClient

    service = QueueServiceClient.from_connection_string(connection)
    queue_name = os.environ.get("AZURE_QUEUE_NAME", "app-logs").strip() or "app-logs"
    poison_name = os.environ.get("AZURE_POISON_QUEUE_NAME", "app-logs-poison").strip() or "app-logs-poison"
    queue = ensure_queue(service, queue_name)
    poison = ensure_queue(service, poison_name)
    es = Elasticsearch(
        os.environ.get("ELASTICSEARCH_URL", "http://elasticsearch:9200"),
        basic_auth=(
            os.environ.get("ELASTICSEARCH_USERNAME", "logs_writer"),
            os.environ["ELASTICSEARCH_PASSWORD"],
        ),
    )
    batch_size = _int_env("BATCH_SIZE", 32)
    visibility = _int_env("VISIBILITY_TIMEOUT", 30)
    wait_seconds = float(os.environ.get("BATCH_WAIT_SECONDS", "2") or "2")
    poison_after = _int_env("POISON_AFTER", POISON_AFTER)

    server = ThreadingHTTPServer(("0.0.0.0", 8080), Handler)
    import threading

    threading.Thread(target=server.serve_forever, daemon=True).start()
    LOG.info("listening on :8080 queue=%s", queue_name)

    while True:
        try:
            if not elasticsearch_reachable(es):
                raise RuntimeError("Elasticsearch ping failed")
            result = run_once(queue, poison, es, batch_size, visibility, wait_seconds, poison_after)
            INDEXED.inc(result.indexed)
            POISONED.inc(result.poisoned)
            STATE["healthy"] = True
            if not result.deleted:
                time.sleep(wait_seconds)
        except Exception:
            STATE["healthy"] = False
            LOG.exception("log worker loop failed")
            time.sleep(wait_seconds)


if __name__ == "__main__":
    main()
