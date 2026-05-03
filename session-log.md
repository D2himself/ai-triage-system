# Session Log — AI Triage System

## Project Overview
Building a failure-aware AI triage system for customer support emails using n8n workflows, Supabase (Postgres), and OpenAI. System demonstrates explicit reasoning decomposition, policy-based decision making, and full traceability — designed as a research-grade portfolio project.

## Trajectory Map
- **H1 — Prototype**: Working 8-node workflow (webhook → classify → store → respond)
- **H2 — Production**: Full 32-node pipeline with policy engine, fallback logic, escalation handling
- **H3 — Compound**: Blog post "Building AI Systems That Know When Not to Act" + GitHub repo

## Architecture Summary
```
Webhook Trigger → Generate Metadata → Insert to DB → Build Prompt → 
OpenAI Classification → Policy Engine → Route/Escalate → 
Write Results → Trace Logging → Respond
```

**Tech Stack**:
- n8n (workflow orchestration) in Docker
- Supabase (managed Postgres) for state persistence
- OpenAI GPT-4o-mini with JSON Schema (structured outputs)

**Database Tables** (6 core):
- requests, classifications, routing_decisions, traces, failure_log, metrics_cache

---

## Progress Tracker

### Phase 5: Execution & Integration

**Overall Progress**: 6/32 nodes complete (18.75%)

#### Completed ✅
- [x] Webhook trigger (email ingestion)
- [x] Generate request metadata (ID + hash)
- [x] Insert request to database
- [x] Build classification prompt
- [x] OpenAI classification (structured outputs)
- [x] Respond to webhook

#### In Progress 🚧
- [ ] Policy decision engine (next immediate step)
- [ ] Routing logic (auto-route vs escalate)
- [ ] Write classification to database
- [ ] Write routing decision to database
- [ ] Build and write trace
- [ ] Slack integration (escalations)
- [ ] Duplicate detection flow

#### Blocked / Dependencies ⏸️
- Slack integration requires workspace setup
- Fallback model needs Anthropic payment (or use GPT-3.5-turbo)
- Metrics dashboard needs Phase 5 complete

---

## Next Session: Priority Checklist

### Critical Path (Must Complete)
1. **[CRITICAL]** Reset Supabase password (security issue from exposed credentials)
2. **Add Policy Decision Engine** (Code node)
   - Implement confidence threshold checks
   - Implement risk flag detection
   - Implement budget enforcement
   - Output: decision object (auto_route | escalate)
3. **Add IF Node**: Branch on decision type
   - True path → auto-route
   - False path → escalate
4. **Write Classification to DB** (Postgres node)
   - Insert into `classifications` table
   - Capture model metadata, cost, latency
5. **Write Routing Decision to DB** (Postgres node)
   - Insert into `routing_decisions` table
   - Record policies evaluated and decision reason

### Secondary (If Time Permits)
6. Add trace assembly and write to `traces` table
7. Test with multiple email types:
   - High confidence billing → auto-route
   - Legal with compliance flag → escalate
   - Ambiguous email → escalate (low confidence)
8. Add simple Slack node (can use webhook URL for testing without workspace)

### Future Sessions
- Duplicate detection flow (requires IF node after Check Duplicate query)
- Fallback model logic (GPT-3.5-turbo if GPT-4o-mini fails)
- Circuit breaker implementation
- Metrics dashboard queries
- Test suite execution

---

## Open Issues / Blockers

### Technical Issues
1. **Duplicate Detection Crashes Workflow**
   - Current: Unique constraint violation stops execution
   - Fix Needed: Add IF node to check for existing hash before insert
   - Priority: Medium (annoying but not blocking core functionality)

2. **No Fallback Model Yet**
   - Current: Single OpenAI model, no backup
   - Options: (a) Add GPT-3.5-turbo fallback, (b) Wait for Anthropic funding
   - Priority: Low (can add later in Phase 6)

3. **n8n Node Referencing Confusion**
   - Learning: `$json` vs `$('Node Name').item.json`
   - Status: Understood through trial and error
   - Priority: Resolved

### Non-Technical Issues
1. **Supabase Password Exposed**
   - Action Required: Reset immediately next session
   - Impact: High (security vulnerability)
   - Priority: CRITICAL

2. **No Slack Workspace for Testing**
   - Workaround: Use Slack webhook URL (can test without full workspace)
   - Alternative: Use email integration instead
   - Priority: Low (can mock for now)

---

## Decision Log

### Key Decisions Made

**Decision 1**: Use Supabase connection pooling (port 6543) instead of direct connection
- **Rationale**: Docker networking issue with direct connection; pooling works reliably
- **Trade-off**: Slight latency increase, but better stability
- **Status**: Working

**Decision 2**: Use OpenAI JSON Schema instead of manual validation
- **Rationale**: n8n has native support; eliminates validation code
- **Trade-off**: Locked into OpenAI (but that's fine for MVP)
- **Status**: Implemented and working

**Decision 3**: Simple hash function instead of crypto module
- **Rationale**: n8n blocks Node.js crypto for security
- **Trade-off**: Less secure hash, but sufficient for duplicate detection
- **Status**: Working (collision unlikely for email content)

**Decision 4**: Reference earlier nodes by name instead of passing data through
- **Rationale**: Cleaner architecture; each node doesn't need to forward everything
- **Trade-off**: Requires understanding n8n's referencing syntax
- **Status**: Working

### Decisions Pending

**Decision A**: Slack vs Email for escalations?
- **Options**: (1) Slack webhook, (2) Email integration, (3) Both
- **Recommendation**: Start with Slack webhook (simpler), add email later
- **Block Until**: Next session

**Decision B**: When to add duplicate detection flow?
- **Options**: (1) Now (parallel work), (2) After policy engine (sequential)
- **Recommendation**: After policy engine (don't split focus)
- **Block Until**: Policy engine complete

**Decision C**: Fallback model strategy?
- **Options**: (1) GPT-3.5-turbo (cheap), (2) Anthropic Claude (better), (3) Both
- **Recommendation**: GPT-3.5-turbo for now (free, works with existing credential)
- **Block Until**: Phase 6 (failure testing)

---

## Sessions

### Session 1 — 2026-03-19
**Type**: BUILD
**Goal**: Implement Phase 5 starter workflow (8 nodes) with n8n + Supabase + Docker

**Completed**:
- ✅ Supabase project setup with connection pooling (port 6543)
- ✅ Database schema initialized (6 tables, 3 functions)
- ✅ Docker + n8n installed and running (localhost:5678)
- ✅ 3 credentials configured (Supabase Postgres, OpenAI, Anthropic)
- ✅ 6-node starter workflow built and tested:
  1. Webhook trigger (`/webhook/email-triage`)
  2. Generate Request Metadata (Code) — creates request_id + email_hash
  3. Insert Request (Postgres) — writes to `requests` table
  4. Build Classification Prompt (Code) — constructs LLM prompt with email data
  5. Classify Email (OpenAI) — GPT-4o-mini with JSON Schema structured outputs
  6. Respond to Webhook — returns classification result

**Stopped at**: Working 6-node workflow. Successfully classified test emails with structured JSON output.

**Next**: 
1. Add policy decision engine (confidence thresholds, risk flag detection)
2. Add routing logic (auto-route vs escalate)
3. Write classification + routing decision to database
4. Add trace logging
5. Test end-to-end with multiple email types

**Open Gaps**:
- [GAP: Duplicate detection] — Currently crashes on duplicate emails instead of returning cached result. Need to add IF node after "Check Duplicate" query.
- [GAP: Fallback model] — No fallback if OpenAI fails. Can add GPT-3.5-turbo as backup (Anthropic requires paid account).
- [GAP: n8n best practices] — Learning node referencing syntax: `$('Node Name').item.json.field` vs `$json.field`

**Experiments / Results**:

🧪 **Email hashing for duplicate detection**
- Hypothesis: Simple hash function (bitwise operations) sufficient for duplicate detection
- Result: Works correctly — same email produces same hash, blocks duplicate inserts
- Learning: Database unique constraint catches duplicates, but workflow crashes instead of handling gracefully

🧪 **OpenAI JSON Schema structured outputs**
- Hypothesis: JSON Schema enforcement eliminates need for validation code
- Result: Confirmed — model always returns valid JSON matching schema exactly
- Learning: n8n's native OpenAI node with JSON Schema is cleaner than HTTP requests + manual validation

🧪 **Node data passing in n8n**
- Hypothesis: Nodes automatically pass all data forward
- Result: False — nodes only pass what they explicitly return (e.g., RETURNING clause in SQL)
- Solution: Reference earlier nodes by name: `$('Generate Request Metadata').item.json`
- Learning: n8n workflows are stateless — must explicitly reference nodes to access their data

**Key Technical Decisions**:
1. **Supabase connection pooling (port 6543)** instead of direct connection — required for Docker network compatibility
2. **Simple hash function** instead of crypto module — n8n blocks Node.js crypto for security
3. **JSON Schema structured outputs** — eliminates validation code, guaranteed valid responses
4. **Reference nodes by name** — cleaner than passing huge JSON objects through every node

**Security Notes**:
- ⚠️ Database password was exposed in chat — MUST reset after session
- Supabase → Project Settings → Database → Reset password
- Update credential in n8n after reset

---

## Learning Notes

### What We Learned This Session

1. **Docker + n8n is easier than expected**
   - Docker Compose handles everything
   - n8n UI is intuitive for visual debugging
   - Credentials persist across container restarts

2. **Supabase connection pooling > direct connection**
   - Docker networks don't always play nice with direct DB connections
   - Pooling (port 6543) works reliably from containers
   - User format: `postgres.PROJECT_REF` not just `postgres`

3. **n8n's native AI nodes are powerful**
   - JSON Schema structured outputs eliminate validation code
   - Much cleaner than raw HTTP requests
   - Built-in error handling and retries

4. **Node data passing is explicit, not automatic**
   - Postgres RETURNING clause only returns specified columns
   - Must reference earlier nodes by name to access full data
   - Syntax: `$('Node Name').item.json.field`

5. **Hash-based duplicate detection works**
   - Simple bitwise hash function is sufficient
   - Same email → same hash → database rejects
   - Need to add graceful handling (IF node) instead of crash

### Knowledge Gaps Filled
- [x] How Docker Compose works
- [x] Supabase vs self-hosted Postgres
- [x] n8n workflow execution model
- [x] OpenAI structured outputs (JSON Schema)
- [x] n8n node referencing syntax

### Knowledge Gaps Remaining
- [ ] n8n IF node configuration (coming next session)
- [ ] How to handle node errors gracefully
- [ ] Circuit breaker implementation in n8n
- [ ] Best practices for n8n workflow organization
- [ ] How to export/version control n8n workflows

---

## Resources & Links

### Project Files
- Session Log: `/home/claude/session-log.md`
- Project Plan: `/home/claude/plan.md`
- Docker Config: `~/ai-triage-system/docker-compose.yml`
- Environment: `~/ai-triage-system/.env` (contains secrets, not committed)

### External Services
- Supabase Dashboard: https://supabase.com/dashboard
- n8n Local: http://localhost:5678
- OpenAI Platform: https://platform.openai.com
- Anthropic Console: https://console.anthropic.com

### Documentation
- n8n Docs: https://docs.n8n.io
- Supabase Docs: https://supabase.com/docs
- OpenAI API: https://platform.openai.com/docs

### GitHub (Future)
- Repo: (not created yet)
- Branch Strategy: main (stable) + dev (active work)
- Commit Format: `type: description` (feat, fix, chore, exp)

---

## Quick Reference

### Docker Commands
```bash
# Start n8n
cd ~/ai-triage-system
docker compose up -d

# Stop n8n
docker compose down

# View logs
docker compose logs -f n8n

# Restart n8n
docker compose restart n8n
```

### Test Commands
```bash
# Test webhook (when workflow is Active)
curl -X POST http://localhost:5678/webhook/email-triage \
  -H "Content-Type: application/json" \
  -d '{
    "from": "test@example.com",
    "subject": "Test email",
    "body": "Email content here",
    "customer_id": "cust_001"
  }'
```

### Supabase Queries
```sql
-- View recent requests
SELECT * FROM requests ORDER BY created_at DESC LIMIT 10;

-- View classifications
SELECT r.subject, c.intent, c.confidence, c.risk_flags 
FROM requests r 
JOIN classifications c ON r.request_id = c.request_id 
ORDER BY r.created_at DESC;

-- Check for failures
SELECT * FROM failure_log ORDER BY occurred_at DESC LIMIT 10;
```

---

## Next Session Setup

### Before Starting Code
1. ⚠️ **SECURITY**: Reset Supabase password
2. Start Docker: `cd ~/ai-triage-system && docker compose up -d`
3. Open n8n: http://localhost:5678
4. Read this session log
5. Review `plan.md` for big picture
6. Test current workflow to verify it still works

### Session Goal Statement
"Add policy decision engine and routing logic — complete the classify → decide → route pipeline"

### Definition of Done
- [ ] Policy engine evaluates confidence, risk flags, and budget
- [ ] IF node branches on decision type
- [ ] Classification written to database
- [ ] Routing decision written to database
- [ ] End-to-end test: email → classification → policy → routing → DB
- [ ] Session log updated with progress

---

## Session Metrics

**Time Spent**: ~3 hours
**Nodes Implemented**: 6
**Database Tables Created**: 6
**Test Emails Sent**: 4
**Bugs Fixed**: 3 (webhook data nesting, node referencing, connection pooling)
**Lines of Code**: ~150 (JavaScript in Code nodes)
**SQL Queries Written**: ~10

**Velocity**: 2 nodes/hour (slower due to setup + learning curve)
**Projected**: Next session should be 4-5 nodes/hour (setup done, patterns learned)

---

**Last Updated**: 2026-03-19, 16:45 (before system shutdown)
**Next Session**: TBD
**Status**: Phase 5 in progress — 6/32 nodes complete
