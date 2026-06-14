# Exportateur Prometheus pour Wazuh
#
# Interroge l'API Wazuh et expose le nombre d'agents actifs/totaux.

import os
import time
import requests
import urllib3
from prometheus_client import Gauge, start_http_server

# Définition des métriques
wazuh_agents_active = Gauge(
    "wazuh_agents_active",
    "Nombre d'agents Wazuh actifs."
)
wazuh_agents_total = Gauge(
    "wazuh_agents_total",
    "Nombre total d'agents Wazuh enregistres."
)

WAZUH_URL = os.getenv("WAZUH_URL", "https://localhost:55000")
WAZUH_USER = os.getenv("WAZUH_USER", "admin")
WAZUH_PASSWORD = os.getenv("WAZUH_PASSWORD", "SecretPassword")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "60"))
PORT = int(os.getenv("PORT", "9200"))

# Configuration de la validation des certificats SSL/TLS
WAZUH_VERIFY_SSL = os.getenv("WAZUH_VERIFY_SSL", "true")
if WAZUH_VERIFY_SSL.lower() in ("false", "0"):
    VERIFY_SSL = False
    urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)
elif WAZUH_VERIFY_SSL.lower() in ("true", "1"):
    VERIFY_SSL = True
else:
    VERIFY_SSL = WAZUH_VERIFY_SSL


def get_token() -> str:
    """Authentifie et recupere le jeton JWT de l'API Wazuh."""
    url = f"{WAZUH_URL}/security/user/authenticate"
    res = requests.post(
        url,
        auth=(WAZUH_USER, WAZUH_PASSWORD),
        verify=VERIFY_SSL,
        timeout=10
    )
    res.raise_for_status()
    return str(res.json()["data"]["token"])


def collect_metrics(token: str) -> None:
    """Interroge l'API pour extraire les statistiques des agents."""
    headers = {"Authorization": f"Bearer {token}"}

    # Récupération des agents actifs
    res_active = requests.get(
        f"{WAZUH_URL}/agents?status=active",
        headers=headers,
        verify=VERIFY_SSL,
        timeout=10
    )
    res_active.raise_for_status()
    active_count = res_active.json()["data"]["totalItems"]
    wazuh_agents_active.set(active_count)

    # Récupération du total des agents
    res_total = requests.get(
        f"{WAZUH_URL}/agents",
        headers=headers,
        verify=VERIFY_SSL,
        timeout=10
    )
    res_total.raise_for_status()
    total_count = res_total.json()["data"]["totalItems"]
    wazuh_agents_total.set(total_count)


def main() -> None:
    """Boucle principale de collecte."""
    start_http_server(PORT)
    print(f"Exporteur Wazuh demarre sur le port {PORT}...")

    token = None
    while True:
        try:
            if not token:
                token = get_token()
            collect_metrics(token)
        except requests.exceptions.HTTPError as err:
            if err.response is not None and err.response.status_code == 401:
                # Token expiré, tentative de renouvellement au prochain cycle
                token = None
            print(f"Erreur HTTP lors de la collecte : {err}")
        except Exception as err:
            print(f"Erreur lors de la collecte : {err}")

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
