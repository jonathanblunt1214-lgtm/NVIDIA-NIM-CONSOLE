# NVIDIA NIM Console — Nexus Integration Governing Plan

## Role

NVIDIA-NIM-CONSOLE is the prompt-based coding console at the front of the Nexus coding architecture. It is not a chatbot and does not replace AI Collaboration or The Crucible.

## Integration path

Nexus → NVIDIA-NIM-CONSOLE → AI-collaboration- (orchestration/council) → The-Crucible (validation/verification). Crucible learning remains behind its own worker, custody, and independent oversight boundaries.

## Required behavior

- Distinguish requested, executed, blocked, unverified, and verified work.
- Never report success solely because an AI provider answered.
- Never bypass Crucible checks to make a task appear complete.
- Never treat council agreement as execution authorization.
- Never write directly to vetted learning custody.
- Keep provider-specific routing behind AI Collaboration where the integration contract supports it.

## Plan

1. Document the exact console-to-AI-Collaboration entry points.
2. Document the exact console-to-Crucible gate entry points.
3. Verify prompt → orchestration → coding action → Crucible gate → evidence result.
4. Verify failure and continuation state handling.
5. Verify the console cannot claim completion before required Crucible verification.
6. Release only from a verified state compatible with the Nexus-wide architecture plan.