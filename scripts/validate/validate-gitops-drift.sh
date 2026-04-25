#!/usr/bin/env bash

set -euo pipefail

RUN_DRIFT_TEST="${RUN_DRIFT_TEST:-true}" \
  bash scripts/validate/validate-gitops-sync.sh
