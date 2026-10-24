# ADR-004: Use Power BI Instead of Streamlit

**Status:** Accepted  
**Date:** 2026-10-24  
**Scope:** Dashboard Development

## Context

The original pipeline design included Streamlit for dashboard development. However, building and maintaining a custom Python application would introduce additional work beyond the project's primary focus on Data Engineering.

Power BI and Tableau were considered as alternatives.

## Decision

Use Power BI instead of Streamlit for dashboard development.

Power BI integrates with SQL Server and supports visualization of analytics-ready Gold datasets without requiring a custom Python dashboard application.

## Rationale

The project prioritizes data ingestion, transformation, validation, and database design.

Using Power BI allows dashboard development to remain focused on reporting and visualization while reducing the need for additional application development.

## Consequences

- Reduces custom dashboard development and maintenance.
- Separates data engineering from business intelligence reporting.
- Introduces practical experience with Power BI.
- Requires basic Power BI data modeling and DAX knowledge where necessary.

## Next Steps

- Complete and validate the Gold datasets.
- Use the Balanced Analytics dashboard layout defined in ADR-005.
- Connect Power BI to the validated Gold datasets.
- Develop and test the approved dashboard visualizations.