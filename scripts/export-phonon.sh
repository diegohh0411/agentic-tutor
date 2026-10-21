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
repository_root="$(cd "$script_dir/.." && pwd -P)"
app_directory="$repository_root/AgenticTutor"
output_directory="$app_directory/PhononModels"

if [[ -L "$app_directory" ]]; then
  echo "Refusing to export: AgenticTutor must not be a symlink." >&2
  exit 1
fi

if [[ -L "$output_directory" ]]; then
  echo "Refusing to export: AgenticTutor/PhononModels must not be a symlink." >&2
  exit 1
fi

mkdir -p "$output_directory"

if [[ -L "$output_directory" ]]; then
  echo "Refusing to export: AgenticTutor/PhononModels must not be a symlink." >&2
  exit 1
fi

output_directory="$(cd "$output_directory" && pwd -P)"
case "$output_directory/" in
  "$repository_root/"*) ;;
  *)
    echo "Refusing to export: output directory must be inside the repository." >&2
    exit 1
    ;;
esac

temporary_directory="$(mktemp -d "${TMPDIR:-/tmp}/xn-ptts.XXXXXX")"

cleanup() {
  rm -rf "$temporary_directory"
}
trap cleanup EXIT

git clone --depth 1 --branch v0.4.0 https://github.com/gradium-ai/xn-ptts.git "$temporary_directory/xn-ptts"

export_arguments=(--model hf://gradium/phonon-40m-multilingual)
if [[ -n "${PHONON_VOICE_IDS:-}" ]]; then
  voices_directory="$temporary_directory/voices"
  read -r -a voice_ids <<< "$PHONON_VOICE_IDS"
  mkdir -p "$voices_directory"

  for voice_id in "${voice_ids[@]}"; do
    if [[ ! "$voice_id" =~ ^[A-Za-z0-9_-]+$ ]]; then
      echo "Invalid PHONON_VOICE_IDS entry: $voice_id" >&2
      exit 1
    fi

    curl -fsSL -H "Authorization: Bearer $HF_TOKEN" \
      "https://huggingface.co/gradium/phonon-voices/resolve/main/voices/$voice_id.safetensors" \
      -o "$voices_directory/$voice_id.safetensors"
  done

  export_arguments+=(--voices "$voices_directory")
fi

cd "$temporary_directory/xn-ptts"
# In xn-ptts v0.4.0, the export destination is the positional `out` argument.
cargo run --release -p ptts --example export_coreml --features hub -- \
  "${export_arguments[@]}" \
  "$output_directory"
