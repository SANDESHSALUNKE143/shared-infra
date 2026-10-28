"""Turn queue messages into Elasticsearch documents.

Invalid JSON and events that are not schema_version 1 go to the poison queue
immediately. A message whose dequeue count is already above the limit goes
there too, without another index attempt. The Azure message id is the
document id, so a later retry replaces the same document instead of copying it.
"""

from __future__ import annotations

import json
import re
from dataclasses import dataclass
from typing import Any, Callable

SCHEMA_VERSION = 1
POISON_AFTER = 5

_INDEX_CLEAN = re.compile(r"[^a-z0-9]+")


@dataclass
class QueueMessage:
    """One received queue message. Tests build this directly."""

    id: str
    content: str
    dequeue_count: int
    pop_receipt: str = ""


@dataclass
class Prepared:
    index: str
    document: dict[str, Any]


@dataclass
class HandleResult:
    deleted: list[QueueMessage]
    indexed: int
    poisoned: int


def index_name(environment: str) -> str | None:
    """Return logs-{environment} with a safe index name, or None."""
    cleaned = _INDEX_CLEAN.sub("-", environment.strip().lower()).strip("-")
    if not cleaned:
        return None
    return f"logs-{cleaned}"


def prepare_document(payload: Any) -> Prepared | None:
    """Accept one shared-logger event. Return None when it must be poisoned."""
    if not isinstance(payload, dict):
        return None
    version = payload.get("schema_version")
    if type(version) is not int or version != SCHEMA_VERSION:
        return None
    timestamp = payload.get("timestamp")
    environment = payload.get("environment")
    if not isinstance(timestamp, str) or not timestamp.strip():
        return None
    if not isinstance(environment, str):
        return None
    name = index_name(environment)
    if name is None:
        return None
    document = dict(payload)
    document["@timestamp"] = timestamp
    return Prepared(index=name, document=document)


def handle_messages(
    messages: list[QueueMessage],
    indexer: Callable[[list[tuple[QueueMessage, Prepared]]], set[str]],
    poison_sender: Callable[[QueueMessage], None],
    poison_after: int = POISON_AFTER,
) -> HandleResult:
    """Index a batch. Poison the rest. Return messages that should be deleted.

    ``indexer`` receives the messages worth writing and returns the message ids
    Elasticsearch rejected. Those messages stay on the queue for another try.
    ``poison_sender`` runs before a poison message is marked for deletion.
    """
    to_index: list[tuple[QueueMessage, Prepared]] = []
    to_poison: list[QueueMessage] = []
    for message in messages:
        if message.dequeue_count > poison_after:
            to_poison.append(message)
            continue
        try:
            payload = json.loads(message.content)
        except json.JSONDecodeError:
            to_poison.append(message)
            continue
        prepared = prepare_document(payload)
        if prepared is None:
            to_poison.append(message)
            continue
        to_index.append((message, prepared))

    failed: set[str] = set()
    if to_index:
        failed = indexer(to_index)

    deleted: list[QueueMessage] = []
    for message in to_poison:
        poison_sender(message)
        deleted.append(message)
    indexed = 0
    for message, _prepared in to_index:
        if message.id in failed:
            continue
        deleted.append(message)
        indexed += 1
    return HandleResult(deleted=deleted, indexed=indexed, poisoned=len(to_poison))
