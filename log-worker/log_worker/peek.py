"""Print poison-queue messages without deleting them."""

from __future__ import annotations

import os
import sys


def main() -> None:
    connection = os.environ.get("AZURE_STORAGE_CONNECTION_STRING", "").strip()
    if not connection:
        raise SystemExit("AZURE_STORAGE_CONNECTION_STRING is empty.")
    name = os.environ.get("AZURE_POISON_QUEUE_NAME", "app-logs-poison").strip() or "app-logs-poison"
    from azure.storage.queue import QueueClient

    queue = QueueClient.from_connection_string(connection, name)
    messages = list(queue.peek_messages(max_messages=32))
    if not messages:
        print("poison queue is empty")
        return
    for message in messages:
        print(message.content)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        print(f"failed to peek poison queue: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
