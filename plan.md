# AI Triage System: Project Plan

This file holds the goal and the design. It changes rarely. For the next step and the
history of each session, read `session-log.md`.

**Last updated:** 2026-09-18

---

## Goal

Build a system that sorts customer support emails. An LLM reads each email and suggests a
category, a confidence score, and any risk flags. A set of fixed rules then decides what
happens next. The email either goes to the right team queue automatically, or it goes to a
person for review. Every step is saved to a database, so you can look back and see why each
decision was made.

The system is built to handle failure on purpose. When the LLM is unsure, when an email
carries a serious risk, or when a request costs too much, the system hands the email to a
person instead of guessing.

**Why it is worth building:** most AI agent demos only show the case where everything works.
This project shows how a system should behave when the model is wrong, slow, or unavailable.

**What "done" looks like:**
- A public GitHub repo with the n8n workflow, the database schema, and test cases.
- A short demo video that shows one email routed automatically and one escalated.
- A blog post titled "Building AI Systems That Know When Not to Act".

---

## Status at a glance

| Phase | What it covers | Status |
|---|---|---|
| 0 | Scope: problem, requirements, success criteria | Done |
| 1 | System design: architecture, data schema | Done |
| 2 | Reasoning layer: prompt, JSON output | Done |
| 3 | Policy layer: the fixed decision rules | Done |
| 4 | State: database tables | Done |
| 5 | Build the n8n workflow | **In progress.** 13 of about 32 nodes built |
| 6 | Metrics and monitoring | Not started |
| 7 | Failure testing | Not started |
| 8 | Deployment | Not started |
| 9 | Documentation | Not started |
| 10 | Portfolio: repo, blog post, demo video | Not started |

### Success criteria

- [x] The system takes in unstructured email text.
- [x] The LLM returns an intent and a confidence score.
- [x] The LLM sorts emails into 5 categories and adds risk flags.
- [x] The Policy Engine decides auto route or escalate from confidence and risk flags.
- [x] The request, the classification, and the routing decision are saved to the database.
- [x] A repeated email returns the saved result instead of running again.
- [ ] Emails are sent to a real queue or a person. Today the decision is only stored.
- [ ] Cost and latency checks use real numbers. Today they use fixed placeholder values.
- [ ] A full trace of each request is saved to the `traces` table.
- [ ] Escalated emails reach a person, e.g., through a Slack alert.
- [x] Bad LLM output escalates instead of crashing the workflow.
- [ ] An LLM that is down or times out is handled without crashing the workflow.
- [ ] A second model takes over when the main model fails.

### Horizons

**H1: working prototype.**
- [x] Database, n8n setup, and the first 6 nodes.
- [x] Policy Engine and database writes for classifications and routing decisions.
- [x] Duplicate check, and the workflow and schema saved in the repo.
- [ ] Trace logging.
- [ ] Demo video that shows one auto route and one escalation.

**H2: full system.**
- [ ] All 5 categories tested, with the failure modes below shown working.
- [ ] Failure test suite, circuit breaker, and duplicate handling.
- [ ] Metrics queries and alerts.
- [ ] Connection to a real inbox such as Gmail.
- [ ] GitHub repo with a technical README.

**H3: public artifacts.**
- [ ] Blog post with architecture diagrams and example traces.
- [ ] LinkedIn posts and a resume update.

---

## Design

### How a request flows

```
Email in (webhook) → Generate Metadata → Check Duplicate → (repeat: return saved result)
→ Store Request → Build Prompt →
LLM Classification → Policy Engine → Store Classification →
Store Routing Decision → (Trace Logging, not built) → Response
```

### Design principles

1. **The LLM suggests, the rules decide.** The model proposes a category. Fixed code decides
   the action.
2. **Neural plus fixed rules.** The model handles reading the email. Hard rules handle safety.
3. **Every decision can be inspected.** Each decision has a trace, and each failure has a log
   entry.
4. **Safety first.** Low confidence leads to escalation. A serious risk flag leads to human
   review. An exceeded budget stops automation.
5. **Failure is shown, not hidden.** The system handles each failure mode on purpose and the
   project demonstrates it.

### Stack

| Part | Tool | Notes |
|---|---|---|
| Orchestration | n8n in Docker | Runs at http://localhost:5678 |
| Database | Supabase (Postgres) | Connection pooler on port 6543 |
| Main LLM | Groq, `openai/gpt-oss-20b` | Since Session 4. OpenAI GPT-4o-mini was the original choice, and the OpenAI account has no credits left |
| Fallback LLM | None yet | See pending decision B in `session-log.md` |
| Alerts | Slack | Planned, not built |

### Data model

**requests** holds each incoming email and its status.
- `request_id` (primary key), `email_hash` (unique), `from_email`, `subject`, `body`, `status`.
- The unique hash is how duplicate emails are detected.

**classifications** holds what the LLM returned and how it performed.
- `intent`, `confidence`, `summary`, `risk_flags`, `reasoning`.
- `model_used`, `latency_ms`, `cost_usd`, `validation_success`.

**routing_decisions** holds what the Policy Engine decided and why.
- `decision` (auto_route or escalate), `destination`, `escalation_reason`,
  `escalation_priority`.
- `policies_evaluated`, `policies_passed`, `policies_failed`.

**traces** holds the full record of one request, for debugging. Not written to yet.
- `trace_id`, `steps` (jsonb), `total_latency_ms`, `total_cost_usd`, `success`.

**failure_log** holds each failure. The circuit breaker will read from it. Not written to yet.
- `failure_type`, `component`, `model_used`, `cost_impact_usd`.

A sixth table, `metrics_cache`, also exists in Supabase. The full schema, with every column,
constraint, index, and function, is in `database/schema.sql`.

### Categories

1. `billing_issue`: payment problems, subscription issues, invoice disputes.
2. `technical_issue`: product bugs, login problems, broken features.
3. `refund_request`: requests for money back, refunds after cancelling.
4. `legal_escalation`: legal threats, compliance concerns, GDPR or CCPA requests.
5. `unknown`: unclear, off topic, or not enough information.

### Risk flags

- `refund`: the customer asks for money back.
- `chargeback`: a card dispute or the bank is involved.
- `lawsuit`: the customer threatens legal action.
- `compliance`: GDPR, CCPA, a data breach, or another legal rule.
- `fraud`: suspected fraud.
- `outage`: the service is fully down.
- `data_loss`: the customer reports lost data.

### LLM output

```json
{
  "intent": "billing_issue",
  "confidence": 0.87,
  "summary": "Customer reports duplicate charge on subscription",
  "risk_flags": ["refund"],
  "reasoning": "Clear billing issue with refund request mentioned"
}
```

On the Groq path, the node returns this JSON as a text string, and nothing on the Groq side
enforces the format. OpenAI did enforce it, through structured outputs. So the Policy Engine
parses the text and checks every field itself before any rule runs. See check 0 below.

### Policy Engine

The rules run in this order. The first rule that fails stops the check and escalates the
email. The cheapest and most safety critical checks run first.

**Check 0: output shape.** Built in Session 5.
- The output must be a JSON object.
- `intent` must be one of the 5 categories.
- `confidence` must be a number from 0 to 1.
- `summary` and `reasoning` must be text.
- `risk_flags` must be a list, and every flag must be one of the 7 known flags.
- Any failure escalates with `invalid_llm_output` and priority high, and sets
  `validation_success` to false.

**Rule 1: critical risk flags.** Built.
- `lawsuit`, `compliance`, or `fraud` forces escalation, whatever the confidence.
- `refund` and `chargeback` are warnings only. `outage` and `data_loss` are for monitoring.

**Rule 2: budget.** Built, but it reads placeholder values.
- Cost above $0.10 per request leads to escalation and a warning.
- Latency above 15 seconds leads to escalation and a model switch.
- An exceeded daily budget stops automation. Not built.
- Cost and latency are fixed at $0.001 and 2000 ms for now, so this rule never fires.

**Rule 3: confidence threshold.** Built.
- Each intent has a minimum confidence. Below it, the email escalates.
- Thresholds: billing 0.75, technical 0.70, refund 0.80, legal 0.90.
- `unknown` has a threshold of 1.01 on purpose, so it always escalates.

**Rule 4: circuit breaker.** Not built.
- 3 or more failures in 60 minutes turn off automation.
- Automation stays off for a 30 minute cooldown and needs a manual check.

### Routing queues

| Intent | Queue | Priority | Response time target |
|---|---|---|---|
| billing_issue | billing_team_queue | Medium | 24h |
| technical_issue | support_tier1_queue | High | 4h |
| refund_request | billing_team_queue | Medium | 48h |
| legal_escalation | legal_team_queue | Critical | 2h |
| unknown | human_review_queue | Low | 72h |

### Failure modes the project will show

| Failure | What triggers it | What the system does | Built? |
|---|---|---|---|
| Bad LLM output | The model returns invalid JSON or a wrong value | Retry with the fallback model, escalate if both fail | Partly. It escalates, with no retry yet |
| Low confidence | Confidence is below the intent threshold | Escalate to human review | Yes |
| Serious risk flag | `lawsuit`, `compliance`, or `fraud` is present | Escalate with high priority | Yes |
| Over budget | Cost or latency is above the limit | Log a warning and escalate | Rule exists, uses placeholder values |
| Circuit breaker | 3 or more failures in 60 minutes | Turn off automation until a manual reset | No |
| Duplicate email | The email hash already exists | Return the saved result and skip processing | Yes |

---

## Test plan

So far 6 cases have been run by hand: normal cases 1, 2, 4, 5, and 6, and failure case 1.
The technical case used an email with an apostrophe.

**Normal cases (6)**
1. Clear billing issue. It auto routes to `billing_team_queue`.
2. Technical issue. It auto routes to `support_tier1_queue`.
3. Refund with a warning flag. It auto routes, since `refund` is not critical.
4. Legal email with a compliance flag. It escalates, since `compliance` is critical.
5. Unclear email. It escalates for low confidence.
6. Duplicate email. It returns the saved result.

**Failure cases (6)**
1. Bad LLM output. The fallback model runs, and the email escalates if both fail.
2. Confidence below the threshold. It escalates with a reason.
3. Cost over the limit. It escalates and logs a warning.
4. Latency over the limit. It escalates and switches model.
5. Circuit breaker trips. Automation turns off.
6. Critical risk flag. It forces escalation.

**Edge cases (4)**
1. Confidence exactly at the threshold. It auto routes, since the threshold is inclusive.
2. Several warning flags. It auto routes, since warnings do not escalate.
3. Empty email body. It is classified as `unknown` and escalates.
4. Email not in English. The model tries, and confidence is likely low.

---

## Risks

| Risk | Effect | Plan |
|---|---|---|
| The LLM provider is down or out of credit | The whole pipeline stops | Add a fallback model. This already happened once, with OpenAI in Session 4 |
| Costs grow with volume | Budget exceeded | Rate limits and budget alerts |
| Low classification accuracy | Wrong routing | Human review queue and a feedback loop |
| Database connection fails | State is lost | Retry logic. Note that Supabase pauses an idle free project |
| Prompt injection in an email | Wrong classifications | Clean the input and add rate limits |

---

## Deliverables

### Repo layout

```
ai-triage-system/
├── README.md (architecture and quickstart)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── FAILURE_MODES.md
│   └── DEPLOYMENT.md
├── workflows/
│   └── email-triage-main.json
├── database/
│   ├── schema.sql
│   └── migrations/
├── tests/
│   ├── test_cases.json
│   └── failure_injection.py
├── examples/
│   ├── traces/
│   └── classifications/
└── docker-compose.yml
```

### Blog post outline

**Title:** "Building AI Systems That Know When Not to Act"

1. The problem. Most AI demos assume success, and real systems need to plan for failure.
2. The main idea. A model without fixed rules around it is unsafe to automate.
3. The design. The model suggests and the rules decide.
4. The failure modes, shown working.
5. What worked, what did not, and what was surprising.
6. A walk through the key design decisions, with examples.

### Resume bullet

"Designed and deployed a failure-aware AI triage system embedding probabilistic language
models into deterministic control pipelines with explicit state, evaluation metrics, and
human-in-the-loop safeguards."

---

## How this lines up with research interests

| Research idea | Where it shows in the project |
|---|---|
| Reasoning kept apart from control | The LLM layer and the policy layer are separate |
| Neural plus fixed rules | The model classifies, hard rules act |
| Inspectability | Full traces, nothing hidden |
| Safety | Guardrails, escalation, circuit breaker |
| Failure awareness | Failures are handled on purpose |
| Evaluation | Metrics, test cases, failure injection |
