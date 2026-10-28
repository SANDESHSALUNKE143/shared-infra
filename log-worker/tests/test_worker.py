"""Index a sample shared-logger event with a fake queue message."""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from log_worker.worker import Prepared, QueueMessage, handle_messages, index_name, prepare_document


def sample_event() -> dict:
    return {
        "schema_version": 1,
        "timestamp": "2026-10-28T05:00:00.000Z",
        "level": "INFO",
        "message": "hello",
        "application": "billing",
        "environment": "Production",
    }


def test_index_name_is_lowercase():
    assert index_name("Production") == "logs-production"
    assert index_name("  ") is None


def test_indexes_sample_event_with_message_id():
    event = sample_event()
    message = QueueMessage(id="msg-1", content=json.dumps(event), dequeue_count=1)
    stored: dict[str, tuple[str, dict]] = {}

    def indexer(batch: list[tuple[QueueMessage, Prepared]]) -> set[str]:
        for item, prepared in batch:
            stored[item.id] = (prepared.index, prepared.document)
        return set()

    poisoned: list[str] = []
    result = handle_messages([message], indexer, lambda item: poisoned.append(item.id))

    assert poisoned == []
    assert [item.id for item in result.deleted] == ["msg-1"]
    assert result.indexed == 1
    index, document = stored["msg-1"]
    assert index == "logs-production"
    assert document["@timestamp"] == event["timestamp"]
    assert document["message"] == "hello"


def test_invalid_json_is_poisoned_immediately():
    message = QueueMessage(id="bad", content="not-json", dequeue_count=1)
    poisoned: list[str] = []
    result = handle_messages([message], lambda _batch: set(), lambda item: poisoned.append(item.id))
    assert poisoned == ["bad"]
    assert result.poisoned == 1
    assert result.indexed == 0


def test_wrong_schema_is_poisoned():
    payload = sample_event()
    payload["schema_version"] = 2
    message = QueueMessage(id="old", content=json.dumps(payload), dequeue_count=1)
    prepared = prepare_document(payload)
    assert prepared is None
    poisoned: list[str] = []
    handle_messages([message], lambda _batch: set(), lambda item: poisoned.append(item.id))
    assert poisoned == ["old"]


def test_dequeue_past_the_limit_skips_indexing():
    message = QueueMessage(id="stuck", content=json.dumps(sample_event()), dequeue_count=6)
    indexed: list[str] = []

    def indexer(batch):
        indexed.extend(item.id for item, _prepared in batch)
        return set()

    poisoned: list[str] = []
    result = handle_messages([message], indexer, lambda item: poisoned.append(item.id))
    assert indexed == []
    assert poisoned == ["stuck"]
    assert [item.id for item in result.deleted] == ["stuck"]


def test_rejected_document_stays_on_the_queue():
    message = QueueMessage(id="msg-9", content=json.dumps(sample_event()), dequeue_count=1)
    result = handle_messages([message], lambda _batch: {"msg-9"}, lambda item: None)
    assert result.deleted == []
    assert result.indexed == 0
