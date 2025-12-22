# Shiny Module Reactivity Analysis

Analyze the reactivity of the specified Shiny module and generate structured documentation.

## File to analyze

$ARGUMENTS

## Analysis steps

1. **Search for reactiveVal and reactive** in the file
2. **Search for all observe_event()** and identify their triggers
3. **Identify triggers** (reactiveVal used to trigger cascades, typically named `*_trigger`)
4. **Trace reactivity chains**: State → Primary trigger → Cascade → Composite trigger → Output
5. **Identify potential redundancies**:
   - Multiple observers on the same state
   - Non-cascade patterns (using `list()` in observe_event)
   - Observers calling functions directly instead of going through cascade pattern
   - Unused or duplicated triggers

## Documentation structure to generate

Generate a comment section to insert in the file, right after the existing MODULE STRUCTURE OVERVIEW (or at the beginning of the file if it doesn't exist). Use this exact format:

```
# REACTIVITY OVERVIEW ====
#
# This module uses a CASCADE PATTERN for reactivity management.
# Instead of having observers with multiple triggers like observe_event(c(a(), b(), c())),
# we use:
#   1. PRIMARY STATE REACTIVES: The actual state values
#   2. PRIMARY TRIGGERS: Fire when state changes
#   3. CASCADE OBSERVERS: Listen to primary triggers and fire COMPOSITE TRIGGERS
#   4. COMPOSITE TRIGGERS: Aggregated triggers that UI observers listen to
#   5. UI OBSERVERS: Render outputs when their composite trigger fires
#
# Flow: State change -> Primary trigger -> Cascade -> Composite trigger -> UI update
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ PRIMARY STATE REACTIVES (reactiveVal)                                                           │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │ variable_name                 - Short description of the state                                  │
# │ other_variable                - Short description                                               │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ CASCADE FLOW DIAGRAM                                                                            │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  PRIMARY STATE              PRIMARY TRIGGER           CASCADE OBSERVER           COMPOSITE      │
# │  CHANGE                     (fires)                   (propagates to)            TRIGGERS       │
# │  ─────────────────────────────────────────────────────────────────────────────────────────────  │
# │                                                                                                 │
# │  state_name() ────────────► state_trigger ──────────► observe_event(state_trigger)             │
# │                                                       ├──► composite_trigger_1                 │
# │                                                       └──► composite_trigger_2                 │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ COMPOSITE TRIGGERS → UI OBSERVERS                                                               │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  composite_trigger_1 ────────────────► output$output_name (renderUI/renderDT)                  │
# │  composite_trigger_2 ────────────────► output$other_output (renderUI)                          │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ DIRECT OBSERVERS (Not part of cascade - direct user interactions)                               │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  INPUT EVENT                           ACTION                                                   │
# │  ─────────────────────────────────────────────────────────────────────────────────────────────  │
# │  input$button_name ──────────────────► Modifies state_name(), calls function                   │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ SPECIAL OBSERVERS                                                                               │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  reactive_param() ───────────────────► Description of what it does                             │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
#
# ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
# │ POTENTIAL REDUNDANCIES / AREAS FOR REVIEW                                                       │
# ├─────────────────────────────────────────────────────────────────────────────────────────────────┤
# │                                                                                                 │
# │  1. Description of the potential issue identified                                               │
# │  2. Another potential issue                                                                     │
# │                                                                                                 │
# └─────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Instructions

- Use aligned ASCII boxes (99 characters inner width)
- Align arrows `►` for clear reading
- Use `├──►` for intermediate branches and `└──►` for the last branch
- List ALL reactiveVal, not just those that are part of the cascade pattern
- If the module doesn't use the cascade pattern, still document the reactivity and suggest improvements
- Insert the generated documentation in the file after the MODULE STRUCTURE OVERVIEW
