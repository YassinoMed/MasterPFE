#!/usr/bin/env python3
import os
import re
import sys
import json
import uuid
import datetime
import argparse

def load_exclusions(path):
    exclusions = []
    if not os.path.exists(path):
        print(f"[WARN] Exclusions file not found: {path}")
        return exclusions
    
    current = {}
    cve_re = re.compile(r"cve_id:\s*\"?([^\"]+)\"?")
    just_re = re.compile(r"justification:\s*\"?([^\"]+)\"?")
    status_re = re.compile(r"status:\s*\"?([^\"]+)\"?")
    impact_re = re.compile(r"impact_statement:\s*\"?([^\"]+)\"?")

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("- cve_id:") or line.startswith("cve_id:"):
                if current:
                    exclusions.append(current)
                    current = {}
                m = cve_re.search(line)
                if m:
                    current["cve_id"] = m.group(1)
            elif "justification:" in line:
                m = just_re.search(line)
                if m:
                    current["justification"] = m.group(1)
            elif "status:" in line:
                m = status_re.search(line)
                if m:
                    current["status"] = m.group(1)
            elif "impact_statement:" in line:
                m = impact_re.search(line)
                if m:
                    current["impact_statement"] = m.group(1)

    if current:
        exclusions.append(current)
    return exclusions

def main():
    parser = argparse.ArgumentParser(description="Generate CycloneDX VEX JSON document")
    parser.add_argument("--sbom-dir", required=True, help="Directory containing SBOM and Grype files")
    parser.add_argument("--context", required=True, help="Application context name")
    parser.add_argument("--output", required=True, help="Output VEX JSON file path")
    parser.add_argument("--exclusions-file", default="security/vex/vex-exclusions.yaml", help="Path to exclusions YAML")

    args = parser.parse_args()

    exclusions = load_exclusions(args.exclusions_file)
    exclusions_map = {ex["cve_id"]: ex for ex in exclusions}

    # Group affects list by CVE ID
    vex_vulns = {}

    # Look for CycloneDX files
    if os.path.exists(args.sbom-dir):
        # Scan directories for *.cyclonedx.json or *-sbom.cdx.json
        files = os.listdir(args.sbom_dir)
        sbom_files = [f for f in files if f.endswith(".cyclonedx.json") or f.endswith("-sbom.cdx.json")]
        
        for sf in sbom_files:
            sbom_path = os.path.join(args.sbom_dir, sf)
            grype_path = sbom_path + ".grype.json"
            
            # Load SBOM
            components_map = {}
            try:
                with open(sbom_path, "r", encoding="utf-8") as f:
                    sbom_data = json.load(f)
                    for comp in sbom_data.get("components", []):
                        bom_ref = comp.get("bom-ref")
                        purl = comp.get("purl")
                        name = comp.get("name")
                        version = comp.get("version")
                        if bom_ref:
                            components_map[(name, version)] = bom_ref
                            if purl:
                                components_map[purl] = bom_ref
            except Exception as e:
                print(f"[WARN] Error loading SBOM {sbom_path}: {e}")
                continue

            # Load Grype report
            if os.path.exists(grype_path):
                try:
                    with open(grype_path, "r", encoding="utf-8") as f:
                        grype_data = json.load(f)
                        matches = grype_data.get("matches", [])
                        for match in matches:
                            vuln = match.get("vulnerability", {})
                            cve_id = vuln.get("id")
                            if cve_id in exclusions_map:
                                # Find matching component ref
                                artifact = match.get("artifact", {})
                                name = artifact.get("name")
                                version = artifact.get("version")
                                purl = artifact.get("purl")
                                
                                ref = components_map.get(purl) or components_map.get((name, version)) or purl or name
                                
                                if cve_id not in vex_vulns:
                                    ex = exclusions_map[cve_id]
                                    vex_vulns[cve_id] = {
                                        "id": cve_id,
                                        "analysis": {
                                            "state": ex.get("status", "not_affected"),
                                            "justification": ex.get("justification", "code_not_present"),
                                            "detail": ex.get("impact_statement", "")
                                        },
                                        "affects": []
                                    }
                                
                                # Add to affects if not already present
                                if ref and not any(x.get("ref") == ref for x in vex_vulns[cve_id]["affects"]):
                                    vex_vulns[cve_id]["affects"].append({"ref": ref})
                except Exception as e:
                    print(f"[WARN] Error parsing Grype report {grype_path}: {e}")

    # Build final VEX document
    vex_doc = {
        "bomFormat": "CycloneDX",
        "specVersion": "1.5",
        "serialNumber": f"urn:uuid:{uuid.uuid4()}",
        "version": 1,
        "metadata": {
            "timestamp": datetime.datetime.utcnow().replace(tzinfo=datetime.timezone.utc).isoformat(),
            "component": {
                "type": "application",
                "name": args.context
            }
        },
        "vulnerabilities": list(vex_vulns.values())
    }

    # Ensure output dir exists
    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(vex_doc, f, indent=2, sort_keys=True)
        f.write("\n")
    
    print(f"[INFO] CycloneDX VEX 1.5 generated successfully at {args.output}")

if __name__ == "__main__":
    main()
