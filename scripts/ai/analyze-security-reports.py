#!/usr/bin/env python3
import os
import sys
import json
import xml.etree.ElementTree as ET
import argparse
import urllib.request
import urllib.error

def main():
    parser = argparse.ArgumentParser(description="Analyze security reports and generate AI advisory")
    parser.add_argument("--semgrep", required=True, help="Semgrep report JSON path")
    parser.add_argument("--gitleaks", required=True, help="Gitleaks report JSON path")
    parser.add_argument("--trivy", required=True, help="Trivy FS report JSON path")
    parser.add_argument("--checkov", required=True, help="Checkov report XML path")
    parser.add_argument("--output", required=True, help="Output Markdown report path")
    parser.add_argument("--context", required=True, help="Business/Application context")
    parser.add_argument("--model", default="claude-sonnet-4-6", help="Model name to use")

    args = parser.parse_args()

    # Extract summaries
    semgrep_summary = ""
    gitleaks_summary = ""
    trivy_summary = ""
    checkov_summary = ""

    # Parse Semgrep
    if os.path.exists(args.semgrep):
        try:
            with open(args.semgrep, "r", encoding="utf-8") as f:
                data = json.load(f)
                results = data.get("results", [])
                semgrep_summary += f"Total Semgrep findings: {len(results)}\n"
                for i, r in enumerate(results[:20]):
                    extra = r.get("extra", {})
                    message = extra.get("message", "")
                    severity = extra.get("severity", "")
                    path = r.get("path", "")
                    line = r.get("start", {}).get("line", 0)
                    semgrep_summary += f"- [{severity}] {path}:{line} - {message[:120]}\n"
                if len(results) > 20:
                    semgrep_summary += f"... and {len(results) - 20} more findings.\n"
        except Exception as e:
            semgrep_summary = f"Error parsing Semgrep report: {e}\n"
    else:
        semgrep_summary = "Semgrep report not found or empty.\n"

    # Parse Gitleaks
    if os.path.exists(args.gitleaks):
        try:
            with open(args.gitleaks, "r", encoding="utf-8") as f:
                data = json.load(f)
                gitleaks_summary += f"Total Gitleaks secrets detected: {len(data)}\n"
                for i, r in enumerate(data[:20]):
                    desc = r.get("Description", "")
                    file = r.get("File", "")
                    line = r.get("StartLine", 0)
                    gitleaks_summary += f"- {desc} in {file}:{line}\n"
                if len(data) > 20:
                    gitleaks_summary += f"... and {len(data) - 20} more secrets.\n"
        except Exception as e:
            gitleaks_summary = f"Error parsing Gitleaks report: {e}\n"
    else:
        gitleaks_summary = "Gitleaks report not found or empty.\n"

    # Parse Trivy
    if os.path.exists(args.trivy):
        try:
            with open(args.trivy, "r", encoding="utf-8") as f:
                data = json.load(f)
                results = data.get("Results", [])
                vulnerabilities = []
                for r in results:
                    vulnerabilities.extend(r.get("Vulnerabilities", []))
                trivy_summary += f"Total Trivy FS vulnerabilities: {len(vulnerabilities)}\n"
                for i, v in enumerate(vulnerabilities[:20]):
                    vuln_id = v.get("VulnerabilityID", "")
                    pkg = v.get("PkgName", "")
                    installed = v.get("InstalledVersion", "")
                    severity = v.get("Severity", "")
                    title = v.get("Title", "")
                    trivy_summary += f"- [{severity}] {vuln_id} in {pkg}@{installed} - {title[:80]}\n"
                if len(vulnerabilities) > 20:
                    trivy_summary += f"... and {len(vulnerabilities) - 20} more vulnerabilities.\n"
        except Exception as e:
            trivy_summary = f"Error parsing Trivy report: {e}\n"
    else:
        trivy_summary = "Trivy report not found or empty.\n"

    # Parse Checkov
    if os.path.exists(args.checkov):
        try:
            tree = ET.parse(args.checkov)
            root = tree.getroot()
            testcases = root.findall(".//testcase")
            failures = []
            for tc in testcases:
                fail_el = tc.find("failure")
                if fail_el is not None:
                    failures.append({
                        "name": tc.get("name"),
                        "message": fail_el.get("message")
                    })
            checkov_summary += f"Total Checkov failures: {len(failures)}\n"
            for i, f in enumerate(failures[:20]):
                checkov_summary += f"- {f['name']}: {f['message']}\n"
            if len(failures) > 20:
                checkov_summary += f"... and {len(failures) - 20} more failures.\n"
        except Exception as e:
            checkov_summary = f"Error parsing Checkov report: {e}\n"
    else:
        checkov_summary = "Checkov report not found or empty.\n"

    # Prepare payload
    api_key = os.environ.get("ANTHROPIC_API_KEY")

    # Output template in case of failure/missing API Key
    dummy_advisory = f"""# RÉSUMÉ EXÉCUTIF
[WARN] AI SAST Triage analysis could not be generated dynamically (API key missing or request failed).
Here is the raw scan summary.

## Outils de sécurité - Raw Count
- **Semgrep SAST**: {semgrep_summary.splitlines()[0] if semgrep_summary else "N/A"}
- **Gitleaks Secrets**: {gitleaks_summary.splitlines()[0] if gitleaks_summary else "N/A"}
- **Trivy FS**: {trivy_summary.splitlines()[0] if trivy_summary else "N/A"}
- **Checkov IaC**: {checkov_summary.splitlines()[0] if checkov_summary else "N/A"}

## FINDINGS CRITIQUES
Veuillez examiner manuellement les rapports archivés dans les artefacts du pipeline Jenkins.

## FAUX POSITIFS PROBABLES
Non déterminés (Analyse IA désactivée).

## RECOMMANDATIONS
1. Configurer la clé `ANTHROPIC_API_KEY` dans le magasin de clés Jenkins (ID: 'anthropic-api-key').
2. Corriger en priorité les alertes de fuite de secrets de Gitleaks.
"""

    if not api_key:
        print("[WARN] ANTHROPIC_API_KEY not set. Generating fallback advisory.")
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(dummy_advisory)
        sys.exit(0)

    # Build prompts
    system_prompt = (
        "You are a senior DevSecOps expert specializing in application security auditing. "
        "Analyze the following security scan results for the application "
        f"context '{args.context}' and write a structured Markdown security advisory.\n"
        "Your advisory MUST contain the following four sections exactly (use them as H1/H2 headers):\n"
        "1. RÉSUMÉ EXÉCUTIF\n"
        "2. FINDINGS CRITIQUES\n"
        "3. FAUX POSITIFS PROBABLES\n"
        "4. RECOMMANDATIONS\n"
        "Be concise, technical, and prioritize business impact (e.g., focus on SQL injection, secret leaks, hardcoded credentials)."
    )

    user_content = f"""Application Context: {args.context}

--- SEMGREP SAST REPORT ---
{semgrep_summary}

--- GITLEAKS SECRETS REPORT ---
{gitleaks_summary}

--- TRIVY FS REPORT ---
{trivy_summary}

--- CHECKOV IAC REPORT ---
{checkov_summary}
"""

    try:
        url = "https://api.anthropic.com/v1/messages"
        headers = {
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
            "content-type": "application/json"
        }
        payload = {
            "model": args.model,
            "max_tokens": 4000,
            "system": system_prompt,
            "messages": [
                {"role": "user", "content": user_content}
            ]
        }
        req = urllib.request.Request(url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST")
        with urllib.request.urlopen(req, timeout=60) as response:
            resp_data = json.loads(response.read().decode("utf-8"))
            advisory_text = resp_data["content"][0]["text"]
            
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(advisory_text)
        print(f"[INFO] Advisory successfully written to {args.output}")
    except Exception as e:
        print(f"[WARN] Failed to call Anthropic API: {e}. Generating fallback advisory.")
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(dummy_advisory)
        sys.exit(0)

if __name__ == "__main__":
    main()
