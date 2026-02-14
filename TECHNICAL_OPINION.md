# Lattice Technical Opinion

This document captures architectural posture, not implementation details.
These are strong opinions, loosely held — but default positions.

## Core Architecture

Lattice is fundamentally:

- distributed
- event-driven
- agent-oriented
- stateful

It is not monolithic.
It is a constellation of cooperating processes.

## Language Philosophy

**Primary runtime: Elixir**

Because:

- lightweight processes
- supervision trees
- fault tolerance
- native concurrency
- message passing as a first-class concept

Lattice assumes:

- things fail
- workers crash
- networks partition

Elixir embraces this reality instead of fighting it.

## Execution Substrate

**Primary compute model: long-lived remote agents**

Agents are:

- addressable
- stateful
- independently deployable
- resumable

They do not disappear after a single task.
They persist.

This enables:

- ambient background work
- continuous monitoring
- durable context

Stateless serverless is insufficient for this system.

## Authentication

Clerk is used for identity.

Auth must be:

- boring
- reliable
- outsourced

Operator identity is sacred.
Everything else is negotiable.

## Walking Skeleton Always

Every new capability starts as a vertical slice:

- API
- agent behavior
- persistence
- local dev
- tests
- docs
- deployment

All at once.
No horizontal layers.
No scaffolding phases.

Lattice grows via end-to-end increments only.

## Vertical PRs Only

A pull request is not complete unless it includes:

- feature implementation
- tests
- local dev instructions
- CI/CD updates (if needed)
- documentation

If it doesn't ship fully, it doesn't ship.

This prevents architectural debt and tribal knowledge.

## Everything Is Tested

Not for coverage.
For confidence.

Tests exist to prove:

- agents recover from failure
- messages arrive out of order safely
- state resumes correctly
- orchestration logic behaves under load

Property tests where possible.
Integration tests over mocks.

## Local-First Development

You must be able to run Lattice locally.
Full stop.

Local dev includes:

- agents
- orchestration
- auth stubs
- persistence
- background workers

If something only works in prod, it doesn't work.

## Event Logs Are Sacred

Every meaningful action produces an event.

Events are immutable.
Derived state is disposable.

This enables:

- replay
- debugging
- audit trails
- future intelligence layers

State can be rebuilt.
History cannot.

## Agent Taxonomy

Lattice recognizes several archetypes:

- **Manager** – coordinates goals
- **Workers** – execute tasks
- **Scouts** – gather information
- **Auditors** – verify outcomes
- **Schedulers** – manage time-based activation

These are conceptual roles, not necessarily classes.

## Autonomy Is Budgeted

Agents never receive unlimited authority.

They operate within:

- time budgets
- financial budgets
- scope constraints

All autonomy is bounded.

## CI/CD Philosophy

Deployment must be:

- automatic
- boring
- reversible

Shipping is not a ceremony.
It is a side effect of merging.

## Observability First

Before features:

- logs
- metrics
- traces

If you can't see it, you can't trust it.

## No Premature Platforms

Lattice avoids:

- speculative abstractions
- generalized frameworks
- premature plugin systems

Capabilities emerge from usage.
Architecture follows behavior.

## Five-Year Rule

Every technical decision is filtered through:

> Would this still make sense in five years?

If not, it's probably a shortcut.

## Summary

Lattice is built like critical infrastructure:

- resilient
- observable
- incremental
- operator-centric

It favors:

- systems thinking over features
- autonomy over workflows
- durability over velocity
- clarity over cleverness

It is designed to grow alongside you.
