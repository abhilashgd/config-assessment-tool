#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${CAT_VENV_DIR:-$ROOT_DIR/.venv}"
PYTHON="$VENV_DIR/bin/python"
PIPENV="$VENV_DIR/bin/pipenv"

cd "$ROOT_DIR"

python_version=""
if [[ -x "$PYTHON" ]]; then
  python_version=$("$PYTHON" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
fi

if [[ "$python_version" != 3.12 ]]; then
  mkdir -p "$(dirname -- "$VENV_DIR")"
  if command -v uv >/dev/null 2>&1; then
    uv venv --clear --python 3.12 "$VENV_DIR"
  elif command -v python3.12 >/dev/null 2>&1; then
    python3.12 -m venv --clear "$VENV_DIR"
  else
    echo "Python 3.12 is required. Install uv or Python 3.12 and rerun this script." >&2
    exit 1
  fi
fi

if [[ ! -x "$PIPENV" ]]; then
  if command -v uv >/dev/null 2>&1; then
    uv pip install --python "$PYTHON" pipenv
  else
    "$PYTHON" -m pip install pipenv
  fi
fi

PIPENV_PYTHON="$PYTHON" \
PIPENV_VENV_IN_PROJECT=1 \
PIPENV_IGNORE_VIRTUALENVS=1 \
"$PIPENV" install --deploy --system

mkdir -p input/jobs input/thresholds logs output
export PYTHONPATH="$ROOT_DIR:$ROOT_DIR/backend${PYTHONPATH:+:$PYTHONPATH}"

if [[ $# -eq 0 || "$1" == "--ui" || "$1" == "--run" ]]; then
  port="${CAT_PORT:-8501}"
  host="${CAT_HOST:-127.0.0.1}"
  echo "Starting CAT UI at http://$host:$port"
  exec "$PYTHON" -m streamlit run "$ROOT_DIR/frontend/frontend.py" \
    --server.address "$host" \
    --server.port "$port" \
    --server.headless true
fi

exec "$PYTHON" "$ROOT_DIR/bin/bundle_main.py" "$@"
