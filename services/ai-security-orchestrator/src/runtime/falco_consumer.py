"""
Falco Consumer — Consumes runtime security alerts from Falco and publishes them to the event bus.
"""

import structlog
from src.bus.event_bus import Event, EventBus

logger = structlog.get_logger()


class FalcoConsumer:
    """Consumes Falco raw logs/JSON alerts and routes them to the event bus."""

    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus

    async def ingest_alert(self, raw_alert: dict):
        """
        Ingest a raw alert from Falco webhook and parse it.
        Example raw_alert fields: output, priority, rule, output_fields.
        """
        rule = raw_alert.get("rule", "Unknown rule")
        priority = raw_alert.get("priority", "WARNING")
        output = raw_alert.get("output", "")
        fields = raw_alert.get("output_fields", {})

        pod = fields.get("k8s.pod.name", fields.get("container.id", "unknown"))
        namespace = fields.get("k8s.ns.name", "securerag-hub")
        container = fields.get("container.name", "unknown")

        logger.info("falco_alert_ingested", rule=rule, priority=priority, pod=pod)

        # Standardize priority to EventBus severities
        severity = "WARNING"
        if priority in ("Emergency", "Alert", "Critical"):
            severity = "CRITICAL"
        elif priority in ("Error", "Warning"):
            severity = "WARNING"
        else:
            severity = "INFO"

        event = Event(
            topic="runtime.event",
            source="falco",
            payload={
                "event_type": rule,
                "severity": severity,
                "namespace": namespace,
                "pod": pod,
                "container": container,
                "description": output,
                "raw_fields": fields
            }
        )

        await self.event_bus.publish(event)
