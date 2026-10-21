#!/usr/bin/env bash

set -euo pipefail

if [[ -z "${HF_TOKEN:-}" ]]; then
  echo "HF_TOKEN is required. Use a Hugging Face token from an account that accepted the phonon-40m-multilingual terms." >&2
  exit 1
fi

if ! command -v cargo >/dev/null 2>&1; then
  echo "cargo is required to export Phonon Core ML models." >&2
  exit 1
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repository_root="$(cd "$script_dir/.." && pwd)"
output_directory="$repository_root/AgenticTutor/PhononModels"
temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/xn-ptts.XXXXXX")"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

git clone --depth 1 --branch v0.4.0 https://github.com/gradium-ai/xn-ptts.git "$temporary_directory/xn-ptts"
mkdir -p "$output_directory"

cd "$temporary_directory/xn-ptts"
# In xn-ptts v0.4.0, the export destination is the positional `out` argument.
cargo run --release -p ptts --example export_coreml --features hub -- \
  --model hf://gradium/phonon-40m-multilingual \
  "$output_directory"
