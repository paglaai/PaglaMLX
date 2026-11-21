<p align="center">
  <a href="https://github.com/paglaai/PaglaMLX">
    <img src="https://raw.githubusercontent.com/paglaai/PaglaMLX/main/brand/paglamlx-wordmark.svg" alt="PaglaMLX Wordmark" width="460">
  </a>
</p>

<p align="center">
  <strong>Bare-Metal Apple Silicon LLM Inference Runtime, Quantized Kernel Execution, and Unified Memory Server.</strong>
</p>

<p align="center">
  <a href="https://www.paglaai.space/products/paglamlx.html"><img src="https://img.shields.io/badge/Docs_Portal-PaglaMLX-6B7EFF?style=flat-square" alt="Docs Portal"></a>
  <a href="https://github.com/paglaai/PaglaMLX/actions"><img src="https://img.shields.io/badge/Metal_Acceleration-Apple_Silicon-0A0A0B?style=flat-square&logo=apple" alt="Apple Silicon"></a>
  <a href="https://github.com/paglaai/PaglaMLX/releases"><img src="https://img.shields.io/badge/version-2.2.0-0A0A0B?style=flat-square" alt="Version 2.2.0"></a>
  <a href="https://github.com/paglaai/PaglaDESIGN"><img src="https://img.shields.io/badge/DesignDNA-Locked_(D--024)-0A0A0B?style=flat-square" alt="DesignDNA Locked"></a>
  <a href="./LICENSE"><img src="https://img.shields.io/badge/license-MIT-0A0A0B?style=flat-square" alt="License MIT"></a>
</p>

---

## Overview

**PaglaMLX** is the bare-metal machine learning inference engine for the PaglaAI ecosystem. Purpose-built for Apple Silicon hardware, PaglaMLX drives 4-bit and 8-bit quantized large language models directly on Apple Metal GPU cores with zero network latency and a strict, hardware-enforced **16GB Unified Memory ceiling**.

It exposes a high-throughput, OpenAI-compatible REST and Server-Sent Events (SSE) server for local agent orchestration.

```
                 ┌────────────────────────────────────────┐
                 │       PaglaMLX Inference Server        │
                 │   Apple Silicon M-Series Unified RAM   │
                 └───────────────────┬────────────────────┘
                                     │
         ┌───────────────────────────┴───────────────────────────┐
         ▼                                                       ▼
┌──────────────────────────────┐              ┌──────────────────────────────┐
│     Metal GPU Pipelines      │              │    Memory Budget Monitor     │
│   4-bit / 8-bit Quantized    │              │   Strict 16GB RAM Ceiling    │
└──────────────┬───────────────┘              └──────────────────────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────────────────────┐
│                    OpenAI-Compatible Streaming Service                     │
│           POST /v1/chat/completions (SSE)  •  GET /v1/models               │
└────────────────────────────────────────────────────────────────────────────┘
```

## Core Capabilities

- **Runs Metal-Native Inference**: Direct dispatch to Apple Silicon GPU cores via Apple MLX, bypassing bloated virtualization and heavy containers.
- **Enforces 16GB Memory Ceiling**: Implements aggressive context pruning and KV-cache quantization to guarantee continuous stability on unified memory.
- **Streams at Wire Speed**: Sub-millisecond time-to-first-token (TTFT) with high-density SSE streaming compatible with any OpenAI client library.
- **Swaps Quantized Weights**: Seamlessly mounts and unmounts 4-bit AWQ/GGUF/MLX model checkpoints dynamically without restarting the server.

## Quick Start

Launch local Apple Silicon inference in two commands:

```bash
# Install dependencies
pip install -r requirements.txt

# Start the local OpenAI-compatible inference server
python3 -m paglamlx.server --model qwen-7b-4bit --port 8080
```

Query the server with standard cURL:

```bash
curl http://localhost:8080/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-7b-4bit",
    "messages": [{"role": "user", "content": "Explain unified memory architecture."}],
    "stream": true
  }'
```

## Architecture & Tech Stack

| Component | Specification |
| :--- | :--- |
| **Compute Core** | Apple MLX C++ & Metal Performance Shaders (MPS) |
| **Quantization** | 4-bit / 8-bit affine group quantization |
| **API Protocol** | OpenAI HTTP / Server-Sent Events (SSE) spec |
| **Memory Ceiling** | 16 GB Unified Memory (M2/M3 Pro architecture target) |

## DesignDNA & Ecosystem Authority

PaglaMLX adheres strictly to the operational doctrine established in [PaglaDESIGN](https://github.com/paglaai/PaglaDESIGN). All terminal interfaces, log streams, and diagnostic outputs match the canonical monospace hierarchy and obsidian branding.

## Security & Fail-Closed Policy

- **Air-Gapped Sovereign Execution**: Zero telemetry calls, zero remote model downloads during production runtime.
- **Localhost Boundary**: Binds exclusively to `127.0.0.1` by default to prevent unauthorized network bridging.

${ecosystemDirectory}

${emailSection}

## License

PaglaMLX is open-source software licensed under the **[MIT License](./LICENSE)**.

---

<p align="center">
  <sub>© 2026 AYNAGHOR. PaglaMLX is part of the PaglaAI ecosystem. Every surface inherits from here.</sub>
</p>
