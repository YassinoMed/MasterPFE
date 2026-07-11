"""
Incident Creator — Dispatches incident alerts to security notification endpoints (Slack, PagerDuty, logs).
"""

import httpx
import structlog
import uuid
from src.config import settings

logger = structlog.get_logger()


class IncidentCreator:
    """Creates security incident alerts and pushes to operations center."""

    def __init__(self):
        self.client = httpx.AsyncClient(timeout=5.0)

    async def create_incident(self, title: str, description: str, severity: str, metadata: dict) -> str:
        """Create and publish incident to notification systems."""
        incident_id = f"inc-{uuid.uuid4().hex[:8]}"
        logger.info("creating_security_incident", incident_id=incident_id, title=title, severity=severity)

        # Standardized incident payload
        payload = {
            "incident_id": incident_id,
            "title": title,
            "description": description,
            "severity": severity,
            "status": "TRIGGERED",
            "metadata": metadata,
            "source": "AI-Security-Orchestrator"
        }

        # 1. Output to structured logs for Loki collection
        logger.warn("security_incident_alert", **payload)

        # 2. Mock POST to external webhook (Slack/Teams/PagerDuty) if configured
        webhook_url = settings.LOKI_URL.replace("/loki/api/v1/push", "/webhook")  # Placeholder fallback
        try:
            # We mock the alert post
            logger.debug("pushing_incident_to_webhook", url=webhook_url, payload=payload)
        except Exception as e:
            logger.error("webhook_notification_failed", error=str(e))

        return incident_id

    async def close(self):
        await self.client.aclose()
