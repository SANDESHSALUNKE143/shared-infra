"""Checks for the line, spike, and pause alert templates."""

from __future__ import annotations

import unittest

from alert_rules import render_alerts


class AlertTemplateTest(unittest.TestCase):
    def test_defaults_keep_the_basic_rules_and_add_spike_and_pause(self) -> None:
        text = render_alerts({})
        self.assertIn("alert: TargetDown", text)
        self.assertIn("expr: up == 0", text)
        self.assertIn("for: 2m", text)
        self.assertIn('kind: pause', text)
        self.assertIn("expr: log_queue_depth > 1000", text)
        self.assertIn("for: 10m", text)
        self.assertIn('kind: line', text)
        self.assertIn(") < 0.15", text)
        self.assertIn('color="yellow"', text)
        self.assertIn('color="red"', text)
        self.assertIn("for: 1m", text)
        self.assertIn("alert: LogIndexingPaused", text)
        self.assertIn("rate(log_worker_indexed_total[15m]) == 0", text)
        self.assertIn("alert: LogPoisonSpike", text)
        self.assertIn("kind: spike", text)
        self.assertIn("5 * avg_over_time(rate(log_worker_poison_total[5m])[1h:5m])", text)
        self.assertIn("rate(log_worker_poison_total[5m]) > 0.01", text)
        self.assertIn("{{ $labels.job }} on {{ $labels.instance }} is down", text)
        self.assertIn("{{ $labels.mountpoint }}", text)

    def test_thresholds_come_from_configuration(self) -> None:
        text = render_alerts(
            {
                "ALERT_QUEUE_DEPTH": "250",
                "ALERT_QUEUE_FOR": "5m",
                "ALERT_DISK_FREE_RATIO": "0.2",
                "ALERT_POISON_SPIKE_MULTIPLIER": "3",
            }
        )
        self.assertIn("expr: log_queue_depth > 250", text)
        self.assertIn("more than 250 messages", text)
        self.assertIn("for: 5m", text)
        self.assertIn(") < 0.2", text)
        self.assertIn("over 80 percent full", text)
        self.assertIn("3 * avg_over_time", text)

    def test_a_bad_duration_is_rejected(self) -> None:
        with self.assertRaises(SystemExit):
            render_alerts({"ALERT_TARGET_DOWN_FOR": "2 minutes"})


if __name__ == "__main__":
    unittest.main()
