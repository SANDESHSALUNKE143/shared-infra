# Alert configuration

Prometheus rules in this stack watch the path from the Azure queue into the `logs-*` indexes. `scripts/up.sh` renders `prometheus/alerts.yml` from the Jinja templates in `prometheus/alert-templates`. The numbers come from `.env`. A missing key keeps the default, so an older `.env` still renders the same rules.

The host needs the `python3-jinja2` package. `scripts/bootstrap-vm.sh` installs it.

## The logs index these alerts protect

Applications never open Elasticsearch. `shared-logger` puts one JSON event on `app-logs`. The log worker is the only writer. A good event becomes one document. A bad event goes to `app-logs-poison` and never becomes a document.

The index name is `logs-` plus the event's `environment`, lowercased, with other characters turned into hyphens. `Production` lands in `logs-production`. The Azure message id is the document id, so a retry replaces that document.

`elasticsearch/init.sh` installs this on first start, and again on every boot:

| Piece | Name | What it does |
| --- | --- | --- |
| Index template | `logs` | Matches `logs-*`. One primary shard, zero replicas, 5 second refresh, best compression, 1000 field limit. |
| Ingest pipeline | `logs-shared-logger` | Copies `timestamp` onto `@timestamp` when the document does not already have it. |
| Lifecycle | `logs-retention` | Deletes the index after `LOG_RETENTION_DAYS` (30 by default). |
| Writer role | `logs_writer` | Can create and write `logs-*`. Cannot read other indexes or administer the cluster. |
| Reader role | `logs_reader` | Can read `logs-*` and open Kibana Discover. Grafana uses this user. |
| Kibana data view | Application logs | Title `logs-*`, time field `@timestamp`. |

Mapped fields on every `logs-*` index:

| Field | Type | Role |
| --- | --- | --- |
| `@timestamp`, `timestamp` | date | When the event happened. Kibana uses `@timestamp`. |
| `schema_version` | integer | Must be `1`. Anything else is poisoned before indexing. |
| `level` | keyword | Severity inside the event. This is not the Prometheus alert severity. |
| `message` | text | The log line. |
| `application`, `environment`, `service_version`, `component` | keyword | Who emitted it, and which index received it (`environment`). |
| `cluster`, `region`, `hostname` | keyword | Where it ran. |
| `process_id`, `thread_id` | long | Process and thread. |
| `correlation_id` | keyword | Tie one request together in Discover. |
| `metadata` | object | Extra fields. Dynamic, under the 1000 field limit. |
| `exception.type` | keyword | Exception class, when present. |
| `exception.message`, `exception.traceback` | text | Exception text. |

An event is poisoned, and stays out of `logs-*`, when the body is not JSON, `schema_version` is not the integer `1`, `timestamp` or `environment` is missing, or the same message has already been dequeued more than 5 times.

## Rules

Each rule has a `kind` label: `line`, `pause`, or `spike`. `severity` is `warning` or `critical`. Summaries that contain `{{ $labels.job }}` are Prometheus text. Jinja writes them through as-is.

| Alert | Kind | Default | What it means for `logs-*` |
| --- | --- | --- | --- |
| `TargetDown` | pause | `up == 0` for 2 minutes | That scrape target is gone. If the job is the log worker, nothing new is written to `logs-*`. |
| `LogQueueDepthHigh` | line | `log_queue_depth` above 1000 for 10 minutes | Events are waiting on `app-logs`. Discover lags behind the applications. |
| `HostDiskSpaceLow` | line | free space under 15 percent for 10 minutes | The filesystem is over 85 percent full. Elasticsearch stops accepting writes to `logs-*` when its own disk watermark is reached. |
| `ElasticsearchClusterYellow` | line | yellow for 5 minutes | A shard is not fully allocated. With zero replicas this is still a warning: a `logs-*` index may be missing a copy or a new index may be stuck. |
| `ElasticsearchClusterRed` | line | red for 1 minute | A primary shard is unavailable. Part of `logs-*` cannot be read or written. |
| `LogIndexingPaused` | pause | queue depth above 0 and no indexed events for 15 minutes | The worker still has messages and `log_worker_indexed_total` is flat. Documents are not landing in `logs-*`. An empty queue does not fire this. |
| `LogPoisonSpike` | spike | recent poison rate above 5 times the last hour, and above 0.01 per second, for 10 minutes | Bad events are rising. Those messages are on `app-logs-poison`, not in `logs-*`. One poison event on a quiet day stays under the floor. |

`TargetDown`, `LogQueueDepthHigh`, the disk rule, and the two cluster-health rules are the original checks. Indexing paused and the poison spike use the same templates.

## Settings

Put these in `.env`. Durations are a positive integer plus `s`, `m`, `h`, or `d`, with no spaces (`10m`, not `10 minutes`). A bad value stops `scripts/up.sh` before it rewrites `alerts.yml`. Fix the value and run it again.

| Variable | Default | Rule |
| --- | --- | --- |
| `ALERT_TARGET_DOWN_FOR` | `2m` | `TargetDown` |
| `ALERT_QUEUE_DEPTH` | `1000` | `LogQueueDepthHigh`. Positive integer. |
| `ALERT_QUEUE_FOR` | `10m` | `LogQueueDepthHigh` |
| `ALERT_DISK_FREE_RATIO` | `0.15` | `HostDiskSpaceLow`. Free space divided by size. Must be greater than 0 and less than 1. `0.15` alerts above 85 percent full. `0.2` alerts above 80 percent. |
| `ALERT_DISK_FOR` | `10m` | `HostDiskSpaceLow` |
| `ALERT_ES_YELLOW_FOR` | `5m` | `ElasticsearchClusterYellow` |
| `ALERT_ES_RED_FOR` | `1m` | `ElasticsearchClusterRed` |
| `ALERT_INDEX_PAUSE_FOR` | `15m` | `LogIndexingPaused`. This is both the wait and the rate window. |
| `ALERT_POISON_SPIKE_WINDOW` | `5m` | `LogPoisonSpike` rate range. |
| `ALERT_POISON_SPIKE_BASELINE` | `1h` | `LogPoisonSpike` comparison range. |
| `ALERT_POISON_SPIKE_MULTIPLIER` | `5` | How many times the baseline the recent rate must beat. |
| `ALERT_POISON_SPIKE_MIN_RATE` | `0.01` | Minimum poison events per second. Keeps a near-zero baseline from paging. |
| `ALERT_POISON_SPIKE_FOR` | `10m` | How long the spike must hold. |
| `ALERT_WEBHOOK_URL` | empty | Alertmanager receiver. Leave empty and alerts still show in the UI. |

`LOG_RETENTION_DAYS` is not an alert. It is how long a `logs-*` index lives before the lifecycle policy deletes it.

After you change a threshold:

```bash
scripts/up.sh
docker compose --env-file .env restart prometheus
```

Prometheus reads rule files on startup and on reload. Restarting the container is the reload this Compose file uses. A webhook change needs the same `scripts/up.sh`. Restart Alertmanager when only the webhook changed: `docker compose --env-file .env restart alertmanager`.

## Templates

Copy one of the three macros in `prometheus/alert-templates/alerts.yml.j2`.

`line.yml.j2` fires when an expression stays true. Pass `name`, `expr`, `duration`, `severity`, and `summary`. A multi-line `expr` is indented as a YAML block.

`pause.yml.j2` takes the same arguments. Use it when a series that should keep moving has stopped, such as `up == 0` or a counter that has gone flat while work is waiting.

`spike.yml.j2` compares a counter with itself:

```text
rate(metric[window]) > multiplier * avg_over_time(rate(metric[window])[baseline:window])
and
rate(metric[window]) > min_rate
```

Pass `name`, `metric`, `window`, `baseline`, `multiplier`, `min_rate`, `duration`, `severity`, and `summary`. `metric` is a Prometheus counter name. The poison rule uses `log_worker_poison_total`.

The worker exposes three series on `:8080/metrics`:

| Series | Type | Meaning |
| --- | --- | --- |
| `log_queue_depth` | gauge | Approximate messages still on `app-logs`. |
| `log_worker_indexed_total` | counter | Documents Elasticsearch accepted. |
| `log_worker_poison_total` | counter | Messages copied to `app-logs-poison`. |

Cluster health comes from elasticsearch-exporter, not from a query against `logs-*`. Disk free space comes from node-exporter. `up` is Prometheus's own scrape result.

Render the file without starting Compose:

```bash
python3 -c "import sys; sys.path.insert(0, 'scripts'); from alert_rules import render_alerts; print(render_alerts({}))"
```

Check the defaults, an override, and a rejected duration:

```bash
python3 scripts/test_alert_rules.py
```

## When one fires

Firing alerts show in Alertmanager on `127.0.0.1:9093` and in Grafana's Alertmanager datasource. `scripts/fire-test-alert.sh` posts one `TestAlert` so you can see that path without stopping a service.

| Alert | Look here |
| --- | --- |
| `TargetDown` | The `job` and `instance` in the summary. For the worker, `docker compose --env-file .env --profile worker ps` and the worker logs. |
| `LogQueueDepthHigh` | Queue depth in Grafana. Then Elasticsearch health. The worker deletes a message only after the bulk index succeeds, so a slow or refusing cluster makes this climb. |
| `LogIndexingPaused` | `logs_writer` can reach Elasticsearch, and `GET logs-*/_count` on the VM is still moving. A red cluster or a full disk stops this counter. |
| `LogPoisonSpike` | `scripts/peek-poison.sh` prints the poison queue without deleting it. Compare `schema_version`, `timestamp`, and `environment` with the fields above. |
| `ElasticsearchClusterYellow` or `Red` | `GET _cluster/health` and `GET _cat/shards?v` as the `elastic` user on `127.0.0.1:9200`. Yellow can sit while a new `logs-*` index allocates. Red means a primary is missing. |
| `HostDiskSpaceLow` | The `mountpoint` in the summary. Elasticsearch data is the `elasticsearch-data` volume on that disk. Free space before the watermark blocks writes. |

Search the documents that did land in Kibana under the Application logs data view. Filter `environment` to the index you expect, for example `logs-dev`. Poisoned events will not be in that view.
