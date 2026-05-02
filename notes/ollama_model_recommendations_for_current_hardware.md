# Ollama Model Recommendations For Current Hardware

## Observations

- Host CPU: `AMD Ryzen 7 7800X3D`
- System memory: `61 GiB`
- Discrete GPU VRAM detected: about `16 GiB`
- The GPU device appears to match a very recent AMD Radeon class card. Current Ollama hardware docs list `Radeon RX 9060 XT` as supported on Linux via `ROCm v7`.

## Claim

There is no single model that is simultaneously optimal for chat, coding, and research. On this hardware, the practical sweet spot is roughly `12B` to `14B` models, with some `24B` models usable if slower inference is acceptable.

## Best Current Judgment

- **Best single all-rounder:** `qwen3:14b`
- **Best coding-first model:** `devstral:24b`
- **Best reasoning / research-first model:** `deepseek-r1:14b`
- **Best if vision matters:** `gemma3:12b`

## Why This Holds Up

- `qwen3:14b` is the best balance candidate for mixed use. It is small enough to fit comfortably while still being strong enough for general chat, coding help, and synthesis.
- `devstral:24b` is the strongest coding-specific recommendation because it is explicitly positioned for software engineering and tool-oriented work. The tradeoff is speed.
- `deepseek-r1:14b` is a better fit when "research" means multi-step reasoning, structured comparison, and deliberate synthesis rather than quick interaction.
- `gemma3:12b` is the useful exception because it supports image input, which matters if research includes screenshots, diagrams, or document images.

## What Is Probably Not Optimal

These may run, but they are weak candidates for a daily-driver setup on this machine because they push beyond the comfortable VRAM budget:

- `qwen3:30b`
- `deepseek-r1:32b`
- `gemma3:27b`

The issue is not whether they can be forced to run. The issue is whether they remain fast and convenient enough to be the default choice.

## Suggested Default Set

- `qwen3:14b` as the default general model
- `devstral:24b` for coding sessions
- `deepseek-r1:14b` for hard reasoning
- `gemma3:12b` only when image input is useful

## Suggested Pull Commands

```bash
ollama pull qwen3:14b
ollama pull devstral:24b
ollama pull deepseek-r1:14b
ollama pull gemma3:12b
```

## Caveat

This recommendation depends on the AMD GPU path actually working well with Ollama on Linux. The central risk is not RAM capacity; it is ROCm and driver support quality on a very recent AMD card. If GPU acceleration is unstable, the optimal model size drops and the recommendation should be revisited.

## Sources

- Ollama hardware support: <https://docs.ollama.com/gpu>
- Qwen3 library page: <https://ollama.com/library/qwen3>
- Devstral library page: <https://ollama.com/library/devstral>
- DeepSeek-R1 library page: <https://ollama.com/library/deepseek-r1>
- Gemma 3 library page: <https://ollama.com/library/gemma3>
