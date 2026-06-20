#!/usr/bin/env python3
import os
import sys
import glob
import json
import argparse
import subprocess
import urllib.request
import urllib.error

# Default baseline sizes in bytes for drift detection
BASELINE_SIZES = {
    "auth-users": 150 * 1024 * 1024,
    "chatbot-manager": 250 * 1024 * 1024,
    "conversation-service": 180 * 1024 * 1024,
    "audit-security-service": 160 * 1024 * 1024,
    "portal-web": 300 * 1024 * 1024
}

def get_current_image_size(image_ref):
    try:
        res = subprocess.run(
            ["docker", "image", "inspect", image_ref, "--format", "{{.Size}}"],
            capture_output=True, text=True, check=True
        )
        return int(res.stdout.strip())
    except Exception:
        return None

def parse_trivy_report(filepath):
    vulnerabilities = []
    if not os.path.exists(filepath):
        return vulnerabilities
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
            results = data.get("Results", [])
            for r in results:
                for v in r.get("Vulnerabilities", []):
                    vulnerabilities.append({
                        "id": v.get("VulnerabilityID"),
                        "pkg": v.get("PkgName"),
                        "severity": v.get("Severity"),
                        "installed": v.get("InstalledVersion"),
                        "fixed": v.get("FixedVersion", "N/A"),
                        "title": v.get("Title", "")
                    })
    except Exception as e:
        print(f"[WARN] Failed to parse Trivy report {filepath}: {e}")
    return vulnerabilities

def main():
    parser = argparse.ArgumentParser(description="AI Image Auditor")
    parser.add_argument("--trivy-reports", required=True, help="Glob pattern for Trivy reports")
    parser.add_argument("--sbom-dir", required=True, help="Directory containing SBOM CycloneDX files")
    parser.add_argument("--registry", required=True, help="Target registry")
    parser.add_argument("--image-prefix", required=True, help="OCI image prefix")
    parser.add_argument("--image-tag", required=True, help="OCI image tag")
    parser.add_argument("--output", required=True, help="Output markdown advisory path")
    parser.add_argument("--context", required=True, help="Business analysis context")
    parser.add_argument("--model", default="claude-sonnet-4-6", help="Model name to use")

    args = parser.parse_args()

    # Find reports
    report_files = glob.glob(args.trivy_reports)
    trivy_summary = {}
    for rf in report_files:
        service_name = os.path.basename(rf).replace("trivy-image-", "").replace(".json", "")
        vulns = parse_trivy_report(rf)
        trivy_summary[service_name] = vulns

    # Read SBOM component counts
    sbom_files = glob.glob(os.path.join(args.sbom_dir, "*.json"))
    sbom_summary = {}
    for sf in sbom_files:
        service_name = os.path.basename(sf).replace("-sbom.cdx.json", "").replace("-sbom.json", "")
        try:
            with open(sf, "r", encoding="utf-8") as f:
                sbom_data = json.load(f)
                comp_count = len(sbom_data.get("components", []))
                sbom_summary[service_name] = comp_count
        except Exception as e:
            sbom_summary[service_name] = f"Error: {e}"

    # Calculate image sizes and check drift
    drift_summary = {}
    services = ["auth-users", "chatbot-manager", "conversation-service", "audit-security-service", "portal-web"]
    for svc in services:
        image_ref = f"{args.registry}/{args.image_prefix}-{svc}:{args.image_tag}"
        curr_size = get_current_image_size(image_ref)
        baseline = BASELINE_SIZES.get(svc)
        
        if curr_size is not None and baseline is not None:
            diff = curr_size - baseline
            diff_pct = (diff / baseline) * 100
            drift_summary[svc] = {
                "size_mib": round(curr_size / (1024 * 1024), 2),
                "baseline_mib": round(baseline / (1024 * 1024), 2),
                "diff_mib": round(diff / (1024 * 1024), 2),
                "diff_pct": round(diff_pct, 2),
                "status": "DRIFT_DETECTED" if diff_pct > 5 else "OK"
            }
        elif curr_size is not None:
            drift_summary[svc] = {
                "size_mib": round(curr_size / (1024 * 1024), 2),
                "baseline_mib": "N/A",
                "diff_mib": "N/A",
                "diff_pct": "N/A",
                "status": "NO_BASELINE"
            }
        else:
            drift_summary[svc] = {
                "size_mib": "N/A",
                "baseline_mib": "N/A",
                "diff_mib": "N/A",
                "diff_pct": "N/A",
                "status": "IMAGE_NOT_FOUND"
            }

    # Format summaries for AI prompt
    trivy_formatted = ""
    for svc, vulns in trivy_summary.items():
        trivy_formatted += f"Service: {svc} - Total Vulns: {len(vulns)}\n"
        for v in vulns[:10]:
            trivy_formatted += f"  - [{v['severity']}] {v['id']} in {v['pkg']} (installed: {v['installed']}, fixed: {v['fixed']}) - {v['title'][:60]}\n"
        if len(vulns) > 10:
            trivy_formatted += f"  - ... and {len(vulns)-10} more\n"

    sbom_formatted = ""
    for svc, count in sbom_summary.items():
        sbom_formatted += f"- {svc}: {count} CycloneDX components\n"

    drift_formatted = ""
    for svc, info in drift_summary.items():
        drift_formatted += f"- {svc}: size={info['size_mib']} MiB, baseline={info['baseline_mib']} MiB, diff={info['diff_mib']} MiB ({info['diff_pct']}%), status={info['status']}\n"

    api_key = os.environ.get("ANTHROPIC_API_KEY")

    dummy_advisory = f"""# RÉSUMÉ
[WARN] AI Image Auditor analysis could not be generated dynamically (API key missing or request failed).
Here is the raw image security summary.

## Outils de sécurité - Raw Count & Drift
### SBOM Component Count
{sbom_formatted}

### Image Size Drift
{drift_formatted}

## CVE CRITIQUES PAR SERVICE
Veuillez examiner manuellement les rapports Trivy Image archivés dans les artefacts du pipeline.

## DRIFT DÉTECTÉ
Non déterminé (Analyse IA désactivée).

## RECOMMANDATIONS
1. Configurer la clé `ANTHROPIC_API_KEY` dans le magasin de clés Jenkins (ID: 'anthropic-api-key').
2. Prioriser les vulnérabilités affectant `auth-users` et `portal-web`.
"""

    if not api_key:
        print("[WARN] ANTHROPIC_API_KEY not set. Generating fallback advisory.")
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(dummy_advisory)
        sys.exit(0)

    # Build prompts
    system_prompt = (
        "You are a senior DevSecOps expert specializing in container image auditing and supply chain validation.\n"
        "Analyze the following OCI image scans and SBOM summaries, perform prioritization of risks based on application context, "
        "and draft a structured Markdown image security advisory.\n"
        "Your advisory MUST contain the following four sections exactly (use them as H1/H2 headers):\n"
        "1. RÉSUMÉ\n"
        "2. CVE CRITIQUES PAR SERVICE\n"
        "3. DRIFT DÉTECTÉ\n"
        "4. RECOMMANDATIONS\n"
        "Focus heavily on risk prioritization (auth-users service should be highest priority) and analyze any significant image size changes."
    )

    user_content = f"""Context: {args.context}

--- TRIVY IMAGE VULNERABILITIES ---
{trivy_formatted}

--- SBOM COMPONENT COUNT ---
{sbom_formatted}

--- IMAGE DRIFT DETAILS ---
{drift_formatted}
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
        print(f"[INFO] Image advisory written to {args.output}")
    except Exception as e:
        print(f"[WARN] Failed to call Anthropic API: {e}. Generating fallback advisory.")
        os.makedirs(os.path.dirname(args.output), exist_ok=True)
        with open(args.output, "w", encoding="utf-8") as f:
            f.write(dummy_advisory)
        sys.exit(0)

if __name__ == "__main__":
    main()
