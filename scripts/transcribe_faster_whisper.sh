#!/usr/bin/env bash
set -euo pipefail

AUDIO_PATH="${1:-}"
if [[ -z "$AUDIO_PATH" || ! -f "$AUDIO_PATH" ]]; then
  echo "ERROR: Audio file not found."
  exit 2
fi

PYTHON_BIN="${PYTHON:-python3}"
"$PYTHON_BIN" - "$AUDIO_PATH" <<'PY'
import os
import sys

audio_path = sys.argv[1]

try:
    from faster_whisper import WhisperModel
except Exception:
    print("ERROR: faster-whisper is not installed. Run: python3 -m pip install --user faster-whisper")
    sys.exit(3)

model_name = os.environ.get("JOBMAXXING_WHISPER_MODEL", "base.en")
device = os.environ.get("JOBMAXXING_WHISPER_DEVICE", "auto")
compute_type = os.environ.get("JOBMAXXING_WHISPER_COMPUTE", "int8")

try:
    model = WhisperModel(model_name, device=device, compute_type=compute_type)
    segments, _ = model.transcribe(audio_path, beam_size=1, vad_filter=True)
    text = " ".join(segment.text.strip() for segment in segments).strip()
    print(text)
except Exception as error:
    print(f"ERROR: faster-whisper transcription failed: {error}")
    sys.exit(4)
PY
