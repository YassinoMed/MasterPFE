import json
import re
from app.schemas import SecurityEventInput

def sanitize_payload(payload: dict) -> dict:
    """
    SOC2 CRITICAL: Removes PII and secrets from the JSON payload.
    """
    payload_str = json.dumps(payload)
    
    # Redact JWTs
    payload_str = re.sub(r'eyJ[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+', '[REDACTED_JWT]', payload_str)
    # Redact Emails
    payload_str = re.sub(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', '[REDACTED_EMAIL]', payload_str)
    # Redact IP addresses (basic regex)
    payload_str = re.sub(r'\b(?:\d{1,3}\.){3}\d{1,3}\b', '[REDACTED_IP]', payload_str)
    # Redact passwords/tokens if key matches
    sanitized_dict = json.loads(payload_str)
    
    def recursive_redact(d):
        for k, v in d.items():
            if isinstance(v, dict):
                recursive_redact(v)
            elif isinstance(k, str) and any(sub in k.lower() for sub in ['password', 'token', 'secret']):
                d[k] = '[REDACTED_SECRET]'
                
    recursive_redact(sanitized_dict)
    return sanitized_dict

def sanitize_event(event: SecurityEventInput) -> SecurityEventInput:
    event.payload = sanitize_payload(event.payload)
    return event
