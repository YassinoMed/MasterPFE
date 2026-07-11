"""
AI Runtime Loop — Correlates alerts, queries metrics, and triggers auto-remediations.
Runs in the background of the AI Security Orchestrator.
"""

import asyncio
import structlog
from datetime import datetime, timezone
from src.bus.event_bus import Event, EventBus
from src.runtime.falco_consumer import FalcoConsumer
from src.runtime.prometheus_query import PrometheusQuery
from src.runtime.rollback_trigger import RollbackTrigger
from src.runtime.incident_creator import IncidentCreator

logger = structlog.get_logger()


class RuntimeLoop:
    """
    Background runtime loop that polls metrics, monitors Falco alerts,
    and runs correlation logic to trigger rollback or alerts.
    """

    def __init__(self, event_bus: EventBus):
        self.event_bus = event_bus
        self.falco_consumer = FalcoConsumer(event_bus)
        self.prom_query = PrometheusQuery()
        self.rollback_trigger = RollbackTrigger()
        self.incident_creator = IncidentCreator()
        self._running = False
        self._task = None

    async def start(self):
        """Start the background loops."""
        self._running = True
        self._task = asyncio.create_task(self._run_polling_loop())
        # Subscribe to runtime events on the bus
        self.event_bus.subscribe("runtime.event", self.handle_runtime_event)
        logger.info("runtime_loop_started")

    async def stop(self):
        """Stop background execution."""
        self._running = False
        if self._task:
            self._task.cancel()
            try:
                await self._task
            except asyncio.CancelledError:
                pass
        logger.info("runtime_loop_stopped")

    async def _run_polling_loop(self):
        """Poll metrics and cluster status every 30 seconds."""
        while self._running:
            try:
                logger.debug("runtime_loop_polling_started")
                # 1. Query Prometheus for SLO violations and error rates
                metrics = await self.prom_query.query_slos()

                # 2. If anomalous error rates or latencies are detected, evaluate rollback
                if metrics.get("error_rate_5xx", 0.0) > 0.05:
                    logger.warn("high_error_rate_detected", error_rate=metrics["error_rate_5xx"])
                    # Trigger automated rollback of the service
                    await self.rollback_trigger.trigger_rollback(
                        service="portal-web",
                        namespace="securerag-hub",
                        reason=f"Automated Rollback: 5xx error rate ({metrics['error_rate_5xx']:.2%}) exceeds 5% threshold"
                    )

                # 3. Publish metrics event
                await self.event_bus.publish(Event(
                    topic="metrics.poll",
                    source="runtime_loop",
                    payload=metrics
                ))

                await asyncio.sleep(30)
            except asyncio.CancelledError:
                break
            except Exception as e:
                logger.error("runtime_loop_polling_error", error=str(e))
                await asyncio.sleep(10)

    async def handle_runtime_event(self, event: Event):
        """Handle incoming Falco runtime alerts from the event bus."""
        payload = event.payload
        severity = payload.get("severity", "WARNING")
        event_type = payload.get("event_type", "unknown")
        pod = payload.get("pod", "unknown")
        namespace = payload.get("namespace", "securerag-hub")

        logger.info("runtime_event_received", event_type=event_type, severity=severity, pod=pod)

        # Correlate alerts and trigger auto-remediation actions
        if severity in ("CRITICAL", "EMERGENCY"):
            # Trigger Incident Creation (PagerDuty/Slack/Loki logs)
            incident_id = await self.incident_creator.create_incident(
                title=f"CRITICAL Security Event: {event_type} on {pod}",
                description=payload.get("description", ""),
                severity=severity,
                metadata=payload
            )

            # Automated remediation: Kill pod if it's a critical runtime shell execution
            if "shell" in event_type.lower() or "exec" in event_type.lower():
                logger.warn("auto_remediation_triggered_kill_pod", pod=pod, namespace=namespace)
                # In real K8s, we would call Kubernetes client API to delete the pod.
                # Let's log it and publish a remediation event.
                await self.event_bus.publish(Event(
                    topic="remediation.action",
                    source="runtime_loop",
                    payload={
                        "action": "KILL_POD",
                        "pod": pod,
                        "namespace": namespace,
                        "reason": f"AI Auto-Remediation: shell execution detected inside container (incident: {incident_id})",
                        "timestamp": datetime.now(timezone.utc).isoformat()
                    }
                ))
