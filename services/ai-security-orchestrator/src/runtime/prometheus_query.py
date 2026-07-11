"""
Prometheus Query Client — Queries Prometheus for live service metrics.
"""

import httpx
import structlog
from src.config import settings

logger = structlog.get_logger()


class PrometheusQuery:
    """Queries Prometheus HTTP API for SLO metrics."""

    def __init__(self, prometheus_url: str = None):
        self.url = prometheus_url or settings.PROMETHEUS_URL
        self.client = httpx.AsyncClient(timeout=5.0)

    async def query_instant(self, query: str) -> float:
        """Execute an instant query and return the float value."""
        try:
            response = await self.client.get(
                f"{self.url}/api/v1/query",
                params={"query": query}
            )
            if response.status_code == 200:
                data = response.json()
                results = data.get("data", {}).get("result", [])
                if results:
                    # Return the value of the first result series
                    val = results[0].get("value", [0, "0"])[1]
                    return float(val)
            return 0.0
        except Exception as e:
            logger.error("prometheus_query_failed", query=query, error=str(e))
            return 0.0

    async def query_slos(self) -> dict:
        """Query standard SLO metrics for portal-web."""
        error_rate_query = (
            'sum(rate(http_server_requests_total{namespace="securerag-hub",status=~"5.."}[2m])) '
            '/ sum(rate(http_server_requests_total{namespace="securerag-hub"}[2m]))'
        )
        latency_p95_query = (
            'histogram_quantile(0.95, sum(rate(http_server_request_duration_seconds_bucket{namespace="securerag-hub"}[2m])) by (le))'
        )
        cpu_query = (
            'avg(rate(container_cpu_usage_seconds_total{namespace="securerag-hub"}[5m]))'
        )
        mem_query = (
            'avg(container_memory_working_set_bytes{namespace="securerag-hub"})'
        )

        error_rate = await self.query_instant(error_rate_query)
        latency_p95 = await self.query_instant(latency_p95_query)
        cpu = await self.query_instant(cpu_query)
        mem = await self.query_instant(mem_query)

        return {
            "error_rate_5xx": error_rate,
            "p95_latency_ms": latency_p95 * 1000.0,  # convert to ms
            "cpu_utilization": cpu,
            "memory_utilization": mem,
        }

    async def close(self):
        await self.client.aclose()
