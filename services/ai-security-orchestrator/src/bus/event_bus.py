"""
Event Bus — Lightweight async event system for inter-agent communication.
Uses asyncio queues for in-process event delivery.
No external dependencies (Redis, NATS, etc.) required.
"""

import asyncio
import structlog
from typing import Dict, List, Callable, Any
from dataclasses import dataclass, field
from datetime import datetime, timezone

logger = structlog.get_logger()


@dataclass
class Event:
    """An event in the bus."""
    topic: str
    payload: Dict[str, Any]
    timestamp: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    source: str = "unknown"


class EventBus:
    """
    Lightweight in-process async event bus.
    Supports pub/sub pattern for AI agent communication.
    """

    def __init__(self):
        self._subscribers: Dict[str, List[Callable]] = {}
        self._queue: asyncio.Queue = asyncio.Queue(maxsize=10000)
        self._running = False
        self._processor_task = None

    @property
    def is_running(self) -> bool:
        return self._running

    def subscribe(self, topic: str, handler: Callable):
        """Subscribe a handler to a topic."""
        if topic not in self._subscribers:
            self._subscribers[topic] = []
        self._subscribers[topic].append(handler)
        logger.info("event_bus_subscribe", topic=topic, handler=handler.__name__)

    async def publish(self, event: Event):
        """Publish an event to the bus."""
        await self._queue.put(event)
        logger.debug("event_published", topic=event.topic, source=event.source)

    async def _process_events(self):
        """Background task to process events from the queue."""
        while self._running:
            try:
                event = await asyncio.wait_for(self._queue.get(), timeout=1.0)
                handlers = self._subscribers.get(event.topic, [])
                handlers += self._subscribers.get("*", [])  # Wildcard subscribers

                for handler in handlers:
                    try:
                        if asyncio.iscoroutinefunction(handler):
                            await handler(event)
                        else:
                            handler(event)
                    except Exception as e:
                        logger.error("event_handler_error",
                                     topic=event.topic, handler=handler.__name__, error=str(e))

                self._queue.task_done()
            except asyncio.TimeoutError:
                continue
            except Exception as e:
                logger.error("event_processing_error", error=str(e))

    async def start(self):
        """Start the event bus processor."""
        self._running = True
        self._processor_task = asyncio.create_task(self._process_events())
        logger.info("event_bus_started")

    async def stop(self):
        """Stop the event bus processor."""
        self._running = False
        if self._processor_task:
            self._processor_task.cancel()
            try:
                await self._processor_task
            except asyncio.CancelledError:
                pass
        logger.info("event_bus_stopped")
