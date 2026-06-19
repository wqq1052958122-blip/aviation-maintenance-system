# AGENTS.md

## Project

This is a database course final project: Aviation Component Lifecycle and Maintenance Management System.

The project has three parts:

* `db/`: MySQL database scripts
* `backend/`: FastAPI backend
* `aviation-frontend/`: Vue frontend

The database is the core of the project. Do not move business rules from the database into frontend-only logic.

## Communication language

1. All plans, summaries, verification reports, and explanations must be written in Chinese.
2. Keep code identifiers, API paths, database table names, view names, stored procedure names, and file paths in their original English form.
3. Do not translate existing code variable names or database object names.
4. User-facing documentation may be written in Chinese.
5. Error messages may remain in English when they come from existing database triggers or backend logic, unless the user explicitly requests a translation.

## Main database requirements

The project must emphasize:

1. lifecycle tracking;
2. history preservation;
3. database constraints;
4. triggers for illegal operation rejection;
5. stored procedures and transactions;
6. complex queries and views;
7. soft retirement instead of physical delete.

## Important database objects

Tables:

* Aircraft
* ComponentModel
* Component
* InstallationRecord
* MaintenanceRecord
* FlightLog
* RetirementRecord
* Operator

Views:

* v_current_installation
* v_component_profile
* v_component_lifecycle
* v_component_flight_usage
* v_model_maintenance_stats

Stored procedures:

* sp_replace_component
* sp_retire_component
* sp_complete_maintenance

## Development rules

1. Keep the database as the source of truth for business rules.
2. Do not bypass stored procedures for replacement, retirement, or maintenance completion.
3. Do not add DELETE operations for core business tables.
4. Keep API response format consistent.
5. Do not hardcode database passwords.
6. Prefer small, safe changes over large rewrites.
7. After changes, explain modified files and how to test them.

## Frontend rules

The frontend should stay simple and clear. This is not a UI-heavy project.

Important frontend tasks:

* show component lifecycle clearly;
* show current installation records;
* show flight usage statistics for a component;
* show database error messages clearly;
* avoid duplicate buttons, debug console logs, and old commented code.

## Backend rules

The backend should:

* validate request shape with Pydantic schemas when possible;
* call database views and stored procedures;
* catch database errors and return readable messages;
* avoid duplicating business rules already enforced by triggers/procedures.

## Done means

A change is done only if:

1. code compiles or can be reasonably run;
2. changed endpoints match frontend calls;
3. database object names match the SQL scripts;
4. no hardcoded password is introduced;
5. the change is documented in a short summary.
   git status
   git diff --stat
