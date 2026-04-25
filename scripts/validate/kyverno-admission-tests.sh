#!/usr/bin/env bash

set -euo pipefail

APPLY_ENFORCE="${APPLY_ENFORCE:-false}" \
  bash scripts/validate/validate-kyverno-enforce.sh
