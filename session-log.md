# Session Log: AI Triage System

Read the first three sections to pick up the project cold. Everything below them is history
and reference.

**Last updated:** 2026-09-18, end of Session 5

---

## 1. Goal

Build a system that sorts customer support emails. An LLM suggests a category, a confidence
score, and risk flags. Fixed rules then decide whether the email goes to a team queue
automatically or to a person. Every decision is saved to Supabase so you can see why it was
made. The finished project is a public repo, a demo video, and a blog post titled "Building
AI Systems That Know When Not to Act".

The full design is in `plan.md`.

---

## 2. Next step

**Design the trace, then build trace assembly.** Decide what each entry in `traces.steps`
records, e.g., the step name, its start and end time, and whether it succeeded. Then add a
node after Write Routing Decision that builds the trace and writes it to `traces`. The table
already exists. Its columns are in `database/schema.sql`.

**After that, in this order:**
1. Set `requests.status` at the end of the run. Today every request stays at `processing`,
   even after it is routed or escalated (open issue 2).
2. Wire real latency, and cost if Groq's token counts can be read (open issue 3).
3. Add a Slack alert for escalated emails. This needs Decision A first.
4. Add a fallback model. This needs Decision B first.

**Stay out of these for now:**
- Do not refactor the Policy Engine into helper functions. It only has 4 checks.
- Do not build an IF node for auto route versus escalate until the two branches need
  different behavior (Decision 8). The duplicate check IF node is a different branch.

---

## 3. Completed so far

**Where the project is:** Phase 5 of 10, building the n8n workflow. 13 of about 32 planned
nodes are built. All three test emails (billing, legal, ambiguous) pass on Groq, and the saved
rows match in all three tables.

### The pipeline as it stands

1. **Webhook** receives the email at `/webhook/email-triage`.
2. **Generate Request Metadata** creates a request ID and a hash of the email.
3. **Check Duplicate** looks up the hash with the `check_duplicate_request()` database
   function, and fetches the saved decision if the email was seen before.
4. **Is Duplicate?** sends a repeated email to Respond Duplicate, and a new email onward.
5. **Respond Duplicate** returns the saved result and skips the LLM.
6. **Insert Request** saves the email to the `requests` table.
7. **Build Classification Prompt** writes the prompt for the LLM.
8. **Basic LLM Chain** sends the prompt to the model and returns its JSON answer as text.
9. **Groq Chat Model** runs `openai/gpt-oss-20b` for the chain above.
10. **Policy Engine** first checks that the LLM output has the expected shape. Bad output
    escalates with `invalid_llm_output`. It then applies three rules in order: critical risk
    flags, then budget, then confidence. It returns `auto_route` or `escalate` with a reason.
11. **Write Classification** saves the LLM output to `classifications`, including the raw
    answer and any validation errors.
12. **Write Routing Decision** saves the decision to `routing_decisions`.
13. **Respond to Webhook** returns the result to the caller.

The workflow is saved in `workflows/email-triage-main.json`. The database schema is saved in
`database/schema.sql`.

### What each session added

- **Session 1 (2026-03-19).** Set up Supabase with 6 tables, and n8n in Docker. Built the
  first 6 nodes. Classification worked with OpenAI and a JSON schema.
- **Session 2 (2026-05-04).** Built the Policy Engine. Tested the billing email. Created the
  public GitHub repo.
- **Session 3 (2026-08-25).** Tested all three policy paths: billing, legal, and ambiguous.
  Fixed the webhook response. Built the two database write nodes. Found a working way to
  insert arrays into jsonb columns.
- **Session 4 (2026-09-17 to 2026-09-18).** Switched classification from OpenAI to Groq,
  because the OpenAI account ran out of credits. Fixed a missing connection that stopped the
  webhook from responding. Traced a "Host not found" error to a paused Supabase project and
  resumed it. Tested the billing email end to end.
- **Session 5 (2026-09-18).** Added the output check to the Policy Engine, and saved the
  model's raw answer and any validation errors with each classification. Built the duplicate
  check. Fixed Insert Request, which crashed on any email with an apostrophe. Fixed
  `model_used`. Passed the billing, legal, and ambiguous tests on Groq. Added
  `database/schema.sql` and the workflow export to the repo. Tidied `plan.md`,
  `session-log.md`, and `CLAUDE.md`.

---

## 4. Open issues

These are the open issues as of Session 5. Older issues that are now fixed are listed at the
end of this section.

1. **No trace is saved.** The `traces` table is empty. This is the next step.
2. **`requests.status` never changes.** It is set to `processing` on insert and never
   updated to `auto_routed` or `escalated`. A duplicate email's reply shows the old status as
   `processing`.
3. **Cost and latency are placeholders.** They are fixed at $0.001 and 2000 ms, so the budget
   rule never fires on real numbers. These values also do not match Groq's pricing.
4. **No fallback model.** If Groq fails or times out, the workflow stops with no reply.
5. **The ambiguous email passes for a weaker reason than planned.** The prompt says an
   unclear email should get intent `unknown` with confidence under 0.5. In the Session 5 test,
   Groq answered `technical_issue` with confidence 0.6. It still escalated, but only because
   0.6 is below the 0.70 threshold for `technical_issue`. A slightly more confident answer
   would have auto routed. Worth adding more unclear emails to the tests.
6. **Only 6 of the 16 planned test cases have been run.** See the test plan in `plan.md`.
7. **The column `requests.commpleted_at` has a typo.** Nothing writes to it yet. Rename it
   before anything does.

**Working habits that came out of past sessions:**
- Save in n8n after each node. A page refresh once lost an unsaved node (Session 3).
- The n8n browser code editor dropped edits in Session 4. For code node edits, export the
  workflow JSON with n8n's command line tool, edit the file, and import it again.
- Supabase pauses a free project that sits idle. If a Postgres node shows "Host not found",
  resume the project from the Supabase dashboard first (Session 4).
- An import through the command line turns the workflow off. Run
  `docker exec n8n-triage n8n publish:workflow --id=YvYWLjqlEa4uxEUp`, then
  `docker compose restart n8n` (Session 5).
- Pass values into SQL as parameters (`$1`, `$2`) with Query Parameters, never by pasting
  `{{ }}` inside quotes. Pasted text breaks on any apostrophe (Session 5).
- After exporting the workflow for the repo, remove the `shared` field. It holds the n8n
  owner's name and email (Session 5).

**Fixed issues:**
- Supabase password was exposed. Fixed in Session 2.
- n8n node referencing was confusing. Fixed in Session 1.
- The OpenAI output shape was unknown. Fixed in Session 2. The result sits at
  `output[0].content[0].text`.
- The escalation paths were untested. Fixed in Session 3, and tested again on Groq in
  Session 5.
- Respond to Webhook returned literal expression text. Fixed in Session 3.
- Write Routing Decision was not connected to Respond to Webhook. Fixed in Session 4.
- Groq output was not checked against the JSON format. Fixed in Session 5.
- A failed output check lost the model's answer. Fixed in Session 5. It is now in
  `raw_response`.
- `model_used` said `gpt-4o-mini`. Fixed in Session 5.
- A duplicate email crashed the workflow. Fixed in Session 5.
- An apostrophe in an email crashed Insert Request. Fixed in Session 5.
- Sessions 3 to 5 were not committed, and the workflow and schema were not in the repo.
  Fixed in Session 5.

---

## 5. Decisions

### Decisions made

**Decision 1**: Use Supabase connection pooling (port 6543) instead of direct connection — *Session 1*
- Rationale: Docker networking issue with direct connection
- Status: Working

**Decision 2**: Use OpenAI JSON Schema instead of manual validation — *Session 1*
- Rationale: n8n native support; eliminates validation code
- Status: Working

**Decision 3**: Simple hash function instead of crypto module — *Session 1*
- Rationale: n8n blocks Node.js crypto for security
- Status: Working

**Decision 4**: Reference earlier nodes by name instead of passing data through — *Session 1*
- Rationale: Cleaner architecture
- Status: Working

**Decision 5**: Defensive navigation with optional chaining (`?.`) for nested LLM output — *Session 2*
- Rationale: n8n's OpenAI node returns full API response, not just structured output. Output is buried at `output[0].content[0].text`. Optional chaining + explicit error throw turns silent failures into loud ones.
- Status: Working

**Decision 6**: Three-rule policy engine with short-circuit precedence — *Session 2*
- Order: critical risk flags → budget → confidence
- Rationale: Cheapest + most safety-critical checks first; first failure short-circuits
- Status: Working (happy path verified)

**Decision 7**: Public GitHub repo with plan.md + session-log.md included — *Session 2*
- Rationale: Working notes + plan ARE the portfolio signal — they show research-grade thinking
- Status: Pushed end of Session 2

**Decision 8**: Defer the IF node (auto_route vs escalate branch) until there's actual divergent behavior to route — *Session 3*
- Rationale: today both branches do the identical thing (write DB, respond); a fork with no behavioral difference is premature structure. Build it when Slack (escalate) or real queue push (auto_route) needs a genuinely different path.
- Status: Deliberately not built

**Decision 9**: Use `to_jsonb($n::text[])` in raw SQL for jsonb array columns, not a `::jsonb` cast on the driver-bound value — *Session 3*
- Rationale: n8n's Postgres "Insert" (column-mapper) operation rejects JS arrays for jsonb columns outright (validator only accepts plain objects). Switching to "Execute Query" with a raw `::jsonb` cast still fails, because node-postgres binds JS arrays as a native Postgres ARRAY type, which `::jsonb` can't cast directly — and an empty array leaves Postgres unable to infer the array's element type at all ("polymorphic type unknown"). `to_jsonb($n::text[])` fixes both: the explicit cast removes the inference ambiguity, and `to_jsonb()` is the correct converter from a native array to jsonb.
- Status: Working, verified via `jsonb_typeof()` on both tables (not by eyeballing Supabase's table UI, which re-stringifies jsonb cells when you copy them — a false alarm this session)

**Decision 10**: Switch classification from OpenAI to Groq (`openai/gpt-oss-20b` through a Basic LLM Chain) — *Session 4*
- Rationale: the OpenAI account had no credits and Kemi could not add funds. Groq already had a saved credential from Session 1. The older Llama models were no longer offered on the account, so this was the closest general model available.
- Status: Working for the billing email. Legal and ambiguous not yet tested on it.

**Decision 11**: Check the LLM output shape in the Policy Engine, and escalate bad output instead of crashing — *Session 5*
- Rationale: OpenAI enforced the JSON format through structured outputs. The n8n Groq node has no such option, so nothing checked the format after the switch. Offline tests of the old code showed 4 of 8 bad outputs were routed automatically without anyone noticing, e.g., a made-up risk flag, and the other 4 crashed the workflow. The check runs first, before the risk flag rule. It matches failure mode 1 in `plan.md`, without the retry, since there is no fallback model yet. A hand check in the Code node is used because the Code node cannot load a schema library by default.
- Status: Working. Tested offline on 11 cases, live on one billing email, and against the real tables with 3 bad answers and 1 good answer.

**Decision 12**: Use the existing `check_duplicate_request()` database function for the duplicate check, and return the saved decision — *Session 5*
- Rationale: the function already existed from Session 1 and always returns exactly one row, so the n8n flow does not stop when there is no match. Joining `routing_decisions` gives the saved result that `plan.md` failure mode 6 asks for, with one query and one new node.
- Status: Working. A repeated email returns `status: duplicate` with the saved decision.

### Decisions pending

**Decision A**: Slack or email for escalations?
- Recommendation: a Slack webhook first, since it is simpler. Email later.
- Open question: how to test escalation without a real Slack workspace.

**Decision B**: Which fallback model?
- The earlier plan was GPT-3.5-turbo. That no longer works, since the OpenAI account has no credits.
- Open. Decide before Phase 7, failure testing.

**Decision C**: Metrics in a separate n8n workflow, or computed inside the main one?
- Open. Decide at Phase 6.

---

## 6. Session history

The full record of each session, oldest first. New sessions go at the bottom of this section.

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

**Open Gaps** (carried forward at end of session):
- [GAP: Duplicate detection] — Currently crashes on duplicate emails
- [GAP: Fallback model] — No fallback if OpenAI fails
- [GAP: n8n best practices] — Learning node referencing syntax

**Experiments / Results**:

🧪 **Email hashing for duplicate detection**
- Result: Works — same email produces same hash, blocks duplicate inserts
- Learning: DB unique constraint catches duplicates, but workflow crashes instead of handling gracefully

🧪 **OpenAI JSON Schema structured outputs**
- Result: Confirmed — model always returns valid JSON matching schema
- Learning: n8n's native OpenAI node + JSON Schema is cleaner than HTTP + manual validation

🧪 **Node data passing in n8n**
- Result: Nodes only pass what they explicitly return
- Solution: Reference earlier nodes by name: `$('Generate Request Metadata').item.json`

---

### Session 2 — 2026-05-04
**Type**: BUILD
**Goal**: Add policy decision engine and routing logic — complete the classify → decide pipeline

**Completed**:
- ✅ Reset Supabase password + updated n8n credential (security fix from Session 1)
- ✅ Built **Policy Engine** Code node — 3 deterministic rules:
  - **CHECK 1**: Critical risk flags (`lawsuit`, `compliance`, `fraud`) → force escalate
  - **CHECK 2**: Budget (cost > $0.10 OR latency > 15s) → escalate (cost/latency stubbed)
  - **CHECK 3**: Confidence below per-intent threshold → escalate (priority depends on intent)
  - **Default**: auto-route to intent-mapped queue
- ✅ Defensive navigation for nested LLM output via optional chaining (`?.`)
- ✅ Defensive guard: throws if intent has no threshold (loud failure > silent corruption)
- ✅ Tested billing email end-to-end — auto-routes to `billing_team_queue` correctly
- ✅ **Git + GitHub setup**:
  - `.gitignore` (excludes `.env`, n8n data, OS junk)
  - `README.md` (portfolio-grade, leads with "why not how")
  - `LICENSE` (MIT)
  - First commit + pushed to public GitHub repo

**Stopped at**: Working policy engine, billing email tested. IF node + DB writes not yet added.

**Next**:
1. Test legal + ambiguous emails to verify escalation paths
2. Fix Respond to Webhook expression bug
3. Add IF node + DB writes for classification + routing_decisions

**Open Gaps**:
- [GAP: Escalation paths untested] — Only billing (happy path) verified. Legal + low-confidence emails not run.
- [GAP: Webhook response shows literal expression text] — `={{ $('Insert Request').item.json.request_id }}` displayed verbatim
- [GAP: Defensive guards] — Pattern of "throw on missing config" should be added in Phase 7 across the system, not just CHECK 3
- [GAP: Cost/latency stubbed] — Real values from OpenAI node output not yet wired
- [GAP: IF node + DB writes] — full state persistence not yet implemented

**Experiments / Results**:

🧪 **Billing email through full pipeline**
- Hypothesis: All 3 checks should pass (no risk flags, low cost/latency, confidence 0.9 > 0.75)
- Result: ✅ Confirmed — `decision: "auto_route"`, `destination: "billing_team_queue"`, all 3 checks in `policies_passed`
- Learning: The system *appears* to work, but only 1 of 3 paths verified. Don't trust the test until escalation paths also fire.

🧪 **LLM output structure surprise**
- Hypothesis: `classification.risk_flags` would be at top level
- Result: ❌ Buried at `output[0].content[0].text.risk_flags`
- Learning: n8n's OpenAI node returns the full API response wrapper, not just the parsed text. Always inspect actual output shape before writing downstream code. **Optional chaining (`?.`) is the right defense** for any deeply-nested external API.

🧪 **JS template strings**
- Hypothesis: Single quotes would interpolate `${variable}`
- Result: ❌ Single quotes treat `${...}` as literal text. Backticks required.
- Learning: Backticks for any string with interpolation. Single/double for plain strings.

**Key Technical Decisions**:
1. Short-circuit precedence (risk → budget → confidence) — cheapest + most safety-critical checks first
2. Defensive navigation with `?.` — prevents cryptic crashes on malformed LLM output
3. Throw on missing threshold — turn silent failure into loud one
4. Public GitHub with plan.md + session-log.md — process visibility IS the portfolio signal

**Lessons (worth keeping)**:
- "Working on the happy path" ≠ "working." Until you test the failure paths, you have a 33%-tested system.
- Silent failures (e.g., `confidence < undefined` returning `false`) are worse than crashes. Defensive guards convert one to the other.
- Repetitive `push 'name' / check / push or return` pattern in CHECK 1/2/3 is a refactor signal — not now (only 3 rules), but mark it.

---

### Session 3 — 2026-08-25
**Type**: BUILD
**Intent**: Leverage
**Goal**: Verify the two untested escalation paths from Session 2's handoff, then wire persistent state (classification + routing decision database writes).

**Completed**:
- ✅ Verified all 3 policy paths against expected output: billing → `auto_route`/`billing_team_queue` (regression check), legal → `escalate`/`critical_risk_flag`/priority `critical`, ambiguous → `escalate`/`low_confidence` (surfaced that `unknown` intent has a deliberate impossible threshold of `1.01`, so it always escalates regardless of confidence — confirmed as intentional design, not a bug)
- ✅ Fixed Respond to Webhook — `request_id` field was in Fixed mode holding literal `={{ }}` text; switched to Expression mode, now resolves real IDs
- ✅ Fixed Policy Engine — `cost_usd`/`latency_ms` were only present on the `budget_check` escalation branch even though both are computed for every request; added to all four `return` blocks
- ✅ Decided to skip the IF node for now (see Decision 8) — both branches currently do identical work
- ✅ Built "Write Classification" node (Postgres, Execute Query) — inserts to `classifications`; stubs `model_used` (`'gpt-4o-mini'`) and `validation_success` (`true`) since nothing tracks those yet; leaves `prompt_tokens`/`completion_tokens`/`total_tokens`/`validation_errors`/`raw_response` unmapped (genuinely untracked, not fake zeros)
- ✅ Built "Write Routing Decision" node (Postgres, Execute Query) — inserts to `routing_decisions`, same pattern
- ✅ Solved the jsonb-array insert problem (see Decision 9) — four failed attempts before landing on `to_jsonb($n::text[])`
- ✅ Verified both nodes with `jsonb_typeof()` — `risk_flags`/`policies_evaluated`/`policies_passed`/`policies_failed` all confirmed as real `array` type, not strings
- ✅ Cleaned up the double-encoded test rows (`id: 1` in both tables) left over from the failed attempts

**Stopped at**: Both DB-write nodes working and type-verified for the `auto_route` path (technical_issue test case). Not yet re-tested against the legal/ambiguous escalation paths through the new DB writes — those were only verified through Policy Engine + Respond to Webhook, before the Postgres nodes existed.

**Next**:
1. Re-run the legal and ambiguous test curls through the full updated pipeline (including the two new Postgres writes) — confirm rows land correctly for escalation cases too, not just auto_route
2. Trace assembly (`traces` table)
3. Slack integration for escalations
4. Duplicate detection guard
5. Revisit the IF node once auto_route vs escalate need genuinely different behavior

**Open Gaps**:
- [GAP: escalation paths not re-verified through DB writes] — only the auto_route/technical_issue case has a confirmed row in both tables
- [GAP: no schema.sql in repo] — tables exist only in Supabase, never version-controlled; plan.md's own artifact list calls for `database/schema.sql`
- [GAP: n8n unsaved-state trap] — lost an unsaved node's config once this session from a page refresh before saving; save after each node going forward, not just at session end
- [GAP: IF node deferred, not designed] — no behavioral split built for auto_route vs escalate destinations yet; needed before Slack/real-queue integration

**Experiments / Results**:

🧪 **jsonb array columns via n8n's "Insert" (column-mapper) operation**
- Hypothesis: passing a JS array, or a `JSON.stringify`'d array, would satisfy a `jsonb` column
- Result: ❌ Both rejected — "expects a object but we got array" / "...got '[]'" (string). The resource-mapper's validator only accepts plain JS objects for `jsonb`-typed fields, never arrays, regardless of representation.
- Learning: n8n's typed "Insert" operation has a real limitation with jsonb ARRAY columns specifically (jsonb OBJECT columns aren't affected). Switched to "Execute Query" with parameterized SQL instead.

🧪 **jsonb arrays via Execute Query with a plain `::jsonb` cast**
- Hypothesis: a raw JS array bound as a parameter, cast `$n::jsonb` in SQL, would insert correctly
- Result: ❌ "cannot cast type text[] to jsonb" — node-postgres binds JS arrays as a native Postgres ARRAY type, and `::jsonb` only knows how to parse text, not convert an array type.
- Learning: `to_jsonb($n)` is the correct converter from a native array to jsonb — but on its own it still failed on an empty array with "could not determine polymorphic type," since Postgres had no elements to infer the array's type from. Adding an explicit `::text[]` cast (`to_jsonb($n::text[])`) resolved both issues at once.
- Belief update: manually pre-stringifying an array before letting Postgres cast it double-encodes — the result is a jsonb *string* containing escaped JSON text, not a real array. Pass the raw array as the parameter and let `to_jsonb()` do the one and only conversion.

🧪 **Verifying jsonb type via Supabase's table UI vs `jsonb_typeof()`**
- Hypothesis: copying a row's JSON out of Supabase's Table Editor reflects the real stored value
- Result: ❌ False alarm — copied cells showed `risk_flags` as a quoted string even after the fix was working correctly. `jsonb_typeof(risk_flags)` against the live table confirmed `'array'`.
- Learning: don't trust a UI's copy-to-text rendering to verify a column's real type — ask the database directly (`jsonb_typeof()`, or equivalent) instead.

---

### Session 4 — 2026-09-17 to 2026-09-18
**Type**: BUILD
**Intent**: Leverage
**Goal**: Re-run the legal and ambiguous test emails from Session 3's handoff through the full pipeline, including the database writes.

**Completed**:
- ✅ Removed `HANDOFF.md` — it was the Session 2 handoff, already superseded by this file
- ✅ Fixed the project's `CLAUDE.md`, which still said the policy layer was not built — it had been done since Session 2
- ✅ Found and fixed a real bug: `Write Routing Decision` had no connection to `Respond to Webhook` in the n8n canvas. This broke silently when the two DB-write nodes were added in Session 3, and the webhook could not return a response until it was found
- ✅ Traced an OpenAI 429 error down to the real cause: the account had no credits left, not a rate limit
- ✅ Traced a second error, `Host not found` on the Postgres node, down to its real cause. n8n's error parser checks only for the text `ENOTFOUND` anywhere in the error message and always reports "Host not found" when it finds that text — even here, where the true error was Supabase's connection pooler saying `tenant/user not found`. That message is what Supabase's pooler returns when a project has been paused for inactivity, which is what had happened (the project had sat idle since Session 3, about three and a half weeks). Kemi resumed the project from the Supabase dashboard and the connection worked again
- ✅ Switched the classification step from OpenAI to Groq, since Kemi had no OpenAI credits left and could not add funds. Groq already had a saved, unused credential from Session 1. Replaced the OpenAI `Classify Email` node with a `Basic LLM Chain` node backed by a `Groq Chat Model` node, running `openai/gpt-oss-20b` (the older Llama models like `llama-3.1-8b-instant` are no longer offered on this Groq account, so this was the closest general-purpose instruct model still available)
- ✅ Updated `Policy Engine` to read from the new node and parse its output. Groq's `Basic LLM Chain` returns a much simpler shape than OpenAI's, just `{ text: "<JSON string as text>" }`, instead of OpenAI's nested `output[0].content[0].text`. Verified this shape with a real test run before writing the fix, then applied it by exporting the workflow with n8n's command-line tool, editing the JSON directly, and re-importing it — the in-browser code editor kept losing edits and text selections during this session, so this was faster and more reliable
- ✅ Ran one live test (billing email) against the production webhook after the fix. It returned a success response, which only happens after both database writes succeed, so the whole pipeline works end to end on the new Groq path

**Stopped at**: The Groq switch is verified end to end for the billing (auto-route) case only. The legal and ambiguous escalation cases, which were the actual goal carried over from Session 3, have not been re-run since the switch.

**Next**:
1. Run the legal and ambiguous test emails through the Groq-based pipeline and confirm the rows land correctly in both `classifications` and `routing_decisions`
2. Fix the `model_used` stub in `Write Classification` — still hardcoded to `'gpt-4o-mini'`, now wrong
3. Commit and push — nothing from this session is in git yet, and the n8n workflow itself is still not exported into the repo's `workflows/` folder
4. Continue the rest of Session 3's carryover: trace assembly, Slack integration, duplicate detection guard

**Open Gaps**:
- [GAP: legal/ambiguous paths not re-verified since the Groq switch] — only the billing/auto_route case has a confirmed successful run
- [GAP: `model_used` stub now inaccurate] — says `'gpt-4o-mini'`, should say the Groq model
- [GAP: nothing committed] — two sessions' worth of changes (Session 3 and 4) are sitting uncommitted; the workflow's real state lives only in the Docker volume, not in git
- [GAP: n8n browser code editor unreliable this session] — multi-line edits and dropdown selections kept resetting; exporting/editing/importing the workflow JSON through the command line worked every time it was tried and is worth defaulting to for code-node edits
- [GAP: `plan.md` badly out of date] — still lists OpenAI GPT-4o-mini as the primary LLM and GPT-3.5-turbo as the fallback, still shows most Phase 5 success criteria as unchecked even though several are done, and its "Last Updated" date is still 2026-03-19. Worth a dedicated pass to reconcile it with `session-log.md`, which is the file that has actually stayed current

**Experiments / Results**:

🧪 **n8n's "Host not found" error on a Postgres node**
- Hypothesis: a DNS lookup was genuinely failing inside the Docker container
- Result: ❌ Manual DNS lookups and raw TCP connects from inside the same container succeeded every time. The real error, found by reproducing the exact connection with the `pg` library directly, was Supabase's pooler returning `tenant/user postgres.<project-ref> not found` — the project had been auto-paused
- Learning: n8n's Postgres node maps *any* error message containing the substring `ENOTFOUND` to "Host not found," regardless of the real cause. Don't trust that message on its own — reproduce the connection directly to see the actual error text

🧪 **Groq's `Basic LLM Chain` output shape vs OpenAI's**
- Hypothesis: assumed it would need the same kind of nested navigation as OpenAI's response
- Result: ❌ It is much simpler — a single `{ text: "<JSON string>" }`, with the model's raw text answer as a string that still needs `JSON.parse()`
- Learning: check the actual output of a new node with a real run before writing code against it, the same lesson as Session 2's OpenAI output-shape surprise, now true for a second provider

---

### Session 5 — 2026-09-18
**Type**: BUILD
**Intent**: Leverage
**Goal**: Tidy the project notes, then close the gap left by the Groq switch, where nothing checked the LLM output format.

**Completed**:
- ✅ Reorganized `plan.md` and `session-log.md` so each opens with the goal, the next step, and what is completed. Rewrote `CLAUDE.md` to point to those two files instead of keeping its own status
- ✅ Added CHECK 0 (`output_validation_check`) to the Policy Engine. It checks that the output is a JSON object, that `intent` is one of the 5 categories, that `confidence` is a number from 0 to 1, that `summary` and `reasoning` are strings, and that `risk_flags` is a list of known flags. Any failure escalates with `escalation_reason: invalid_llm_output`, priority `high`, and a safe placeholder classification so the database writes still run
- ✅ Every Policy Engine result now carries `validation_success`, and Write Classification writes it instead of a hardcoded `true`
- ✅ Edited through the command line export and import. Reactivated with `n8n publish:workflow` and a container restart
- ✅ Live billing test on the production webhook returned success after the change
- ✅ Tested the bad output path against the real tables. Imported a temporary copy of the workflow, "TEMP bad output test (safe to delete)", on its own webhook, `/webhook/email-triage-badtest`. In the copy, a Code node named Basic LLM Chain returns a fake answer taken from the request, and a Read Back node selects the saved rows. Everything else is the real code. The copy was turned off after the test

- ✅ Saved the model's raw answer in `raw_response` and the check's errors in `validation_errors` for every classification. Retested with a fake legal answer that has a made-up flag. The row keeps the full answer, e.g., `"intent":"legal_escalation"`, and the error `unknown risk flags: legal_threat`
- ✅ Fixed `model_used`, which now records `openai/gpt-oss-20b`
- ✅ Fixed Insert Request. It pasted the email text inside quotes in the SQL, so an email with an apostrophe stopped the workflow with an empty reply. It now passes the values as query parameters. An email containing "can't" and "password's" now saves and routes correctly
- ✅ Built the duplicate check from the two unconnected nodes. Check Duplicate calls the existing `check_duplicate_request()` function and joins the saved decision. Is Duplicate? branches on `is_duplicate`. A new Respond Duplicate node returns the saved result. The summary check in check 0 now also enforces the database limit of 500 characters
- ✅ Ran the billing, legal, and ambiguous tests on Groq, plus the apostrophe email and a repeated billing email. Read back every row from the database through a temporary webhook workflow
- ✅ Read the full live schema and wrote `database/schema.sql`. Loaded it into an empty Postgres 16 container to confirm it runs. It created 6 tables and 30 indexes, the same count as the live database
- ✅ Exported the workflow to `workflows/email-triage-main.json`, with the owner's name and email removed

**Stopped at**: All Session 4 carryover is done. The next step is the trace design.

**Next**: See section 2.

**Open Gaps**:
- [GAP: test rows in Supabase] Rows from this session's tests. The fake answer tests have subjects starting with "bad output test:", and the live tests have bodies ending in "(test run 2026-09-18 b)". Delete them or keep them as examples
- [GAP: two temporary workflows left in n8n] "TEMP read back (safe to delete)" and "TEMP bad output test (safe to delete)" are both turned off. n8n's command line tool cannot delete workflows, so delete both in the n8n UI. `n8n execute` on the command line cannot load saved credentials in this n8n version, so a temporary workflow with a webhook trigger is the way to run a one-off query

**Experiments / Results**:

🧪 **Old Policy Engine against bad LLM output**
- Hypothesis: without a schema, some bad outputs would pass without anyone noticing
- Result: ✅ Confirmed. Offline, with 8 bad outputs, 4 were routed automatically: a string confidence, a confidence of 85, a made-up risk flag, and the intent `toString`. The other 4 crashed the workflow: text that is not JSON, JSON `null`, an unknown intent, and missing `risk_flags`
- Learning: `JSON.parse` succeeding only means the text is JSON. It says nothing about whether the values are usable. The new check escalates all 8 and leaves the 3 valid cases unchanged

🧪 **Bad output path against the real tables**
- Hypothesis: the new `escalation_reason` value `invalid_llm_output` might break a constraint on `routing_decisions`
- Result: ✅ No constraint problem. Three bad answers (not JSON, the made-up flag `legal_threat`, and a confidence of 85) each saved a row to both tables with `decision: escalate`, `escalation_reason: invalid_llm_output`, priority `high`, `validation_success: false`, and `risk_flags` stored as a real jsonb array. A good billing answer in the same run auto routed to `billing_team_queue` with all 4 checks passed
- Learning: the made-up flag case showed a new gap. The row says intent `unknown`, so a reviewer would not know the email was a legal threat. The raw answer needs saving (open issue 7)

🧪 **Live tests on Groq after all Session 5 changes**
- Hypothesis: billing auto routes, legal escalates as critical, ambiguous escalates for low confidence, and the new nodes do not break any of them
- Result: ✅ All as expected. Billing came back as `refund_request` at 0.95 with flag `refund`, and auto routed to `billing_team_queue`. Legal came back as `legal_escalation` at 0.95 with flags `lawsuit` and `compliance`, and escalated as critical. Ambiguous came back as `technical_issue` at 0.6, and escalated for low confidence. The apostrophe email auto routed to `support_tier1_queue`. Sending the billing email again returned `status: duplicate` with the saved decision
- Learning: the ambiguous case passed, but not the way the prompt intends (open issue 5)

---

### Session metrics

#### Session 1 (2026-03-19)
- Time: ~3 hours · Nodes: 6 · Tables: 6 · Tests: 4 · Bugs fixed: 3 · LoC: ~150

#### Session 2 (2026-05-04)
- Time: ~2.5 hours · Nodes added: 1 (Policy Engine) · LoC added: ~110 (JS in Code node) · Bugs hit: 4 (typo, missing else, wrong quotes, nested output) · Bugs fixed: 4
- Repo created + pushed: ✅
- Tests run: 1 (billing happy path only)

**Velocity note**: Session 2 was slow on the policy engine (JS learning curve + nested-output debug). Tomorrow should be faster — IF node and Postgres nodes are visual config, not raw code.

#### Session 3 (2026-08-25)
- Gap since Session 2: ~3.5 months · Nodes added: 2 (Write Classification, Write Routing Decision) · Bugs fixed: 2 (webhook expression, Policy Engine cost/latency inconsistency) · Bugs hit on the jsonb insert specifically: 4 (resource-mapper object-only validation, `::jsonb` cast on a native array type, double-encoding via manual `JSON.stringify`, polymorphic type unknown on an empty array)
- Tests run: 3 (billing, legal, ambiguous — all verified against Policy Engine output; only the billing/technical_issue path verified through the new DB writes so far)

**Velocity note**: most of this session went into the jsonb-array insert problem, not the DB-write design itself — four rounds of trial and error before landing on `to_jsonb($n::text[])`. Worth keeping as the reference pattern for any future jsonb-array column in this project.

#### Session 4 (2026-09-17 to 2026-09-18)
- Gap since Session 3: ~3.5 weeks · Bugs fixed: 2 (missing Write Routing Decision → Respond to Webhook connection, Policy Engine's dead reference to the deleted OpenAI node) · Root causes traced: 2 (OpenAI billing exhaustion, Supabase pooler "tenant not found" misreported as a DNS error) · LLM provider swapped: 1 (OpenAI → Groq, forced by zero OpenAI credits with no way to add funds)
- Tests run: 1 (billing, verified end to end on the new Groq path). Legal and ambiguous were the actual carried-over goal from Session 3 and are still not re-verified.

**Velocity note**: most of this session went into diagnosis, not the fix itself — two misleading error messages (n8n's generic 429 text, and its "Host not found" mislabel of a Supabase pooler error) each took real digging to trace to their true cause. Once the true causes were known, both the Supabase resume and the Groq swap were quick.

### What I learned

**Covered so far:**
- [x] Docker Compose basics — *Session 1*
- [x] Supabase vs self-hosted Postgres — *Session 1*
- [x] n8n workflow execution model — *Session 1*
- [x] OpenAI structured outputs (JSON Schema) — *Session 1*
- [x] n8n node referencing syntax — *Session 1*
- [x] JS basics (const, arrow fns, template strings) — *Session 2*
- [x] Optional chaining (`?.`) — *Session 2*
- [x] LLM API response shape (n8n OpenAI node) — *Session 2*
- [x] Git + GitHub workflow (init, .gitignore, push) — *Session 2*
- [x] Postgres Execute Query with parameter binding, and jsonb arrays — *Session 3*
- [x] Exporting and importing an n8n workflow as JSON from the command line — *Session 4*

**Still to learn:**
- [ ] n8n IF node configuration
- [ ] Handling node errors in n8n (retry, error branch)
- [ ] Circuit breaker implementation in n8n
- [ ] Postgres INSERT with RETURNING

---

## 7. Reference

### Before each session
1. Start n8n: `cd /Users/mac/Projects/ai-triage-system && docker compose up -d`
2. Check the Supabase project is not paused. Resume it from the dashboard if it is.
3. Open n8n at http://localhost:5678.
4. Read section 2 of this file.

### Project files
- `/Users/mac/Projects/ai-triage-system/`
- `plan.md` holds the goal and design. `session-log.md` holds progress and history. `CLAUDE.md` holds agent context.
- `docker-compose.yml`
- `.env` holds secrets and is not committed.
- `workflows/email-triage-main.json` holds the n8n workflow. `database/schema.sql` holds the database schema.

### Links
- GitHub repo: https://github.com/D2himself/ai-triage-system
- Supabase dashboard: https://supabase.com/dashboard
- n8n local: http://localhost:5678
- Groq console: https://console.groq.com
- n8n docs: https://docs.n8n.io
- Supabase docs: https://supabase.com/docs

### Docker commands
```bash
# Start n8n
cd /Users/mac/Projects/ai-triage-system
docker compose up -d

# Stop n8n
docker compose down

# View logs
docker compose logs -f n8n

# Restart n8n
docker compose restart n8n
```

### Test emails
These use the test webhook URL, which only listens after you click "Listen for test event" in
n8n. For the active workflow, use `/webhook/email-triage` instead of `/webhook-test/email-triage`.

```bash
# Billing email — should AUTO-ROUTE to billing_team_queue
curl -X POST http://localhost:5678/webhook-test/email-triage \
  -H "Content-Type: application/json" \
  -d '{
    "from": "customer@example.com",
    "subject": "Duplicate charge on my account",
    "body": "Hi, I noticed I was charged twice this month. Please refund the duplicate. Order #12345.",
    "customer_id": "cust_001"
  }'

# Legal email — should ESCALATE (compliance flag, critical priority)
curl -X POST http://localhost:5678/webhook-test/email-triage \
  -H "Content-Type: application/json" \
  -d '{
    "from": "legal@example.com",
    "subject": "GDPR data deletion request",
    "body": "Per GDPR Article 17, I am formally requesting deletion of all personal data you hold about me. Failure to comply within 30 days may result in a complaint to the data protection authority.",
    "customer_id": "cust_002"
  }'

# Ambiguous email — should ESCALATE (low confidence)
curl -X POST http://localhost:5678/webhook-test/email-triage \
  -H "Content-Type: application/json" \
  -d '{
    "from": "vague@example.com",
    "subject": "hi",
    "body": "is this thing working? need help.",
    "customer_id": "cust_003"
  }'
```

Sending the same email twice returns `status: duplicate` with the saved result. Change the body
slightly to rerun a test through the LLM.

### Supabase queries
```sql
-- Recent requests
SELECT * FROM requests ORDER BY created_at DESC LIMIT 10;

-- Classification for each request
SELECT r.subject, c.intent, c.confidence, c.risk_flags
FROM requests r
JOIN classifications c ON r.request_id = c.request_id
ORDER BY r.created_at DESC;

-- Latest routing decisions
SELECT * FROM routing_decisions ORDER BY id DESC LIMIT 5;

-- Check a jsonb column holds a real array, not a string
SELECT jsonb_typeof(risk_flags) FROM classifications ORDER BY id DESC LIMIT 5;
```

### Git
```bash
git status
git add .
git commit -m "feat: <what changed>"
git push
```
