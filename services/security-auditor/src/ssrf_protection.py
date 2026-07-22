"""
SSRF Protection Helper for Python Services.
Provides URL validation, Cloud Metadata blocking, host whitelisting, and disables redirects.
"""

import urllib.parse
from typing import List

ALLOWED_HOSTS: List[str] = [
    "localhost",
    "127.0.0.1",
    "::1",
    "ollama",
    "qdrant",
    "auth-users",
    "chatbot-manager",
    "conversation-service",
    "audit-security-service",
    "portal-web",
    "postgres",
    "redis"
]

BLOCKED_PREFIXES: List[str] = [
    "169.254.",      # AWS Link-Local / IMDS
    "100.64.",       # CGNAT
    "0."
]


def validate_target_url(url: str) -> str:
    """
    Validate target URL against SSRF vulnerabilities.
    
    Raises ValueError if URL is malformed, targets metadata IPs, or is not in allowed hosts whitelist.
    """
    parsed = urllib.parse.urlparse(url)
    if not parsed.netloc:
        raise ValueError(f"SSRF Protection: Invalid URL structure: {url}")
    
    host = parsed.hostname.lower() if parsed.hostname else ""
    
    # Block cloud metadata addresses
    if host in ["169.254.169.254", "metadata.google.internal", "instance-data"]:
        raise ValueError(f"SSRF Protection: Access to cloud metadata service is forbidden ({host}).")
    
    for prefix in BLOCKED_PREFIXES:
        if host.startswith(prefix):
            raise ValueError(f"SSRF Protection: Target IP prefix is blocked ({host}).")
    
    # Allow K8s cluster services or whitelisted hosts
    is_whitelisted = False
    if host.endswith(".svc.cluster.local") or host.endswith(".securerag-hub.svc"):
        is_whitelisted = True
    else:
        for allowed in ALLOWED_HOSTS:
            if host == allowed or host.endswith("." + allowed):
                is_whitelisted = True
                break
    
    if not is_whitelisted:
        raise ValueError(f"SSRF Protection: Host '{host}' is not in the allowed internal whitelist.")
    
    return url


def get_safe_httpx_client_options() -> dict:
    """
    Returns httpx Client configuration with follow_redirects=False to prevent SSRF bypass.
    """
    return {
        "follow_redirects": False,
        "timeout": 10.0,
        "verify": True
    }
