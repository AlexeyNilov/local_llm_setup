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

### Results: 20260624-121325

Run metadata:

```text
backend=/home/lexa/Downloads/backends/llama-cpp-vulkan-full
build_commit=88636e178
build_number=9777
model=gemma-4-12B-it-QAT-Q4_0.gguf
device=Vulkan0
threads=8
repetitions=5
```

Environment looked clean enough for interpretation:

```text
Vulkan0: AMD Radeon RX 9060 XT (RADV GFX1200) (16304 MiB, 15640 MiB free)
rocm-smi: VRAM 4%, GPU 0% before the run
```

Baseline:

```text
512 prompt tokens:        1264 tok/s
128 generated tokens:       38.4 tok/s
512 prompt + 128 gen:      167.6 tok/s combined
```

Workload shape matters:

| case | combined tok/s | avg time |
|---|---:|---:|
| 128 prompt + 128 gen | 73.8 | 3.47 s |
| 512 prompt + 128 gen | 167.6 | 3.82 s |
| 2048 prompt + 128 gen | 419.9 | 5.18 s |
| 4096 prompt + 256 gen | 415.6 | 10.47 s |

Interpretation: generation is the limiting phase for short interactive prompts.
The combined tok/s number rises with longer prompts because prompt processing is
much faster than token generation.

Parameter findings:

| variant | combined tok/s | result |
|---|---:|---|
| `-b 1024 -ub 256` | 167.3 | no meaningful win |
| `-b 2048 -ub 512` | 167.3-167.6 | keep this default |
| `-b 4096 -ub 512` | 167.3 | no meaningful win |
| `-b 4096 -ub 1024` | 167.4 | no meaningful win |
| KV `f16/f16` | 167.4 | best/neutral |
| KV `q8_0/q8_0` | 164.1 | slower, about -2% |
| KV `q4_0/q4_0` | 164.1 | slower, about -2% |
| flash attention `on` | 167.3 | keep enabled |
| flash attention `auto` | 167.5 | effectively same as on |
| flash attention `off` | 162.8 | slower, about -3% |
| CPU-only offload | 36.5 | much slower |
| GPU offload | 167.5 | required for useful speed |

Current best settings for `start_gemma.sh`:

```text
--n-gpu-layers all
--threads 8
--threads-batch 8
--batch-size 2048
--ubatch-size 512
--cache-type-k f16
--cache-type-v f16
--mmap
-fa on
```

No benchmarked change justifies moving away from those defaults. The useful
optimization was not batch/cache tuning; it was making sure the server runs on
the discrete GPU with full offload and enough free VRAM.

Limits of this run:

- It does not test server concurrency, `--parallel`, prompt caching, or
  `--cache-reuse`.
- It does not directly test `--ctx-size`; larger context mainly increases KV
  memory pressure and can still hurt real server capacity.
- It benchmarks raw llama.cpp execution, not full client/server latency through
  the OpenAI-compatible API.

### MTP Server Test

Use the server benchmark for MTP. `llama-bench` does not expose the relevant
speculative decoding flags, and the useful question is end-to-end server
latency.

Script:

```sh
stack/llama_cpp/bench_gemma_server.sh
```

Dry-run:

```sh
stack/llama_cpp/bench_gemma_server.sh dry-run
```

Run:

```sh
stack/llama_cpp/bench_gemma_server.sh run
```

The script starts two temporary servers on port `12346`:

- baseline: normal Gemma server
- mtp: same settings plus `--spec-type draft-mtp`

It writes results under:

```text
bench/server-results/YYYYMMDD-HHMMSS/
```

The summary files are:

```text
summary.csv
summary.md
```

Decision rule: promote MTP only if generation throughput improves by at least
15%, wall time improves on medium/coding cases, output quality is not visibly
worse, and VRAM headroom remains acceptable. If the gain is under 10%, leave
MTP off by default.

### Results: MTP Server Test 20260624-130453

Run metadata:

```text
backend=/home/lexa/Downloads/backends/llama-cpp-vulkan-full
model=gemma-4-12B-it-qat-UD-Q4_K_XL.gguf
mtp_model=mtp-gemma-4-12B-it.gguf
port=12346
repetitions=3
```

Timing summary:

| case | baseline wall | mtp wall | wall change | baseline gen tok/s | mtp gen tok/s | gen change |
|---|---:|---:|---:|---:|---:|---:|
| short | 3.369 s | 1.398 s | -58.5% | 39.50 | 101.05 | +155.8% |
| medium | 6.665 s | 2.541 s | -61.9% | 39.26 | 107.16 | +173.0% |
| long | 6.725 s | 3.240 s | -51.8% | 39.19 | 84.56 | +115.7% |
| coding | 13.340 s | 5.976 s | -55.2% | 38.96 | 88.67 | +127.6% |

MTP is clearly faster on this server benchmark. The MTP server log also confirms
high draft acceptance:

```text
short:  draft acceptance = 0.83621, mean acceptance length = 4.34
medium: draft acceptance = 0.88839, mean acceptance length = 4.55
long:   draft acceptance = 0.65248, mean acceptance length = 3.59
coding: draft acceptance = 0.70019, mean acceptance length = 3.79
```

Important caveat: this benchmark used `/completion` with raw prompts, and the
generated outputs were visibly degenerate/repetitive for both baseline and MTP.
That means this run is valid as a speed A/B test, but not as an answer-quality
test. Before enabling MTP by default, run a second quality/latency check through
the chat endpoint or through the same OpenAI-compatible client used in normal
workflows.

Provisional decision: MTP is worth enabling behind an opt-in flag now. Promote it
to the default only after the chat-endpoint test shows comparable output quality.
