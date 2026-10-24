# ADR-001: Exclusion of Third-Set Data from the Gold Layer

**Date:** 2026-10-21  
**Status:** Accepted  
**Scope:** Gold Layer

## Context

Dataset inspection identified third-set weight and repetition values recorded on only 11 workout days. The current training routine consists of two working sets per exercise.

The Gold layer needs a consistent rule for calculating exercise progression across historical workout sessions.

## Options Considered

- **Option 1:** Include third-set data in Gold calculations.
- **Option 2:** Exclude third-set data from Gold calculations.

## Decision

Exclude third-set weight and repetition values from Gold calculations while preserving the original data in Bronze and Silver.

Only Sets 1 and 2 will be considered when calculating maximum weight progression.

## Rationale

- The current training routine uses two working sets per exercise.
- Third-set records reflect an earlier training approach.
- Using Sets 1 and 2 provides a consistent basis for the intended progression metric.

## Trade-offs

**Advantages**

- Aligns Gold calculations with the current training routine.
- Simplifies maximum weight progression calculations.

**Disadvantages**

- Historical third-set performance is excluded from Gold metrics.
- Future analyses involving all performed sets will require different calculation rules.

## Consequences

- Bronze and Silver retain all recorded sets.
- Gold progression metrics consider Sets 1 and 2 only.
- The exclusion of Set 3 must remain explicit in metric definitions.

---

## Amendment: Include Repetitions in Weight Progression

**Date:** 2026-10-24  
**Status:** Accepted

### Context

Maximum weight alone does not fully describe exercise performance. Repetitions provide additional context when comparing the same exercise across workout sessions.

### Decision

The Gold layer will track the maximum recorded weight for each exercise within each workout session, together with the repetitions performed at that weight.

The following rules apply:

- Only Sets 1 and 2 are considered.
- Repetitions must correspond to the selected maximum weight.
- No minimum repetition requirement is applied.
- When multiple sets or records share the maximum weight within the same workout session and exercise, the highest corresponding repetition count is selected.

### Rationale

Including repetitions provides additional context for weight progression without excluding performances below a fixed repetition target.

Selecting the highest corresponding repetition count when maximum weights are tied establishes a consistent tie-breaking rule.

### Consequences

- Maximum weight and repetitions must remain correctly paired during SQL transformations.
- Equal-weight records require repetition-based tie-breaking.
- Missing values must be handled without assigning repetitions from a different weight.
- Gold calculations must follow these rules before their results are used in Power BI.