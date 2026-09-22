# NVIDIA-NIM-CONSOLE

> High-performance terminal interface and orchestration console for local & cloud-hosted NVIDIA NIM microservices, featuring automated release gates via The Crucible and multi-model consensus via the AI Collaboration Council.

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![NVIDIA NIM](https://img.shields.io/badge/NVIDIA-NIM-76B900?logo=nvidia&logoColor=white)](#)
[![Python 3.10+](https://img.shields.io/badge/Python-3.10+-brightgreen.svg)](#)

---

## Features

- **NIM Direct API & Local Streaming**: Low-latency chat interface supporting nvidia/nemotron-3.5-lightning-30b-a3b.
- **Hardware-Optimized Local Offloading**: Built-in launcher tuned for RTX 5060 (8GB VRAM) + 32GB system RAM hybrid architectures.
- **Continuation-Resolution Memory**: Persistent session checkpoints and deterministic context window recovery across turns.
- **The Crucible & Council Gatekeeper**: Pre-push git hooks that execute Crucible release gates and query a multi-model AI Council (Gemini, Claude, GPT-4o, NIM).

---

## Quick Start

```bash
git clone https://github.com/jonathanblunt1214-lgtm/NVIDIA-NIM-CONSOLE.git
cd NVIDIA-NIM-CONSOLE
pip install -r requirements.txt
```
Launch the console using `Launch-NimConsole.bat`.
