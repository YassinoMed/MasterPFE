#!/usr/bin/env python3
"""Script : Transforme les logs sécurité en datasets d'entraînement AISEC.

Usage :
  python3 scripts/ai/generate-datasets.py [--source falco|trivy|kyverno|all]
                                         [--output datasets/]
                                         [--max-events 50]
                                         [--types classification,severity,remediation,explanation]
"""
import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, ".")

from secai.dataset_generator import (
    DatasetType,
    export_jsonl,
    export_summary,
    transform_log_to_dataset,
)

# ── Collecte des logs depuis le cluster ──────────────────────────────────────

def collect_falco_events(max_events: int = 50) -> list[dict]:
    """Collecte les events Falco depuis le fichier d'evidence."""
    events = []
    falco_file = Path("evidence/2026-09-27/falco-events-24h.log")
    if falco_file.exists():
        with open(falco_file) as f:
            for line in f:
                line = line.strip()
                if line:
                    try:
                        events.append(json.loads(line))
                    except json.JSONDecodeError:
                        continue
                if len(events) >= max_events:
                    break
    return events


def collect_trivy_findings(max_events: int = 50) -> list[dict]:
    """Collecte les findings Trivy depuis les ConfigAuditReports du cluster."""
    import subprocess
    findings = []
    try:
        result = subprocess.run(
            ["kubectl", "get", "configauditreports", "-A", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            for item in data.get("items", []):
                for check in item.get("status", {}).get("results", []):
                    finding = {
                        "VulnerabilityID": check.get("id", ""),
                        "Severity": check.get("severity", "MEDIUM"),
                        "PkgName": check.get("subject", ""),
                        "Description": check.get("message", ""),
                        "References": [check.get("uri", "")],
                    }
                    findings.append(finding)
                    if len(findings) >= max_events:
                        break
    except Exception as e:
        print(f"  [WARN] Trivy collect: {e}")
    return findings


def collect_kyverno_reports(max_events: int = 50) -> list[dict]:
    """Collecte les PolicyReports Kyverno."""
    import subprocess
    reports = []
    try:
        result = subprocess.run(
            ["kubectl", "get", "policyreports", "-A", "-o", "json"],
            capture_output=True, text=True, timeout=30
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            for item in data.get("items", []):
                for result_entry in item.get("status", {}).get("results", []):
                    report = {
                        "rule": result_entry.get("policy", ""),
                        "priority": result_entry.get("result", "MEDIUM"),
                        "process": result_entry.get("resources", [{}])[0].get("kind", ""),
                        "command": "",
                        "file": result_entry.get("resources", [{}])[0].get("name", ""),
                        "output": result_entry.get("message", "")[:500],
                        "tags": [],
                    }
                    reports.append(report)
                    if len(reports) >= max_events:
                        break
    except Exception as e:
        print(f"  [WARN] Kyverno collect: {e}")
    return reports


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Génère des datasets AISEC depuis les logs")
    parser.add_argument("--source", default="falco", choices=["falco", "trivy", "kyverno", "all"])
    parser.add_argument("--output", default="datasets/aisec")
    parser.add_argument("--max-events", type=int, default=50)
    parser.add_argument("--types", default="classification,severity,remediation")
    parser.add_argument("--dry-run", action="store_true", help="Sans appel LLM (fallback)")
    args = parser.parse_args()

    # Parse types
    dataset_types = []
    for t in args.types.split(","):
        try:
            dataset_types.append(DatasetType(t.strip()))
        except ValueError:
            pass

    print("═" * 60)
    print("  GÉNÉRATEUR DE DATASETS AISEC — SecureRAG Hub")
    print("═" * 60)
    print(f"  Source: {args.source}")
    print(f"  Types: {[t.value for t in dataset_types]}")
    print(f"  Max events: {args.max_events}")
    print(f"  Output: {args.output}")
    print()

    # Collecter les logs
    all_examples = []

    if args.source in ("falco", "all"):
        events = collect_falco_events(args.max_events)
        print(f"  Falco events collectés: {len(events)}")
        for i, event in enumerate(events):
            print(f"    [{i+1}/{len(events)}] {event.get('rule', '?')} ({event.get('priority', '?')})")
            examples = transform_log_to_dataset(event, source="falco", dataset_types=dataset_types)
            all_examples.extend(examples)

    if args.source in ("trivy", "all"):
        findings = collect_trivy_findings(args.max_events)
        print(f"  Trivy findings collectés: {len(findings)}")
        for i, finding in enumerate(findings[:10]):  # Limite pour la vitesse
            print(f"    [{i+1}/{min(10, len(findings))}] {finding.get('VulnerabilityID', '?')}")
            examples = transform_log_to_dataset(finding, source="trivy", dataset_types=dataset_types)
            all_examples.extend(examples)

    if args.source in ("kyverno", "all"):
        reports = collect_kyverno_reports(args.max_events)
        print(f"  Kyverno reports collectés: {len(reports)}")
        for i, report in enumerate(reports[:10]):
            print(f"    [{i+1}/{min(10, len(reports))}] {report.get('rule', '?')}")
            examples = transform_log_to_dataset(report, source="kyverno", dataset_types=dataset_types)
            all_examples.extend(examples)

    # Export
    print()
    print(f"  Total exemples générés: {len(all_examples)}")

    for ds_type in dataset_types:
        type_examples = [ex for ex in all_examples if ex.dataset_type == ds_type.value]
        output_file = f"{args.output}/{ds_type.value}.jsonl"
        count = export_jsonl(type_examples, output_file)
        print(f"    {ds_type.value}: {count} exemples → {output_file}")

    # Summary
    summary = export_summary(all_examples)
    summary_file = f"{args.output}/dataset-summary.json"
    Path(args.output).mkdir(parents=True, exist_ok=True)
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)
    print(f"\n  Summary → {summary_file}")

    print()
    print("  " + "═" * 58)
    print("  DATASET PRÊT POUR FINE-TUNING")
    print("  " + "═" * 58)
    for k, v in summary["by_dataset_type"].items():
        print(f"    {k}: {v} exemples")
    print(f"  Sévérités: {summary['by_severity']}")
    print(f"  Guardrails: {summary['by_guardrail_verdict']}")
    print(f"  MITRE tags: {summary['mitre_tags_covered']}")
    print()
    print(f"  Pour fine-tuner (LoRA) :")
    print(f"    datasets: {args.output}/classification.jsonl")
    print(f"    base_model: Qwen/Qwen2.5-0.5B-Instruct")
    print(f"    format: instruction-tuning JSONL")
    print()


if __name__ == "__main__":
    main()
