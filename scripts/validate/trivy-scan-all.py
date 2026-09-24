#!/usr/bin/env python3
import json
import sys

for s in ["portal-web", "auth-users", "chatbot-manager", "conversation-service", "audit-security-service"]:
    import subprocess
    out = subprocess.run([
        "docker", "run", "--rm", "--network", "host",
        "-v", "/var/run/docker.sock:/var/run/docker.sock",
        "aquasec/trivy:latest", "image", "--format", "json",
        f"localhost:5001/securerag-hub-{s}:dev"
    ], capture_output=True, text=True, timeout=300).stdout
    d = json.loads(out)
    crit=hi=med=lo=0
    pkgs=set()
    for r in d.get("Results", []):
        for v in r.get("Vulnerabilities") or []:
            sev=(v.get("Severity") or "").upper()
            pkgs.add(v["PkgName"]+"@"+(v.get("InstalledVersion") or ""))
            if sev=="CRITICAL": crit+=1
            elif sev=="HIGH": hi+=1
            elif sev=="MEDIUM": med+=1
            elif sev=="LOW": lo+=1
    high_pkgs=[v["PkgName"] for r in d.get("Results",[]) for v in (r.get("Vulnerabilities") or []) if v.get("Severity")=="HIGH"]
    print(f"{s}: CRITICAL={crit} HIGH={hi} MEDIUM={med} LOW={lo}")
    if high_pkgs:   print(f"   HIGH packages: {sorted(set(high_pkgs))}")
