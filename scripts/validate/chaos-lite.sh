#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="${OUT_FILE:-artifacts/validation/chaos-lite-proof.md}" \
  bash scripts/validate/validate-ha-chaos-lite.sh
