# PaglaMLX Task Orchestration Plan

## Overview

Two parallel workstreams:
- **Workstream A**: 6 operational gaps (thermal, restart, dashboard, warm-pool, memory, port collision)
- **Workstream B**: HIG design polish (color, typography, layout, window conventions)

---

## Workstream A — PaglaMLX Operational Gaps

### A0. Port 8000 Collision (Trivial)
| Field | Value |
|-------|-------|
| **File** | `ModelOrchestrator.swift:192` |
| **Change** | `private var nextPort = 8000` → `private var nextPort = 2526` |
| **Est. time** | 5 min |
| **Est. tokens** | ~500 (read + single-line edit) |
| **Sub-agent** | No need — direct edit |
| **Success** | New model instances start on 2526+ |
| **Error** | None possible |
| **Handoff** | → A1 blocker: none, can run in parallel |

### A1. Thermal Monitoring
| Field | Value |
|-------|-------|
| **Files** | New `ThermalMonitor.swift` + ContentView + MenuBarView |
| **What** | Read `powermetrics` via subprocess or `sysctl machdep.xcpm` for CPU temperature / thermal pressure |
| **Est. time** | 1.5 hr |
| **Est. tokens** | ~4,000 (new file + view edits) |
| **Sub-agent** | `Task → "Create ThermalMonitor.swift"` (model layer) then direct edits (view layer) |
| **Success** | Menu bar shows 🌡️ reading, main view has thermal gauge |
| **Error** | `powermetrics` requires root → fallback to thermal pressure via `ProcessInfo.thermalState` |
| **Handoff** | → A5 merge into shared `SystemMonitorManager` if both pass |

### A2. Auto-Restart on Crash
| Field | Value |
|-------|-------|
| **Files** | `ModelInstance.swift` (terminationHandler), `ModelOrchestrator.swift` (restart logic) |
| **What** | When process exits non-zero, wait 3s, re-check health, auto-start with exponential backoff (3s, 10s, 30s, 60s cap) |
| **Est. time** | 1.5 hr |
| **Est. tokens** | ~3,500 |
| **Sub-agent** | `Task → "Extend ModelInstance with auto-restart"` — modify terminationHandler + add restartBackoff state |
| **Success** | Killing mlx_lm subprocess manually triggers auto-restart within 10s |
| **Error** | If crashing repeatedly (>5 times), give up and show alert — do not loop forever |
| **Handoff** | Depends on A3 for crash log integration but can be done independently |

### A3. Activity Dashboard
| Field | Value |
|-------|-------|
| **Files** | New `ActivityTracker.swift` + new `ActivityDashboardView.swift` + ContentView (add tab) |
| **What** | Track request count, tok/sec rolling average, latency, error rate per model. Show as a panel in ContentView. |
| **Est. time** | 3 hr |
| **Est. tokens** | ~6,000 (model + view + integration) |
| **Sub-agent** | `Task → "Create ActivityTracker"` (data model), separate `Task → "Create ActivityDashboardView"` (UI) |
| **Success** | Typing `curl ...` against the gateway populates dashboard metrics |
| **Error** | Need gateway integration point — RoutingGateway must report metrics. Fallback: poll /v1/models metrics |
| **Handoff** | Integrates with A2 (crash events), A5 (memory pressure context) |

### A4. Model Warm-Pool
| Field | Value |
|-------|-------|
| **Files** | `ModelInstance.swift` (warm method), `ModelOrchestrator.swift` (+ "warm" button), `ContentView.swift` |
| **What** | Pre-load model by sending a dummy completion request right after start, or keep a "hot" model loaded |
| **Est. time** | 2 hr |
| **Est. tokens** | ~4,000 |
| **Sub-agent** | `Task → "Add model warm-pool to ModelOrchestrator"` |
| **Success** | First real request after warm shows <500ms response instead of 5s+ cold start |
| **Error** | Warm request fails → model still works, just not pre-heated. Log warning. |
| **Handoff** | None — independent feature |

### A5. Memory Pressure Monitoring
| Field | Value |
|-------|-------|
| **Files** | New `MemoryMonitor.swift` + ContentView (merge with A1 panel) + MenuBarView |
| **What** | Read `vm_stat` / `sysctl vm.swapusage` / `host_statistics64`. Show used memory, swap, compressed, memory pressure level. |
| **Est. time** | 1 hr |
| **Est. tokens** | ~3,000 |
| **Sub-agent** | Merge with A1 into shared `SystemMonitorManager.swift` |
| **Success** | UI shows memory pressure (green/yellow/red) alongside thermal |
| **Error** | macOS SIP may block some sysctl calls → fallback to `ProcessInfo.physicalMemory` |
| **Handoff** | Merge into A1 SystemMonitorManager at completion |

---

## Workstream B — HIG Design Polish

### B0. Design Token Foundation (Prerequisite for B1-B4)
| Field | Value |
|-------|-------|
| **File** | New `DesignTokens.swift` |
| **What** | Centralize colors, fonts, spacing from the Apple design palette |
| **Est. time** | 30 min |
| **Est. tokens** | ~2,000 |
| **Success** | Single file defines all design constants |
| **Handoff** | → B1, B2, B3, B4 all depend on this |

### B1. Color System
| Field | Value |
|-------|-------|
| **Files** | All view files (9 SwiftUI files) |
| **What** | Replace hardcoded hex colors with DesignTokens. Use `.tint()`, `.foregroundStyle(.secondary)`, Material, `.background(.background)` |
| **Est. time** | 2 hr |
| **Est. tokens** | ~8,000 |
| **Sub-agent** | Split into 3 sub-agents: (1) SettingsView + ProviderRow, (2) ContentView + detailView, (3) MenuBarView + PreflightView |
| **Success** | No hex strings remain in view files (except DesignTokens.swift) |
| **Error** | Some NSColor references must stay (AppKit interop) — document each exception |
| **Handoff** | → B3 (layout) builds on color work |

### B2. Typography
| Field | Value |
|-------|-------|
| **Files** | All view files |
| **What** | Replace ad-hoc font sizes with `.headline`, `.subheadline`, `.caption`, `.body`. Remove "Lucida Grande" usage (not a macOS system font; should be SF Pro). |
| **Est. time** | 1.5 hr |
| **Est. tokens** | ~6,000 |
| **Sub-agent** | Split by file (same as B1) |
| **Success** | All text uses semantic font styles, no hardcoded font names |
| **Error** | Monospaced usage is intentional (code blocks, logs) — preserve `.design(.monospaced)` |
| **Handoff** | Independent of B1, but aesthetically better done after B1 |

### B3. Spacing & Layout
| Field | Value |
|-------|-------|
| **Files** | All view files |
| **What** | Standardize padding (HIG: 8px grid), group box insets, toolbar spacing, list row insets |
| **Est. time** | 1.5 hr |
| **Est. tokens** | ~5,000 |
| **Success** | Consistent 8px grid across all views |
| **Handoff** | Best done after B1 (don't fight color + spacing changes in same agent) |

### B4. Window & Sheet Conventions
| Field | Value |
|-------|-------|
| **Files** | `PaglaMLXApp.swift`, `ContentView.swift`, `SettingsView.swift` |
| **What** | Sheet sizing with `.ideal`, proper `.windowResizability`, `.contentMargins`, Settings window sizing |
| **Est. time** | 1 hr |
| **Est. tokens** | ~2,000 |
| **Success** | Windows resize gracefully, sheets have correct sizing, Settings matches HIG |

---

## Master Dependency Graph

```
A0 (port) ──no deps──→ (anytime)
A1 (thermal) ──no deps──→ standalone
A2 (restart) ──no deps──→ standalone
A3 (dashboard) ──no deps──→ standalone
A4 (warm-pool) ──no deps──→ standalone
A5 (memory) ──no deps──→ standalone (merge into A1's SystemMonitorManager)
B0 (tokens) ──blocker──→ B1, B2, B3, B4
B1 (color) ──recommended before──→ B3 (layout)
B2 (typo) ──independent──→ B1, B3
B3 (layout) ──prefers after──→ B1
B4 (windows) ──independent──→ B1, B2, B3
```

## Parallelization Strategy

```
Phase 1 (all independent — run in parallel):
  ┌─── A0  (5 min)
  ├─── A1  (1.5 hr) 
  ├─── A2  (1.5 hr)
  ├─── A3  (3 hr)
  ├─── A4  (2 hr)
  ├─── A5  (1 hr)
  └─── B0  (30 min) ← must complete before Phase 2 starts

Phase 2 (B0 complete, A1+A5 merged):
  ┌─── B1  (2 hr) — split into 3 sub-agents
  ├─── B2  (1.5 hr) — split into 3 sub-agents
  ├─── B3  (1.5 hr) — after B1
  └─── B4  (1 hr) — independent

Phase 3 (integrate + verify):
  ┌─── Build all (5 min)
  ├─── Review each change
  └─── Fix any regressions
```

## Agent Delegation Rules

### When to use sub-agents
- Task touches 3+ files → split into sub-agents (1 per file group)
- Task is purely research (no writes) — e.g., "find all hex colors in view files"
- Task is verification — e.g., "build and report errors"

### Sub-agent handoff protocol
```
1. Launch sub-agent with exact file list + change spec
2. Sub-agent returns: [file: path, changes: string, success: bool, error: string?]
3. If success == false, the orchestrator either:
   a. Retry with refined instructions (max 2 retries)
   b. Escalate to user with error context
4. If success == true, run build to verify
```

### Error handling per task

| Symptom | Action |
|---------|--------|
| Build fails after change | Read compiler error, fix, rebuild. If >3 attempts, escalate. |
| Sub-agent returns unexpected result | Request diff, validate against spec, retry with tighter instructions. |
| `powermetrics` requires root | Fall back to `ProcessInfo.thermalState` for A1. |
| `vm_stat` parse fails | Fall back to `ProcessInfo.physicalMemory` for A5. |
| "Lucida Grande" appears in multiple places | B2 sub-agent replaces all with `.body`, `.headline`, etc. |
| Hex colors too numerous to track | B1 sub-agent: grep for hex patterns, replace with DesignTokens. |
| Auto-restart causes crash loop | A2: cap at 5 retries, then show alert. Do NOT restart indefinitely. |

### Task timeout limits
| Task | Time limit | Action on timeout |
|------|-----------|-------------------|
| A0 (port fix) | 5 min | Should never timeout |
| A1 (thermal) | 2 hr | Fallback to ProcessInfo.thermalState, skip powermetrics |
| A2 (restart) | 2 hr | Strip to bare minimum (restart on non-zero exit, no backoff) |
| A3 (dashboard) | 4 hr | Ship minimal version (request count only, no tok/sec) |
| A4 (warm-pool) | 3 hr | Ship as "Prewarm" button only, no auto-warm |
| A5 (memory) | 1.5 hr | Ship `ProcessInfo.physicalMemory` only |
| B0 (tokens) | 45 min | Skip — use inline constants |
| B1 (color) | 3 hr per sub-agent | Ship partial — critical files only (ContentView, Settings) |
| B2 (typo) | 2 hr per sub-agent | Same as B1 |
| B3 (layout) | 2 hr | Centralize padding constants in DesignTokens, leave edge cases |
| B4 (windows) | 1.5 hr | Skip `contentMargins`, just fix window sizing |

## Build Verification Protocol

After each task completes:
1. `swift build` in PaglaMLX directory
2. If build fails → read error, fix, rebuild (max 3 attempts)
3. If still fails → report errors, do NOT advance to next task
4. If build passes → mark task complete, advance task list

## Execution Order (Recommended)

### Round 1 (parallel — max 5 agents)
1. **A0** (port) — 5 min, trivial
2. **A4** (warm-pool) — 2 hr, independent
3. **A2** (restart) — 1.5 hr, independent
4. **B0** (design tokens) — 30 min, prerequisite
5. **A1+A5** (thermal + memory merged into SystemMonitorManager) — 2 hr combined
6. **A3** (dashboard) — 3 hr, longest independent task

### Round 2 (B0 complete, starts after Round 1)
1. **B1** (color) — 3 sub-agents in parallel
2. **B2** (typo) — 3 sub-agents in parallel

### Round 3 (B1+B2 complete)
1. **B3** (layout)
2. **B4** (windows/sheets)

### Round 4 (all code done)
1. Build & fix regressions
2. Run manual smoke test (start model, send curl request, check UI)

## Token Budget Estimate

| Task | Tokens (estimate) |
|------|------------------|
| A0 | 500 |
| A1 | 4,000 |
| A2 | 3,500 |
| A3 | 6,000 |
| A4 | 4,000 |
| A5 | 3,000 |
| B0 | 2,000 |
| B1 | 8,000 |
| B2 | 6,000 |
| B3 | 5,000 |
| B4 | 2,000 |
| **Total** | **~44,000 tokens** |

Time to completion (parallel): ~5 hours wall clock
Time to completion (serial): ~18 hours
Recommended: 2-3 rounds with parallel sub-agents = ~6 hours total

## Pre-flight Checklist (before starting Round 1)

- [ ] USB volume CastingC0UCH disconnected (no need for mlx_lm, we're just editing code)
- [ ] `swift build` currently passes — verify baseline
- [ ] Design reference docs loaded (already in memory)
- [ ] All 6 gap descriptions clear
- [ ] B0 DesignTokens.swift spec clear
