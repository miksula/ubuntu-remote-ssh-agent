#!/usr/bin/env bash
set -euo pipefail

USAGE="Usage: $0 [--upstream URL] [--branch BRANCH] [--project-dir DIR] [--clone-dir DIR] [--non-interactive]\n
Options:\n  --upstream URL       Supabase repository URL (default: https://github.com/supabase/supabase)\n  --branch BRANCH      Git branch or tag to clone (default: master)\n  --project-dir DIR    Destination project directory (default: supabase-project)\n  --clone-dir DIR      Local clone directory for upstream source (default: supabase)\n  --non-interactive    Forward to scripts/generate_supabase_env.sh\n  --help               Show this help message\n"

UPSTREAM_URL="https://github.com/supabase/supabase"
BRANCH="master"
PROJECT_DIR="supabase-project"
CLONE_DIR="supabase"
NONINTERACTIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --upstream)
      UPSTREAM_URL="$2"; shift 2;;
    --branch)
      BRANCH="$2"; shift 2;;
    --project-dir)
      PROJECT_DIR="$2"; shift 2;;
    --clone-dir)
      CLONE_DIR="$2"; shift 2;;
    --non-interactive)
      NONINTERACTIVE=1; shift;;
    --help|-h)
      printf "%b" "$USAGE"
      exit 0;;
    *)
      echo "Unknown option: $1" >&2
      printf "%b" "$USAGE"
      exit 1;;
  esac
done

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_ROOT/.." && pwd)"

cd "$REPO_ROOT"

clone_source() {
  if [[ -d "$CLONE_DIR/.git" ]]; then
    echo "Using existing upstream source at '$CLONE_DIR'."
    return
  fi

  echo "Cloning Supabase upstream from $UPSTREAM_URL (branch: $BRANCH) into $CLONE_DIR..."
  git clone --depth 1 --branch "$BRANCH" "$UPSTREAM_URL" "$CLONE_DIR"
}

prepare_project_dir() {
  if [[ -e "$PROJECT_DIR" && ! -d "$PROJECT_DIR" ]]; then
    echo "ERROR: project path exists and is not a directory: $PROJECT_DIR" >&2
    exit 1
  fi

  mkdir -p "$PROJECT_DIR"
  echo "Copying Supabase docker files into $PROJECT_DIR..."
  cp -r "$CLONE_DIR/docker/"* "$PROJECT_DIR/"

  if [[ ! -f "$CLONE_DIR/docker/.env.example" ]]; then
    echo "ERROR: expected upstream .env.example not found: $CLONE_DIR/docker/.env.example" >&2
    exit 1
  fi

  cp -f "$CLONE_DIR/docker/.env.example" "$PROJECT_DIR/.env"
}

patch_env() {
  echo "Patching $PROJECT_DIR/.env using scripts/generate_supabase_env.sh..."
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    "$SCRIPT_ROOT/generate_supabase_env.sh" --non-interactive --base-env "$PROJECT_DIR/.env" --output "$PROJECT_DIR/.env"
  else
    "$SCRIPT_ROOT/generate_supabase_env.sh" --base-env "$PROJECT_DIR/.env" --output "$PROJECT_DIR/.env"
  fi
}

generate_keys() {
  echo "Generating Supabase auth/internal keys in $PROJECT_DIR..."
  pushd "$PROJECT_DIR" >/dev/null
  if [[ ! -x ./utils/generate-keys.sh && -f ./utils/generate-keys.sh ]]; then
    chmod +x ./utils/generate-keys.sh
  fi
  sh ./utils/generate-keys.sh
  popd >/dev/null
}

main() {
  clone_source
  prepare_project_dir
  patch_env
  generate_keys

  echo "\nPartial Supabase setup complete."
  echo "Next steps:"
  echo "  1) Review $PROJECT_DIR/.env and keep it private." 
  echo "  2) Configure host-managed Caddy to proxy your SUPABASE_PUBLIC_URL to 127.0.0.1:8000." 
  echo "  3) Start the stack from $PROJECT_DIR: docker compose pull && docker compose up -d"
}

main
