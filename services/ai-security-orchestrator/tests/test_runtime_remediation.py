"""
Tests for AI Security Orchestrator — Runtime & Remediation.
"""

import pytest
import asyncio
from src.bus.event_bus import Event, EventBus
from src.runtime.falco_consumer import FalcoConsumer
from src.remediation.yaml_fixer import YamlFixer
from src.remediation.pr_creator import PrCreator


class TestRuntimeRemediation:
    """Test suite for runtime alert ingestion and auto-remediation."""

    @pytest.mark.anyio
    async def test_falco_consumer_publishes_event(self):
        """Test that FalcoConsumer correctly parses and publishes events to the bus."""
        event_bus = EventBus()
        await event_bus.start()

        events_received = []

        async def dummy_handler(event: Event):
            events_received.append(event)

        event_bus.subscribe("runtime.event", dummy_handler)

        consumer = FalcoConsumer(event_bus)
        await consumer.ingest_alert({
            "rule": "Shell in container",
            "priority": "Critical",
            "output": "Shell spawned in container pod-123",
            "output_fields": {
                "k8s.pod.name": "pod-123",
                "k8s.ns.name": "securerag-hub",
                "container.name": "app-container"
            }
        })

        # Wait briefly for queue processing
        await asyncio.sleep(0.1)

        assert len(events_received) == 1
        event = events_received[0]
        assert event.topic == "runtime.event"
        assert event.payload["severity"] == "CRITICAL"
        assert event.payload["pod"] == "pod-123"
        assert event.payload["container"] == "app-container"

        await event_bus.stop()

    def test_yaml_fixer_applies_security_controls(self):
        """Test that YamlFixer secures deployment manifests."""
        unsecured_manifest = """
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
spec:
  template:
    spec:
      containers:
        - name: web
          image: test:latest
"""
        fixer = YamlFixer()
        fixed = fixer.fix_manifest(unsecured_manifest)

        assert "runAsNonRoot: true" in fixed
        assert "allowPrivilegeEscalation: false" in fixed
        assert "readOnlyRootFilesystem: true" in fixed
        assert "cpu: 100m" in fixed
        assert "limits:" in fixed

    def test_pr_creator(self, tmp_path):
        """Test that PrCreator simulates commit generation."""
        test_file = tmp_path / "deployment.yaml"
        test_file.write_text("dummy")

        creator = PrCreator()
        success = creator.create_remediation_commit(str(test_file), "fixed_content", "test-issue")

        assert success is True
        assert test_file.read_text() == "fixed_content"
