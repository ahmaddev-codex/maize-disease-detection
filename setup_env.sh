#!/usr/bin/env bash
# setup_env.sh — create and activate a Python 3.11 virtual environment
# TF 2.16 supports Python 3.9–3.12; this project pins 3.11 (what .venv and the
# notebook kernel use).
set -e

PYTHON=${PYTHON:-python3.11}
ENV_DIR=".venv"

echo "==> Creating virtual environment with $PYTHON ..."
$PYTHON -m venv $ENV_DIR

echo "==> Activating virtual environment ..."
source $ENV_DIR/bin/activate

echo "==> Upgrading pip ..."
pip install --upgrade pip

echo "==> Installing dependencies ..."
pip install -r requirements.txt

echo ""
echo "Done! Activate your environment with:"
echo "  source $ENV_DIR/bin/activate"
