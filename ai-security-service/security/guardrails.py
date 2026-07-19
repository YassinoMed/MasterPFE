"""
Security Guardrails — Output Safety Enforcement.

Scans AI-generated responses for dangerous commands that could modify
infrastructure, execute arbitrary code, or delete resources.

No model output may bypass these guardrails without explicit validation.
"""

import re
import logging
from typing import Dict, Any, List

logger = logging.getLogger("ai-security-pipeline.guardrails")

# ── Forbidden Action Patterns ──────────────────────────────────
# These patterns detect commands that should never be executed without
# explicit human validation from a cluster administrator.

FORBIDDEN_PATTERNS: List[Dict[str, Any]] = [
    # Kubernetes mutations
    {"category": "kubernetes", "pattern": r"kubectl\s+(apply|delete|edit|patch|replace|scale|drain|cordon|uncordon|taint|label|annotate)\b"},
    {"category": "kubernetes", "pattern": r"kubectl\s+exec\s"},
    {"category": "kubernetes", "pattern": r"kubectl\s+run\b"},
    {"category": "kubernetes", "pattern": r"kubectl\s+cp\b"},
    {"category": "kubernetes", "pattern": r"kubectl\s+port-forward\b"},

    # Vault mutations
    {"category": "vault", "pattern": r"vault\s+(write|delete|seal|unseal|operator|auth|secrets|policy)\b"},

    # ArgoCD mutations
    {"category": "argocd", "pattern": r"argocd\s+app\s+(sync|delete|create|set|patch|rollback)\b"},
    {"category": "argocd", "pattern": r"argocd\s+repo\s+(add|remove)\b"},

    # Helm mutations
    {"category": "helm", "pattern": r"helm\s+(install|uninstall|upgrade|rollback|delete)\b"},

    # Terraform mutations
    {"category": "terraform", "pattern": r"terraform\s+(apply|destroy|import|state\s+(rm|mv|push))\b"},

    # Ansible execution
    {"category": "ansible", "pattern": r"ansible(-playbook)?\s"},

    # Docker mutations
    {"category": "docker", "pattern": r"docker\s+(rm|rmi|stop|kill|system\s+prune|volume\s+rm|network\s+rm)\b"},
    {"category": "docker", "pattern": r"docker\s+exec\b"},

    # System administration
    {"category": "system", "pattern": r"(systemctl|service)\s+(stop|restart|disable|mask|start|enable)\b"},
    {"category": "system", "pattern": r"(rm\s+-rf|rmdir|dd\s+if=|mkfs|fdisk|mount|umount)\b"},
    {"category": "system", "pattern": r"(chmod\s+[0-7]{3,4}|chown|chgrp)\s"},
    {"category": "system", "pattern": r"(iptables|nftables|firewall-cmd|ufw)\s"},
    {"category": "system", "pattern": r"(useradd|userdel|usermod|groupadd|groupdel)\b"},
    {"category": "system", "pattern": r"(passwd|shadow|sudoers)\b"},

    # Code execution
    {"category": "code_execution", "pattern": r"\b(eval|exec|compile|__import__|subprocess|os\.system|os\.popen)\s*\("},
    {"category": "code_execution", "pattern": r"\bimport\s+(subprocess|shlex|pty|socket|ctypes)\b"},
    {"category": "code_execution", "pattern": r"(curl|wget)\s+.*\|\s*(bash|sh|python|perl)"},
    {"category": "code_execution", "pattern": r"(python|python3|perl|ruby|node)\s+-[ec]\s"},

    # Network operations
    {"category": "network", "pattern": r"(nc|ncat|netcat)\s+(-[elp]|--listen)"},
    {"category": "network", "pattern": r"ssh\s+(-o|root@)"},
    {"category": "network", "pattern": r"(nmap|masscan|zmap)\s"},
]


def apply_guardrails(response_text: str) -> str:
    """
    Scan an AI-generated response for forbidden actions.

    If dangerous commands are detected, prepends a security warning
    requiring explicit human validation before execution.

    Args:
        response_text: The raw text from an expert AI agent.

    Returns:
        Safe response text (with warning header if needed).
    """
    violations = scan_response(response_text)

    if not violations:
        return response_text

    # Build detailed warning
    categories = sorted(set(v["category"] for v in violations))
    patterns = [v["match"] for v in violations]

    logger.warning(
        "Guardrails triggered: %d violations in categories %s",
        len(violations),
        categories,
    )

    warning = (
        "\n╔══════════════════════════════════════════════════════════════╗\n"
        "║            ⚠️  SECURITY GUARDRAIL ALERT  ⚠️                  ║\n"
        "╠══════════════════════════════════════════════════════════════╣\n"
        "║                                                            ║\n"
        "║  This response contains commands that modify infrastructure ║\n"
        "║  or cluster state. These actions CANNOT be executed         ║\n"
        "║  directly by the AI and require EXPLICIT MANUAL VALIDATION  ║\n"
        "║  by a cluster administrator.                               ║\n"
        "║                                                            ║\n"
        f"║  Violation categories: {', '.join(categories):<35}  ║\n"
        f"║  Total violations:     {len(violations):<35}  ║\n"
        "║                                                            ║\n"
        "╚══════════════════════════════════════════════════════════════╝\n\n"
    )

    return warning + response_text


def scan_response(response_text: str) -> List[Dict[str, str]]:
    """
    Scan response text for forbidden patterns.

    Returns:
        List of violation dicts with 'category' and 'match' keys.
    """
    violations = []
    response_lower = response_text.lower()

    for entry in FORBIDDEN_PATTERNS:
        matches = re.findall(entry["pattern"], response_lower)
        if matches:
            for match in matches:
                violations.append({
                    "category": entry["category"],
                    "match": match if isinstance(match, str) else match[0],
                })

    return violations


def validate_response(response_text: str) -> Dict[str, Any]:
    """
    Full validation report for a response.

    Returns:
        dict with keys:
            safe: bool
            violations: list of violation dicts
            categories: list of violated categories
    """
    violations = scan_response(response_text)
    return {
        "safe": len(violations) == 0,
        "violations": violations,
        "categories": sorted(set(v["category"] for v in violations)),
    }
