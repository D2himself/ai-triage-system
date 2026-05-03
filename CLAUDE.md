# Failure-Aware Triage (ai-triage-system) — Project Context

*Read this before doing any work in this repo.*

---

## Goal

A hybrid triage system that routes tasks through either an LLM path or a
deterministic rules/policy path. Orchestrated with n8n. "Failure-aware" means
the system handles LLM path failures or low-confidence outputs by falling back
to deterministic logic.

---

## Stack

- LLM path: OpenAI + Groq
- Orchestration: n8n
- Rules layer: TBD
- Package management: uv

---

## Current State

| Component | Status |
|-----------|--------|
| LLM path | ✅ Complete |
| Policy / rules layer | ❌ Not yet implemented (design TBD) |
| n8n nodes (partial) | 🔄 In progress — remaining nodes to complete |
| End-to-end integration | Not started |

---

## Blocker

None. Clear path forward.

---

## Immediate Next Steps

1. Design and implement the policy/rules layer
2. Complete remaining n8n nodes
3. Wire end-to-end and test

---

## Key Files

[Update as project develops — no code exists yet, this is a placeholder]

---

## Context for Agents

- This is Kemi's secondary project — unblocked, but lower priority than Hop-Specialist.
- LLM path is done. Don't touch it unless debugging.
- Rules layer design is open — propose options and let Kemi decide before implementing.
- Check `~/life-os/context/active-projects.md` for latest state before starting work.
