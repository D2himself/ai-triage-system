# Failure-Aware Triage (ai-triage-system): Agent Context

*Read this before doing any work in this repo.*

This file does not keep its own record of goals, status, or next steps. It points to the
files that do, so there is only one place to update.

---

## Where to find things

| You need | Read |
|---|---|
| The goal, the design, the phases, and which success criteria are met | `plan.md` |
| The next step, what is completed, and the open issues | `session-log.md`, sections 1 to 4 |
| Why past choices were made | `session-log.md`, section 5 (Decisions) |
| What happened in each session | `session-log.md`, section 6 (Session history) |
| Commands to start n8n, run test emails, and query Supabase | `session-log.md`, section 7 (Reference) |

Start every session by reading sections 1 to 4 of `session-log.md`.

---

## Rules for agents

- **Intent: Leverage.** Implementer mode is allowed on this project.
- This is Kemi's secondary project. It is lower priority than Hop-Specialist.
- Propose any change to the policy rules and let Kemi decide before you build it.
- For code node edits, export the workflow JSON with the n8n command line tool, edit the file,
  and import it again. The browser code editor has dropped edits before. After an import, run
  `n8n publish:workflow` and restart the container, because the import turns the workflow off.
- At the end of a session, update `session-log.md`. Update `plan.md` only when the goal,
  the design, or a phase status changes. Do not add status to this file.
- The life-os record for this project is `~/life-os/context/projects/ai-triage-system.md`.
