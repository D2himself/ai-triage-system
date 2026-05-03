# AI Triage System — Project Plan

## Project Identity

**Name**: Failure-Aware AI Triage System for Real-World Operations

**One-Line Description**: A hybrid AI–deterministic system that triages customer support emails using probabilistic reasoning, explicit control policies, persistent state, and safety guardrails — with full traceability and failure handling.

**Why This Matters**: Most "AI agent" demos ignore failure. This system is designed around uncertainty, demonstrating research-grade thinking about control, safety, and inspectable reasoning.

---

## System Architecture

### Core Pattern: Trigger → State → Reason → Decide → Act

```
Email Input → Generate Metadata → Store Request → 
Build Prompt → LLM Classification → Policy Decision → 
Route/Escalate → Store Results → Trace Logging → Response
```

### Key Design Principles

1. **Reasoning ≠ Control**: LLM proposes classifications; deterministic policy decides actions
2. **Probabilistic + Symbolic**: Neural models for understanding + hard rules for safety
3. **Inspectability**: Every decision has a trace; every failure has a log
4. **Safety First**: Low confidence → escalate; Risk flags → human review; Budget exceeded → halt
5. **Failure as Feature**: System explicitly handles and demonstrates failure modes

---

## Technical Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Orchestration | n8n (Docker) | Workflow execution and visual debugging |
| Database | Supabase (Postgres) | State persistence, audit logs, metrics |
| Primary LLM | OpenAI GPT-4o-mini | Email classification with structured outputs |
| Fallback LLM | OpenAI GPT-3.5-turbo | Backup if primary fails |
| Integration | Slack / Email / Webhook | Action execution (routing, escalations) |
| Monitoring | Built-in (Postgres queries) | Real-time metrics and system health |

---

## Data Model

### Core Tables

**requests**: Incoming email data + status tracking
- `request_id` (PK), `email_hash` (unique), `from_email`, `subject`, `body`, `status`
- Enables duplicate detection, request tracking, audit trail

**classifications**: LLM reasoning outputs + performance metrics
- `intent`, `confidence`, `summary`, `risk_flags`, `reasoning`
- `model_used`, `latency_ms`, `cost_usd`, `validation_success`
- Tracks what the AI thought and how well it performed

**routing_decisions**: Policy engine outputs
- `decision` (auto_route | escalate), `destination`, `escalation_reason`, `escalation_priority`
- `policies_evaluated`, `policies_passed`, `policies_failed`
- Records why each routing decision was made

**traces**: Full execution traces for debugging
- `trace_id`, `steps` (JSONB), `total_latency_ms`, `total_cost_usd`, `success`
- Enables post-mortem analysis and system optimization

**failure_log**: Dedicated failure tracking
- `failure_type`, `component`, `model_used`, `cost_impact_usd`
- Powers circuit breaker and system reliability monitoring

---

## Classification System

### Categories (5)

1. **billing_issue**: Payment problems, subscription issues, invoice disputes
2. **technical_issue**: Product bugs, login problems, feature malfunctions
3. **refund_request**: Money back requests, cancellation refunds
4. **legal_escalation**: Legal threats, compliance concerns, GDPR/CCPA requests
5. **unknown**: Ambiguous, off-topic, insufficient information

### Risk Flags (7)

- `refund`: Customer explicitly requests money back
- `chargeback`: Credit card dispute or bank involvement
- `lawsuit`: Legal action threatened
- `compliance`: GDPR, CCPA, data breach, regulatory concern
- `fraud`: Suspected fraudulent activity
- `outage`: Service completely unavailable
- `data_loss`: Customer reports lost data

### Structured Output (JSON Schema)

```json
{
  "intent": "billing_issue",
  "confidence": 0.87,
  "summary": "Customer reports duplicate charge on subscription",
  "risk_flags": ["refund"],
  "reasoning": "Clear billing issue with refund request mentioned"
}
```

---

## Policy Engine

### Decision Rules (Deterministic)

**Rule 1: Confidence Threshold**
- Each intent has minimum confidence requirement
- Below threshold → escalate to human review
- Thresholds: billing (0.75), technical (0.70), refund (0.80), legal (0.90)

**Rule 2: Risk Flag Check**
- Auto-escalate flags: lawsuit, compliance, fraud
- Warning flags: refund, chargeback
- Monitor flags: outage, data_loss

**Rule 3: Budget Enforcement**
- Cost per request > $0.10 → escalate + log warning
- Latency > 15 seconds → escalate + switch model
- Daily budget exceeded → halt automation

**Rule 4: Circuit Breaker**
- 3+ failures in 60 minutes → disable automation
- Cooldown period: 30 minutes
- Requires manual investigation

### Routing Queues

| Intent | Queue | Priority | SLA |
|--------|-------|----------|-----|
| billing_issue | billing_team_queue | Medium | 24h |
| technical_issue | support_tier1_queue | High | 4h |
| refund_request | billing_team_queue | Medium | 48h |
| legal_escalation | legal_team_queue | Critical | 2h |
| unknown | human_review_queue | Low | 72h |

---

## Failure Modes (Explicitly Demonstrated)

### 1. Malformed LLM Output
**Trigger**: Invalid JSON from model
**Handling**: Retry with fallback model → escalate if both fail
**Trace**: Logs raw response, error details, models attempted

### 2. Low Confidence Classification
**Trigger**: Confidence below intent threshold
**Handling**: Immediate escalation to human review
**Trace**: Records confidence gap, classification attempt

### 3. Risk Flag Detection
**Trigger**: Critical risk flag present (lawsuit, compliance, fraud)
**Handling**: Force escalation regardless of confidence
**Trace**: Flags detected, escalation priority set to "high"

### 4. Budget Overrun
**Trigger**: Cost or latency exceeds limits
**Handling**: Log warning, escalate request, alert admin
**Trace**: Actual vs limit, model performance metrics

### 5. Circuit Breaker Trip
**Trigger**: Repeated failures (3+ in 60 min)
**Handling**: Disable automation, require manual reset
**Trace**: Failure timeline, affected requests

### 6. Duplicate Request
**Trigger**: Same email hash already processed
**Handling**: Return cached result, skip processing
**Trace**: Original request ID, cached timestamp

---

## Workflow Phases (10 Total)

### **Phase 0**: Scope Definition ✅
- Problem statement, requirements, success criteria

### **Phase 1**: System Design ✅
- Architecture diagrams, data schemas, module breakdown

### **Phase 2**: Reasoning Layer ✅
- LLM prompts, JSON schema, validation logic

### **Phase 3**: Policy Layer ✅
- Policy rules, decision logic, routing configuration

### **Phase 4**: State Management ✅
- Database schema, state operations, query patterns

### **Phase 5**: Execution & Integration (IN PROGRESS)
- n8n workflow implementation, API integrations, trace assembly
- **Current Status**: 6-node starter workflow working
- **Next**: Add policy engine, routing logic, full state persistence

### **Phase 6**: Metrics & Observability
- Real-time dashboards, KPI tracking, alert configuration

### **Phase 7**: Failure Testing
- Hard-case test suite, failure injection, recovery validation

### **Phase 8**: Deployment
- Production configuration, environment setup, monitoring

### **Phase 9**: Documentation
- System README, architecture docs, runbook

### **Phase 10**: Portfolio Artifacts
- GitHub repo, blog post, resume bullets, demo video

---

## Success Criteria

### Functional Requirements ✅ / ❌

- [x] System ingests unstructured email text
- [x] Extracts structured intent with confidence scores
- [x] Classifies into 5 categories with risk flags
- [ ] Routes based on confidence thresholds
- [ ] Applies safety policies (cost, latency, risk)
- [x] Maintains persistent state in database
- [ ] Exports full reasoning traces
- [ ] Escalates ambiguous cases to human review
- [ ] Handles LLM failures gracefully
- [ ] Supports model fallback chain

### Performance Targets

- **Latency**: < 10s per request (P95)
- **Cost**: < $0.05 per request
- **Automation Rate**: > 70% (non-escalated)
- **Escalation Precision**: > 90% (escalated cases need human review)
- **Accuracy**: > 85% vs ground truth labels
- **Uptime**: > 99% with graceful degradation

### Portfolio Signal (High-Level)

**GitHub Repository**: Clean architecture, documented failure modes, trace examples
**Blog Post**: "Building AI Systems That Know When Not to Act"
**Resume Bullet**: "Designed failure-aware AI triage system embedding probabilistic language models into deterministic control pipelines with explicit state, evaluation metrics, and human-in-the-loop safeguards"

---

## Implementation Roadmap

### Horizon 1 (H1): MVP Prototype — 2 Weeks
**Goal**: Working end-to-end pipeline with 1 email type

- [x] Week 1: Database + n8n setup + basic workflow (6 nodes)
- [ ] Week 2: Policy engine + routing + trace logging (full 32 nodes)
- [ ] Deliverable: Demo video showing auto-route vs escalate decision

### Horizon 2 (H2): Production System — 4 Weeks
**Goal**: Handle all 5 categories with failure modes demonstrated

- [ ] Week 3: Failure test suite + circuit breaker + duplicate handling
- [ ] Week 4: Metrics dashboard + alerting + performance optimization
- [ ] Week 5: Integration with real email system (Gmail/Outlook)
- [ ] Week 6: Load testing + documentation + deployment guide
- [ ] Deliverable: GitHub repo + technical README

### Horizon 3 (H3): Portfolio Compound — 2 Weeks
**Goal**: Ship public artifacts that generate career signal

- [ ] Week 7: Blog post draft + architecture diagrams + trace visualizations
- [ ] Week 8: LinkedIn post series + resume update + demo refinement
- [ ] Deliverable: Published blog, updated resume, active GitHub repo

---

## Test Cases (Coverage Plan)

### Happy Path Tests (6)

1. **Clear billing issue** → Auto-route to billing_team_queue
2. **Technical issue** → Auto-route to support_tier1_queue
3. **Refund with warning flag** → Auto-route (refund is not critical)
4. **Legal with compliance flag** → Escalate (compliance is critical)
5. **Ambiguous email** → Escalate (low confidence)
6. **Duplicate email** → Return cached result

### Failure Mode Tests (6)

1. **Malformed LLM output** → Trigger fallback → Escalate if both fail
2. **Confidence below threshold** → Escalate with reason
3. **Cost exceeded** → Escalate + log warning
4. **Latency exceeded** → Escalate + switch model
5. **Circuit breaker trip** → Disable automation
6. **Critical risk flag** → Force escalation

### Edge Cases (4)

1. **Confidence exactly at threshold** → Auto-route (inclusive)
2. **Multiple warning flags** → Auto-route (warnings don't escalate)
3. **Empty email body** → Classify as unknown, escalate
4. **Non-English email** → Model attempts classification, likely low confidence

---

## Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| OpenAI API downtime | Complete system halt | Add fallback model (GPT-3.5-turbo) |
| Cost overrun from high volume | Budget exceeded | Rate limiting + budget alerts |
| Low classification accuracy | Poor routing decisions | Human review queue + feedback loop |
| Database connection failures | Lost state | Retry logic + connection pooling |
| Prompt injection attacks | Malicious classifications | Input sanitization + rate limiting |

---

## Artifacts & Deliverables

### GitHub Repository Structure

```
failure-aware-ai-triage/
├── README.md (architecture + quickstart)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── FAILURE_MODES.md
│   └── DEPLOYMENT.md
├── n8n/
│   └── workflows/
│       └── email-triage-main.json
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

### Blog Post Outline

**Title**: "Building AI Systems That Know When Not to Act"

1. **The Problem**: Most AI demos assume success; production needs failure awareness
2. **Core Insight**: Intelligence without control is dangerous
3. **System Design**: Probabilistic reasoning + deterministic policy
4. **Failure Modes**: Demonstrated, not hidden
5. **Lessons Learned**: What worked, what didn't, what surprised us
6. **Code Walkthrough**: Key architectural decisions with examples

### Resume Bullet (Final)

"Designed and deployed a failure-aware AI triage system embedding probabilistic language models into deterministic control pipelines with explicit state, evaluation metrics, and human-in-the-loop safeguards — demonstrating research-grade reasoning about AI safety and system reliability"

---

## What Makes This Research-Aligned

| Research Value | Where It Shows |
|----------------|----------------|
| Reasoning ≠ control | Separate LLM and policy layers |
| Probabilistic + symbolic | Neural classification + hard rules |
| Inspectability | Full traces, no black boxes |
| Safety thinking | Guardrails, escalation, circuit breaker |
| NeSy intuition | State + logic + neural components |
| Failure awareness | Explicit handling, not edge cases |
| Evaluation rigor | Metrics, test cases, failure injection |

---

## Current Status Summary

**What Works**:
- ✅ Email ingestion via webhook
- ✅ Unique ID generation + duplicate detection (hash-based)
- ✅ Database persistence (requests table)
- ✅ LLM classification with structured outputs (JSON Schema)
- ✅ End-to-end flow (webhook → classify → respond)

**What's Missing**:
- ❌ Policy decision engine (confidence + risk + budget checks)
- ❌ Routing logic (auto-route vs escalate branching)
- ❌ Full state persistence (classifications, routing_decisions, traces)
- ❌ Slack/email integration for escalations
- ❌ Failure handling (fallback model, circuit breaker)
- ❌ Duplicate detection flow (query → IF → cached response)
- ❌ Metrics dashboard + monitoring

**Next Session Goals**:
1. Add policy decision engine (Code node with confidence/risk/budget checks)
2. Add IF node to branch auto-route vs escalate
3. Write classification to database
4. Write routing decision to database
5. Test with multiple email types (billing, legal, refund, ambiguous)

---

## Questions for Next Session

1. Should we add Slack integration first, or finish database writes?
2. How do we test escalation flow without a real Slack workspace?
3. Should we add duplicate detection now, or after policy engine?
4. Do we need a separate "metrics" workflow, or inline calculations?

---

**Last Updated**: 2026-03-19
**Phase**: H1 — MVP Prototype (Week 1 complete, Week 2 in progress)
**Status**: 6-node workflow functional, expanding to 32-node full pipeline
