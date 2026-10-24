# ADR-003: Simplify the Project Roadmap to Two Phases

**Status:** Accepted  
**Date:** 2026-10-24

## Context

The original Gym Data Pipeline roadmap consisted of four development phases. Some activities planned for the intermediate phases overlapped with work intended for the final phase.

Maintaining these phases separately would introduce unnecessary development steps and potentially duplicate work.

## Decision

Reduce the project roadmap from four phases to two:

- **Phase 1 — Manual End-to-End Pipeline:** Complete the current pipeline, including Gold development and validation.
- **Phase 2 — Final Pipeline:** Consolidate the remaining development into one final phase. Its architecture, requirements, and implementation scope will be defined after Phase 1.

The original Phases 2 and 3 will no longer be developed separately. Relevant activities will be considered during the planning of the new Phase 2.

## Rationale

The revised roadmap prioritizes completing the existing pipeline before introducing more advanced components.

Consolidating overlapping development activities reduces unnecessary work while preserving the project's long-term objectives.

## Consequences

- Reduces potential duplication across development phases.
- Keeps the immediate focus on completing Phase 1.
- Allows the final architecture to incorporate lessons learned from the manual pipeline.
- Requires updates to existing roadmap and milestone documentation.
- Leaves detailed Phase 2 requirements open until the planning stage.

## Next Steps

Complete and validate the Gold layer, close the remaining Phase 1 requirements, and begin planning the final Phase 2.