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
│  LLM Classify   │ ← Groq gpt-oss-20b, strict JSON schema, temperature 0
└─────────────────┘         └── on failure → gpt-oss-120b (fallback model)
    │
    ▼
┌─────────────────┐
│  Policy Engine  │ ← deterministic: output check, risk flags, budget, confidence
└─────────────────┘
    │
    ├──► auto-route ──► routing queue
    │
    └──► escalate  ──► human review queue ──► Slack alert
    │
    ▼
┌─────────────────┐
│  Persist + Trace│ ← classification, routing decision, full run trace
└─────────────────┘
```

A repeated email is detected by its hash before the model is called, and the saved decision is returned instead.

---

## Stack

| Layer | Tool |
|-------|------|
| Orchestration | n8n (self-hosted via Docker) |
| State | Supabase (managed Postgres) |
| LLM | Groq `openai/gpt-oss-20b`, strict JSON schema, temperature 0 |
| Fallback LLM | Groq `openai/gpt-oss-120b`, used only when the first call fails |
| Policy layer | JavaScript (n8n Code node) |
| Alerts | Slack incoming webhook |

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

The policy engine applies four deterministic checks, in order. The first failure escalates the email and the rest are skipped.

0. **Output check** — the answer must be JSON with a known intent, a confidence from 0 to 1, and known risk flags. A wrong answer escalates as `invalid_llm_output`, and no answer at all escalates as `llm_unavailable`. The raw answer is saved either way.
1. **Critical risk flags** — `lawsuit`, `compliance`, `fraud` → force escalate (overrides any confidence)
2. **Budget enforcement** — cost > $0.10 or latency > 15s → escalate. Both are measured from the real call, and cost comes from the token counts
3. **Confidence thresholds** — per-intent minimums; below threshold → escalate
   - billing: 0.75 · technical: 0.70 · refund: 0.80 · legal: 0.90 · unknown: always escalate

---

## Status

🚧 **In active development** — Phase 5 of 10 (Execution & Integration)

Working end to end today: email intake, duplicate detection, classification with a fallback model, the four policy checks, persistence of the request, classification, routing decision and a full trace, and a Slack alert for every escalation.

Not built yet: pushing routed emails to a real queue, metrics and monitoring, a circuit breaker, and handling Groq's rate limit of 8000 tokens a minute.

The build notes are kept privately for now, and will be published when the system is finished.

---

## Local Setup

> Requires Docker, a Supabase project, and a Groq API key.

```bash
# 1. Clone
git clone https://github.com/D2himself/ai-triage-system.git
cd ai-triage-system

# 2. Configure
cp .env.example .env
# Edit .env with your Supabase credentials, and SLACK_WEBHOOK_URL if you want alerts.
# The Groq credential is set inside n8n, not in .env.

# 3. Start n8n
docker compose up -d

# 4. Open n8n UI
open http://localhost:5678

# 5. Load the schema into your Supabase project, then import the workflow
#    from workflows/email-triage-main.json in the n8n UI.
```

---

## License

MIT — see [LICENSE](./LICENSE).
