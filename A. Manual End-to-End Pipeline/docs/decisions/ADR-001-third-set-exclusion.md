# Engineering Decisions

## ADR-001: Exclusion of Third-Set Data from the Gold Layer

**Date:** 2026-10-21  
**Scope:** Gold Layer

### Context

Upon inspecting the workout dataset, I observed that third-set weight and repetition values were recorded on only 11 workout days. My current training routine consists of two working sets per exercise.

### Options Considered

- **Option 1:** Retain third-set data in Gold calculations.
- **Option 2:** Exclude third-set data from Gold calculations.

### Decision

I decided to exclude third-set weight and repetition values from the Gold layer while preserving them in the Bronze and Silver layers.

### Reasoning

- My intended workout routine consists of two working sets per exercise.
- Third-set data represents an earlier training approach that falls outside the scope of my intended Gold analytics.
- Gold metrics will therefore be calculated using only Sets 1 and 2.

### Trade-offs

**Advantages**
- Gold metrics align with my defined training model.
- Calculations are simpler and focused on two-set workout progression.

**Disadvantages**
- Gold metrics will not account for historical third-set performance.
- Future analyses requiring all performed sets will need different calculation rules.

### Consequences

- Bronze and Silver remain unchanged, preserving the original and standardized historical records.
- Gold calculations will exclude third-set weight and repetition values.
- Gold metric definitions must explicitly document this limitation.