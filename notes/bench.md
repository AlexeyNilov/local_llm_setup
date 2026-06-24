# Benchmarking local LLM

## Using simple promt

```text
time llm "Explain why hash maps are usually O(1), in exactly 150 words."
```

### llama.cpp-linux-x86_64-vulkan-avx2-2.22.0

#### gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF/gemma4-v2-Q4_K_M.gguf

```text
real	1m45.028s
user	0m1.200s
sys	0m0.152s
```

#### gemma-4-12B-it-QAT-GGUF/gemma-4-12B-it-QAT-Q4_0.gguf

```text
real	3m43.915s
user	0m1.981s
sys	0m0.246s
```

### llama-cpp-vulkan-full

#### gemma-4-12B-it-QAT-GGUF/gemma-4-12B-it-QAT-Q4_0.gguf

```text
real	3m46.065s
user	0m2.022s
sys	0m0.226s
```

## Using llama-bench

Use `llama-bench` for controlled measurements. The simple `time llm ...`
checks above are useful smoke tests, but they mix server state, client overhead,
prompt format, cache reuse, and current GPU load. Treat them as observations,
not conclusions.

### Benchmark wrapper

The wrapper is:

```sh
stack/llama_cpp/bench_gemma.sh
```

It uses:

```text
/home/lexa/Downloads/backends/llama-cpp-vulkan-full/llama-bench
```

and writes results under:

```text
bench/results/YYYYMMDD-HHMMSS/
```

Do not run the benchmark while `llama-gemma.service`, LM Studio, or another
GPU-heavy workload is active. If VRAM or GPU utilization is already high, the
numbers are contaminated.

### Preflight

Check whether the benchmark binary can see the Vulkan device:

```sh
stack/llama_cpp/bench_gemma.sh devices
```

If this reports no devices, the Vulkan benchmark is not measuring the same path
as the server. Fix that before interpreting any performance numbers.

Observed preflight on 2026-06-24 after freeing VRAM:

```text
load_backend: loaded RPC backend from /home/lexa/Downloads/backends/llama-cpp-vulkan-full/libggml-rpc.so
WARNING: radv is not a conformant Vulkan implementation, testing use only.
ggml_vulkan: Found 2 Vulkan devices:
ggml_vulkan: 0 = AMD Radeon RX 9060 XT (RADV GFX1200) (radv) | uma: 0 | fp16: 1 | bf16: 1 | warp size: 64 | shared memory: 65536 | int dot: 1 | matrix cores: KHR_coopmat
ggml_vulkan: 1 = AMD Radeon Graphics (RADV RAPHAEL_MENDOCINO) (radv) | uma: 1 | fp16: 1 | bf16: 0 | warp size: 32 | shared memory: 65536 | int dot: 1 | matrix cores: none
load_backend: loaded Vulkan backend from /home/lexa/Downloads/backends/llama-cpp-vulkan-full/libggml-vulkan.so
load_backend: loaded CPU backend from /home/lexa/Downloads/backends/llama-cpp-vulkan-full/libggml-cpu-zen4.so
Available devices:
  Vulkan0: AMD Radeon RX 9060 XT (RADV GFX1200) (16304 MiB, 15640 MiB free)
  Vulkan1: AMD Radeon Graphics (RADV RAPHAEL_MENDOCINO) (32215 MiB, 32185 MiB free)
```

Readiness judgment:

- Ready: `Vulkan0` now has `15640 MiB free`, enough for a clean Gemma 12B Q4 benchmark.
- Ready: dry-run command expansion succeeds.
- Important: the wrapper pins benchmark runs to `Vulkan0` with `-dev Vulkan0` so the integrated GPU does not pollute the result.
- Remaining caveat: keep the desktop and other GPU workloads quiet during the run, because benchmark validity depends on stable GPU load and available VRAM.

Review the planned commands without running them:

```sh
stack/llama_cpp/bench_gemma.sh dry-run
```

### Run

Stop the running server first:

```sh
systemctl --user stop llama-gemma.service
```

Then run:

```sh
stack/llama_cpp/bench_gemma.sh run
```

The script records:

- `metadata.env`
- `devices.txt`
- `rocm-smi.txt`
- `git-status.txt`
- `commands.txt`
- one JSONL result file per benchmark case

### What the cases test

The suite starts with a baseline close to the tuned server settings:

```text
-t 8 -dev Vulkan0 -ngl 999 -fa on -b 2048 -ub 512 -ctk f16 -ctv f16 -pg 512,128
```

Then it varies one axis at a time:

- prompt/generation workload: `128,128`, `512,128`, `2048,128`, `4096,256`
- KV cache type: `f16/f16`, `q8_0/q8_0`, `q4_0/q4_0`
- batch and ubatch size: `1024/256`, `2048/512`, `4096/512`, `4096/1024`
- flash attention: `on`, `auto`, `off`
- offload sanity: CPU-only versus GPU offload

### Interpretation

For interactive use, prefer the setting with the best token generation rate
for realistic prompt sizes, not just the best prompt processing rate. A high
prompt-processing number with weak generation speed is the wrong optimization
for chat and coding workflows.

The CPU-only and GPU-offload cases are a sanity check. If GPU offload is not
clearly faster than CPU-only, the backend/device path is probably wrong or the
GPU is already resource constrained.
