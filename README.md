# Lattice

Personal autonomous systems layer. Not a chatbot. Not a task manager.
An always-on control plane for delegating cognitive labor.

Lattice proposes work, humans approve, Lattice scaffolds, humans implement.

## Quick Start

Prerequisites:
- Elixir >= 1.14
- `gh` CLI ([install](https://cli.github.com/)) — authenticated with `gh auth login`

```bash
mix deps.get
mix lattice.run
```

This runs one manager iteration:

1. Loads the constitution (`docs/product-directive.md`, `docs/technical-opinion.md`)
2. Initializes `.lattice/` directory
3. Creates a backlog if none exists (derived from constitution)
4. Selects the next task candidate
5. Generates a proposal in `.lattice/proposals/`
6. Opens a GitHub Issue for that task (labeled `proposed`)
7. Waits for human approval

### Continuous mode

```bash
mix lattice.run --loop
```

Runs the iteration every 30 seconds until interrupted.

## How It Works

Lattice operates as a **propose-approve-scaffold-implement** loop:

```
Lattice proposes → human approves → Lattice scaffolds → human implements → merge → repeat
```

### GitHub as the Control Plane

GitHub is the human approval substrate. No custom approval systems.

| Primitive  | Role                    |
|------------|-------------------------|
| Issues     | Intent approval         |
| PRs        | Execution approval      |
| Comments   | Negotiation             |
| Labels     | State machine           |
| Merges     | Commitment to reality   |

### Label State Machine

Issues move through these labels:

- `proposed` — Lattice has proposed this work
- `approved` — Human has approved intent (add this label to proceed)
- `in-progress` — Work is underway
- `blocked` — Work is blocked
- `done` — Complete

**Lattice will NOT execute work unless the Issue is labeled `approved`.**

### Approval Flow

1. Run `mix lattice.run` — Lattice creates a GitHub Issue with label `proposed`
2. Review the Issue and proposal
3. Add the `approved` label to the Issue
4. Run `mix lattice.run` again — Lattice detects approval, generates PR scaffold
5. Implement the task on the suggested branch
6. Open a PR linking the Issue
7. Review, approve, merge

Lattice never merges PRs autonomously.

## Backlog and Proposals

### Backlog

Stored at `.lattice/backlog.md`. Human-readable markdown with pending tasks
derived from the constitution. First pending task is always the next candidate.

### Proposals

Generated in `.lattice/proposals/YYYYMMDD-HHMM-task-slug.md`. Each contains:

- Objective
- Acceptance criteria
- Risks
- Test plan
- Dev impact
- Docs impact

## Event Log

Every meaningful action appends to `.lattice/events.log` (JSON lines format).

Events are immutable. State can be rebuilt from the log.

```bash
# View recent events
tail -20 .lattice/events.log | python3 -m json.tool --no-ensure-ascii
```

## Configuration

### Environment Variables

| Variable                 | Default  | Description                          |
|--------------------------|----------|--------------------------------------|
| `LATTICE_WRITE_ACTIONS`  | `true`   | Kill switch for all GitHub/Fly writes |
| `LATTICE_ENABLE_FLYCTL`  | `false`  | Enable flyctl integration            |
| `FLY_ACCESS_TOKEN`       | —        | Fly.io API token                     |
| `GITHUB_TOKEN`           | —        | GitHub token (or use `gh auth login`) |

Copy `.env.example` to `.env` and adjust as needed.

### Kill Switch

Set `LATTICE_WRITE_ACTIONS=false` to disable all external write operations.
Lattice still runs locally — generates proposals and logs events — but
creates no Issues, PRs, or Fly deployments.

## Fly.io Deployment

### Build and Deploy

```bash
fly apps create lattice
fly secrets set GITHUB_TOKEN=ghp_...
fly deploy
```

### Scheduled Machines

Lattice is designed for Fly Scheduled Machines — start, iterate, exit.

```bash
# Create a scheduled machine that runs every 5 minutes
fly machine run . --schedule "*/5 * * * *" --region ord
```

The Docker container runs one manager iteration and exits. Each invocation:

- Checks the backlog
- Proposes or follows up on the next task
- Scaffolds PRs for approved work
- Exits cleanly

No internal scheduler. No long-running process. Just cron-compatible iterations.

### Environment

Set via `fly secrets` or `fly.toml`:

```bash
fly secrets set GITHUB_TOKEN=ghp_... LATTICE_WRITE_ACTIONS=true
```

## flyctl Guardrails

The `Lattice.Fly` module enforces strict controls on flyctl usage:

- **Disabled by default** (`LATTICE_ENABLE_FLYCTL=false`)
- **Command allowlist** — only known commands are permitted
- **SAFE commands** (read-only): `status`, `list`, `info`, `logs`
- **CONTROLLED commands** (write): `deploy`, `scale`, `secrets`, `machine`
  - CONTROLLED commands require a GitHub Issue labeled `approved`
- **All flyctl usage is logged** to the event log
- **Auth via `FLY_ACCESS_TOKEN`** environment variable

Unknown commands (e.g. `destroy`, `rm`) are rejected regardless of configuration.

## Development

### Run Tests

```bash
mix test
```

Tests are integration-focused. Each test creates isolated temp directories.
No mocks except for `gh` CLI calls.

### Format

```bash
mix format
```

### Project Structure

```
docs/                          # Constitutional documents (immutable)
  product-directive.md
  technical-opinion.md
lib/
  lattice.ex                   # Root module
  lattice/
    application.ex             # OTP application
    manager.ex                 # Manager loop (core)
    constitution.ex            # Reads governing docs
    event_log.ex               # Append-only event log
    backlog.ex                 # Backlog management
    proposal.ex                # Proposal generation
    github.ex                  # GitHub integration via gh
    fly.ex                     # flyctl capability module
    scaffold.ex                # PR scaffolding
  mix/tasks/
    lattice.run.ex             # Mix task CLI
test/                          # Integration tests
config/                        # Environment configs
.github/workflows/ci.yml      # CI pipeline
Dockerfile                     # Fly.io deployment
fly.toml                       # Fly.io config
```

### Constitutional Documents

`docs/product-directive.md` and `docs/technical-opinion.md` are immutable.
They define what Lattice is and how it is built. All features, backlog items,
and architectural decisions trace back to these two documents.

Do not modify them.
