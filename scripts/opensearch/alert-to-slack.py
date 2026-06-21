#!/usr/bin/env python3
"""
SecureRAG SIEM - Alert to Slack Bridge

Queries OpenSearch for critical security events and forwards them to Slack.
Designed to run as a Kubernetes CronJob.
"""

import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timedelta, timezone
from typing import Any

OPENSEARCH_URL = os.getenv("OPENSEARCH_URL", "https://opensearch.opensearch.svc:9200")
OPENSEARCH_USER = os.getenv("OPENSEARCH_USER", "admin")
OPENSEARCH_PASS = os.getenv("OPENSEARCH_PASS", "admin")
SLACK_WEBHOOK_URL = os.getenv("SLACK_WEBHOOK_URL", "")
LOOKBACK_MINUTES = int(os.getenv("LOOKBACK_MINUTES", "5"))
SEVERITY_THRESHOLD = os.getenv("SEVERITY_THRESHOLD", "warning")

INDICES = [
    "falco-events-*",
    "tetragon-events-*",
    "k8s-audit-*",
    "kyverno-admissions-*",
]


def build_opensearch_query(lookback_minutes: int) -> dict[str, Any]:
    now = datetime.now(timezone.utc)
    since = now - timedelta(minutes=lookback_minutes)
    return {
        "query": {
            "bool": {
                "filter": [
                    {"range": {"@timestamp": {"gte": since.isoformat()}}},
                ]
            }
        },
        "size": 50,
        "sort": [{"@timestamp": {"order": "desc"}}],
    }


def query_opensearch(index: str, query: dict) -> list[dict]:
    url = f"{OPENSEARCH_URL}/{index}/_search"
    req_data = json.dumps(query).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=req_data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    password_mgr = urllib.request.HTTPPasswordMgrWithDefaultRealm()
    password_mgr.add_password(None, OPENSEARCH_URL, OPENSEARCH_USER, OPENSEARCH_PASS)
    handler = urllib.request.HTTPBasicAuthHandler(password_mgr)
    opener = urllib.request.build_opener(handler)

    ctx = __import__("ssl").create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = __import__("ssl").CERT_NONE

    try:
        with opener.open(req, timeout=30, context=ctx) as resp:
            result = json.loads(resp.read().decode("utf-8"))
            return [hit["_source"] for hit in result.get("hits", {}).get("hits", [])]
    except urllib.error.URLError as e:
        print(f"Error querying {index}: {e}", file=sys.stderr)
        return []


def format_slack_message(events: list[dict], index: str) -> dict:
    if not events:
        return {}

    severity_colors = {
        "critical": "#FF0000",
        "error": "#FF4500",
        "warning": "#FFA500",
        "info": "#1E90FF",
    }
    color = severity_colors.get(
        events[0].get("priority", events[0].get("severity", "info")), "#808080"
    )

    fields = []
    for evt in events[:10]:
        ts = evt.get("@timestamp", "")[:19].replace("T", " ")
        title = evt.get("rule", evt.get("event_type", evt.get("result", "Unknown")))
        pod = evt.get("pod", evt.get("resource_name", "N/A"))
        ns = evt.get("namespace", evt.get("resource_namespace", "N/A"))
        fields.append(
            {
                "title": title,
                "value": f"Pod: {pod} | Namespace: {ns} | Time: {ts}",
                "short": False,
            }
        )

    total = len(events)
    return {
        "attachments": [
            {
                "color": color,
                "title": f"SIEM Alert: {index}",
                "text": f"Found {total} event(s) in the last {LOOKBACK_MINUTES} minutes.",
                "fields": fields,
                "footer": "SecureRAG SIEM OpenSearch",
                "ts": int(datetime.now(timezone.utc).timestamp()),
            }
        ]
    }


def send_to_slack(payload: dict) -> bool:
    if not SLACK_WEBHOOK_URL:
        print("No SLACK_WEBHOOK_URL configured, skipping Slack notification")
        return False

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        SLACK_WEBHOOK_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            if resp.status == 200:
                print("Slack notification sent successfully")
                return True
            print(f"Slack returned HTTP {resp.status}", file=sys.stderr)
            return False
    except urllib.error.URLError as e:
        print(f"Failed to send to Slack: {e}", file=sys.stderr)
        return False


def main():
    all_events = 0
    for index in INDICES:
        query = build_opensearch_query(LOOKBACK_MINUTES)
        events = query_opensearch(index, query)
        if events:
            all_events += len(events)
            slack_msg = format_slack_message(events, index)
            if slack_msg:
                send_to_slack(slack_msg)
        else:
            print(f"No events in {index} for the last {LOOKBACK_MINUTES} minutes")

    print(f"Total events found: {all_events}")
    return 0 if all_events == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
