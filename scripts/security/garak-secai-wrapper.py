#!/usr/bin/env python3
"""Wrapper garak — scan RÉEL du LLM déployé (Ollama qwen2.5-0.5b).

Garak 0.17 ignore l'option `uri` via --generator_options (bug de merge
de config) : on patche DEFAULT_PARAMS AVANT le chargement du plugin,
ce qui force l'URI sur notre port-forward.
"""
import sys

# ── Patch AVANT l'import de garak.cli ──────────────────────────────
from garak.generators.openai import OpenAICompatible

TARGET_URI = "http://127.0.0.1:11499/v1/"
OpenAICompatible.DEFAULT_PARAMS["uri"] = TARGET_URI
OpenAICompatible.URI_CONNECT_TIMEOUT = 10.0

import os
os.environ.setdefault("OPENAICOMPATIBLE_API_KEY", "ollama-noauth")

from garak import cli

sys.exit(cli.main(sys.argv[1:]))
