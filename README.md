# Failure-Aware AI Triage System

A hybrid AI–deterministic system for triaging customer support emails. Combines probabilistic language model classification with explicit deterministic policies for control, safety, and inspectable reasoning.

> **Design principle**: Reasoning ≠ control. The LLM proposes; the policy engine decides.

---

## Why this project exists

Most "AI agent" demos optimize for the happy path. Production systems fail — silently, weirdly, expensively. This project is built around that failure: every decision has a trace, every failure has a log, and the system explicitly demonstrates the conditions under which it cannot be trusted to act alone.

It is a study in:

- **Probabilistic + symbolic reasoning** — neural models for understanding, hard rules for safety
- **Inspectability** — full audit trail of why each decision was made
- **Failure as a feature** — escalation paths, circuit breakers, budget enforcement
- **Human-in-the-loop safeguards** — low confidence, critical risk flags, and budget overruns trigger human review

---

## Architecture

```
Email Input
    │
    ▼
┌─────────────────┐
│  Webhook        │ ← n8n trigger
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  Metadata       │ ← request_id + email_hash (duplicate detection)
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  Persist State  │ ← Supabase (Postgres)
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  LLM Classify   │ ← OpenAI GPT-4o-mini, JSON Schema structured output
└─────────────────┘
    │
    ▼
┌─────────────────┐
│  Policy Engine  │ ← deterministic: confidence, risk flags, budget
└─────────────────┘
    │
    ├──► auto-route ──► routing queue
    │
    └──► escalate  ──► human review queue
```

---

## Stack

| Layer | Tool |
|-------|------|
| Orchestration | n8n (self-hosted via Docker) |
| State | Supabase (managed Postgres) |
| LLM | OpenAI GPT-4o-mini (structured outputs) |
| Policy layer | JavaScript (n8n Code node) |

---

## Classification Schema

The LLM returns structured JSON conforming to:

```json
{
  "intent": "billing_issue | technical_issue | refund_request | legal_escalation | unknown",
  "confidence": 0.0-1.0,
  "summary": "string",
  "risk_flags": ["refund", "chargeback", "lawsuit", "compliance", "fraud", "outage", "data_loss"],
  "reasoning": "string"
}
```

## Policy Rules

The policy engine applies three deterministic checks, in order:

1. **Critical risk flags** — `lawsuit`, `compliance`, `fraud` → force escalate (overrides any confidence)
2. **Budget enforcement** — cost > $0.10 or latency > 15s → escalate
3. **Confidence thresholds** — per-intent minimums; below threshold → escalate
   - billing: 0.75 · technical: 0.70 · refund: 0.80 · legal: 0.90 · unknown: always escalate

---

## Status

🚧 **In active development** — Phase 5 of 10 (Execution & Integration)

See [`plan.md`](./plan.md) for the full project plan and [`session-log.md`](./session-log.md) for build progress.

---

## Local Setup

> Requires Docker, a Supabase project, and an OpenAI API key.

```bash
# 1. Clone
git clone https://github.com/<your-username>/ai-triage-system.git
cd ai-triage-system

# 2. Configure
cp .env.example .env
# Edit .env with your Supabase + OpenAI credentials

# 3. Start n8n
docker compose up -d

# 4. Open n8n UI
open http://localhost:5678
```

---

## License

MIT — see [LICENSE](./LICENSE).
