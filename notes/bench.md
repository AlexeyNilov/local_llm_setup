# Benchmarking local LLM

## Using simple promt

```text
time llm "Explain why hash maps are usually O(1), in exactly 150 words."
```

### llama.cpp-linux-x86_64-vulkan-avx2-2.22.0

#### gemma-4-12B-agentic-fable5-composer2.5-v2-3.5x-tau2-GGUF/gemma4-v2-Q4_K_M.gguf

##### stack/llama_cpp/start_gemma.sh

```text
real	1m45.028s
user	0m1.200s
sys	0m0.152s
```

##### stack/llama_cpp/start_gemma_raw.sh

```text
real	3m45.938s
user	0m1.944s
sys	0m0.256s
```

#### gemma-4-12B-it-QAT-GGUF/gemma-4-12B-it-QAT-Q4_0.gguf

```text
real	3m43.915s
user	0m1.981s
sys	0m0.246s
```

## Using llama-bench

TBD
