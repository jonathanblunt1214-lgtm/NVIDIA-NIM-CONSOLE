# NVIDIA-NIM-CONSOLE

> High-performance terminal interface and orchestration console for local & cloud-hosted NVIDIA NIM microservices, featuring automated release gates via The Crucible and multi-model consensus via the AI Collaboration Council.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NVIDIA NIM](https://img.shields.io/badge/NVIDIA-NIM-76B900?logo=nvidia&logoColor=white)](#)
[![Python 3.10+](https://img.shields.io/badge/Python-3.10+-brightgreen.svg)](#)

---

## ⚡ Features

- **NIM Direct API & Local Streaming**: Low-latency streaming chat interface supporting `meta/llama-3.1-70b-instruct`, `nvidia/nemotron-3.5-lightning-30b-a3b`, and specialized microservices.
- **Hardware-Optimized Local Offloading**: Built-in launcher for Nemotron 3.5 MoE with hybrid GPU layer offloading (tuned for 8GB VRAM + system RAM architectures).
- **Continuation-Resolution Memory**: Persistent session checkpoints and deterministic context window recovery across turns.
- **The Crucible & Council Gatekeeper**: Pre-push git hooks that execute Crucible release gates and query a multi-model AI Council (Gemini, Claude, GPT-4o, NIM) before committing changes.

---

## 🛠️ Quick Start

### 1. Clone & Setup
```bash
git clone [https://github.com/jonathanblunt1214-lgtm/NVIDIA-NIM-CONSOLE.git](https://github.com/jonathanblunt1214-lgtm/NVIDIA-NIM-CONSOLE.git)
cd NVIDIA-NIM-CONSOLE
pip install -r requirements.txt