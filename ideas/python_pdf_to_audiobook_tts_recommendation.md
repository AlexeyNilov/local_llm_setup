# Python PDF To Audiobook TTS Recommendation

## Context

Goal: build a Python application that converts PDFs into English audiobooks using local models where practical.

Constraints:

- English only
- Python integration is required
- Local hardware: `AMD Ryzen 7 7800X3D`, about `61 GiB` RAM, about `16 GiB` VRAM
- Existing local LLM path uses Ollama

## Claim

For this use case, the best current TTS default is **Kokoro**.

## Why This Probably Holds Up

- English-only removes most of the value of heavier multilingual TTS systems.
- Python integration is a hard requirement, and Kokoro has a direct Python library path.
- The application is for audiobook generation, where natural long-form narration matters more than minimal runtime complexity.
- Piper is still a strong fallback, but it is a better answer to "simple and robust local TTS" than to "best English audiobook voice quality from Python."

## Recommended Stack

1. PDF text extraction
2. Text cleanup and normalization with Ollama
3. Chapter and paragraph chunking
4. TTS generation with Kokoro
5. Audio stitching and metadata packaging

## LLM Recommendation For The Text Stage

Use `qwen3:14b` in Ollama as the default model for:

- OCR cleanup
- removing headers, footers, and page artifacts
- converting tables/footnotes into speech-friendly text
- splitting text into TTS-safe chunks
- normalizing punctuation for narration

## TTS Ranking

1. **Kokoro**: best default for English audiobook generation from Python
2. **Piper**: best fallback if operational simplicity matters more than voice quality
3. **XTTS v2**: only worth the added complexity if voice cloning becomes a real requirement

## Minimal Architecture Sketch

- `extractor`: reads PDF text
- `cleaner`: uses Ollama to normalize text for speech
- `chunker`: splits text into chapter-safe and sentence-safe blocks
- `tts_backend`: calls Kokoro from Python
- `assembler`: combines WAV segments into chapter audio files

## What Is Still Uncertain

- Whether Kokoro remains stable and pleasant over very long chapter-length narration without manual chunk tuning
- Which specific English voice is best for audiobook listening rather than short samples
- Whether Piper is preferable in practice because of simpler packaging and fewer dependency edges

## Best Next Move

Build the first MVP around **Kokoro**, but define the Python TTS layer behind a small interface so **Piper** can be swapped in if Kokoro creates operational friction.
