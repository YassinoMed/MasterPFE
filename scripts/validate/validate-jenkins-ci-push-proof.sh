#!/usr/bin/env bash

set -euo pipefail

OUT_FILE="${OUT_FILE:-artifacts/validation/jenkins-ci-push-proof.md}" \
  bash scripts/jenkins/verify-ci-push-trigger.sh
