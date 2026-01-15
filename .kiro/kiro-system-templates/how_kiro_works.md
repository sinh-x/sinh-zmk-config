# How Kiro Works

Kiro is an AI assistant that helps you build features systematically through a structured spec-driven development process.

## Core Philosophy

Instead of jumping straight into code, Kiro guides you through three phases:
1. **Requirements** - What needs to be built
2. **Design** - How it will be built
3. **Tasks** - Step-by-step implementation plan

This ensures every feature is well-planned before implementation begins.

## The Spec Structure

Each feature gets its own folder in `.kiro/specs/{feature-name}/` containing:

- `requirements.md` - User stories and acceptance criteria
- `design.md` - Technical architecture and implementation approach
- `tasks.md` - Actionable coding checklist

## Workflow Process

### Phase 1: Requirements Gathering
- I create initial requirements based on your feature idea
- Uses user stories format: "As a [role], I want [feature], so that [benefit]"
- Includes acceptance criteria in EARS format (Easy Approach to Requirements Syntax)
- Example: "WHEN user clicks submit THEN system SHALL validate all fields"
- We iterate until you approve the requirements

### Phase 2: Design Documentation
- I research and create a comprehensive design.md
- Covers architecture, components, data models, error handling, testing strategy
- May include Mermaid diagrams for visual representation
- Addresses all requirements from the previous phase
- We iterate until you approve the design

### Phase 3: Task Planning
- I break down the design into actionable coding tasks in tasks.md
- Creates numbered checklist items (1.1, 1.2, etc.)
- Each task references specific requirements
- Focuses only on code implementation activities
- Prioritizes incremental, testable progress
- We iterate until you approve the task list

## Key Features

- **Iterative Approval** - You must explicitly approve each document before moving to the next
- **Requirement Traceability** - Tasks link back to specific requirements
- **Incremental Development** - Tasks build on each other progressively
- **Code-Focused** - Tasks only include activities a coding agent can execute

## Task Execution

Once your spec is complete, you can execute tasks by:
- Opening the `tasks.md` file
- Clicking "Start task" next to individual task items
- I'll implement one task at a time, stopping for your review between tasks

## When to Use Kiro (and When Not To)

The full Kiro spec-driven process is designed for **new features and complex changes**. Using it for small fixes is "like using a sledgehammer to crack a nut" - the overhead isn't worth it.

### Decision Guide

| Change Type | Approach | Documentation |
|-------------|----------|---------------|
| **Quick fix** (1-2 files, obvious solution) | Skip specs | Good commit message |
| **Bug fix** (needs investigation) | Bug fix workflow | `.kiro/bugs/` |
| **Small feature** (< 3 tasks) | Judgment call | Consider skipping specs |
| **Medium/Large feature** | Full Kiro process | `.kiro/specs/` |

### Signs You Should Use Full Specs
- Multiple files need changes
- Architectural decisions required
- Multiple valid approaches exist
- Requirements are unclear
- Changes affect existing behavior

### Signs You Should Skip Specs
- Single file change
- Obvious solution
- Pure config tweak
- Typo or formatting fix

## Bug Fix Workflow

For bugs that need investigation but don't warrant full specs, use the lightweight **Report → Analyze → Fix → Verify** workflow.

### Bug Documentation Structure

```
.kiro/bugs/<bug-name>/
├── report.md       # What's broken, how to reproduce
├── analysis.md     # Root cause investigation (optional)
└── resolution.md   # Solution and verification
```

### When to Use Bug Workflow vs Git Only

- **Git only**: Quick fixes with obvious solutions (typos, simple config errors)
- **Bug workflow**: Issues requiring investigation, debugging, or multiple attempts

## Getting Started

To begin a new feature spec, simply describe your idea and I'll guide you through the three-phase process. For existing specs, I can help review, update any phase, or execute implementation tasks as needed.

For bug fixes, create a report in `.kiro/bugs/` and work through the Report → Analyze → Fix → Verify process.
