#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="${OUT_FILE:-artifacts/validation/jenkins-webhook-proof.md}" \
  bash scripts/jenkins/validate-github-webhook.sh
