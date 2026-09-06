# Service state transitions

This document describes the behavior currently implemented by `service.luau`. It is a characterization baseline for tests and future refactoring, not a proposed redesign.

## State and request channels

The service communicates with the panel and widget through Noctalia's in-memory state store.

| Channel | Direction | Purpose |
| --- | --- | --- |
| `generation-status` | Service → UI | Status of the booted-versus-current generation check |
| `closure-diff-status` | Service → UI | Status and result of an on-demand closure comparison |
| `status` | Service → UI | Status and result of a mutating flake input update |
| `generation-refresh-request` | Panel → service | Incrementing counter requesting a generation refresh |
| `closure-diff-request` | Panel → service | Incrementing counter requesting a closure comparison |
| `check-request` | Panel → service | Incrementing counter requesting a flake input update |

Request values have no meaning beyond changing the stored value and triggering a watcher. Each workflow has a separate in-memory running flag; a request received while its workflow is running is ignored.

## Generation status

### Shapes currently published

```luau
{ state = "checking" }

{
    state = "current" | "different",
    bootedPath = string,
    currentPath = string,
}

{
    state = "current" | "different" | "error" | "checking",
    bootedPath = string?,
    currentPath = string?,
    message = string?,
    refreshing = true,
}

{
    state = "error",
    message = string,
}
```

The `refreshing` shape preserves selected fields from the previous status while a new check is running. Once the check completes, the newly published result does not contain `refreshing`.

### Triggers

A generation check starts:

- when the service loads;
- on every service `update()` interval, currently every 60 seconds;
- when `generation-refresh-request` changes;
- after a successful closure comparison.

### Transition table

| Starting condition | Event/result | Published status | Other effects |
| --- | --- | --- | --- |
| No status exists | Check starts | `checking` | Sets the generation running guard |
| A previous status exists | Check starts | Previous state and selected fields, plus `refreshing = true` | Sets the generation running guard |
| Any status; check running | Another trigger arrives | No change | Trigger is ignored |
| Check running | `readlink` times out | `error` with timeout message | Releases the running guard |
| Check running | `readlink` exits non-zero | `error` with trimmed stderr or fallback message | Releases the running guard |
| Check running | Output contains other than exactly two non-empty lines | `error` with expected-paths message | Releases the running guard |
| Check running | Both resolved paths are equal | `current` with both paths | Releases the running guard |
| Check running | Resolved paths differ | `different` with both paths | Releases the running guard |
| Starting command fails | `runAsync` returns `false` | `error` with start-failure message | Releases the running guard |

### Reload behavior

Generation state is not explicitly reset on service load. The initial check does the following:

- if no previous status exists, it publishes `checking`;
- if a previous status exists, it preserves its state and selected fields while adding `refreshing = true`.

The generation running guard is process-local and therefore starts as `false` after reload.

## Closure-diff status

### Shapes currently published

```luau
{ state = "idle" }
{ state = "running" }

{
    state = "ready",
    output = string,
    lines = { any },
    truncated = boolean?,
}

{
    state = "error",
    message = string,
}
```

`lines` contains the structured output produced by `lib/closure_diff.luau`.

### Trigger

A closure comparison starts when `closure-diff-request` changes.

### Transition table

| Starting condition | Event/result | Published status | Other effects |
| --- | --- | --- | --- |
| Not running | Request arrives | `running` | Sets the closure running guard |
| Running | Another request arrives | No change | Request is ignored |
| Running | Command times out | `error` with timeout message | Releases the running guard |
| Running | Command exits non-zero | `error` using cleaned stderr, then stdout, then fallback message | Releases the running guard |
| Running | Command succeeds | `ready` with cleaned output, parsed lines, and truncation flag | Releases the running guard and requests a generation check directly |
| Starting command fails | `runAsync` returns `false` | `error` with start-failure message | Releases the running guard |

A successful comparison calls the generation-check function directly. If a generation check is already running, that follow-up check is ignored.

### Reload behavior

On service load:

- a missing status becomes `idle`;
- a retained `running` status becomes `idle`, because its callback was lost;
- `ready` and `error` statuses are preserved.

The closure running guard is process-local and therefore starts as `false` after reload.

## Flake-update status

Despite the historical `check` naming in request and function identifiers, this workflow runs a real, mutating `nix flake update` against the configured flake.

### Shapes currently published

```luau
{ state = "idle", message = nil }
{ state = "checking", message = nil }
{ state = "current", changedInputs = {} }

{
    state = "updates",
    changedInputs = { any },
}

{
    state = "error",
    message = string,
}
```

`changedInputs` contains entries produced by `lib/nix.luau`.

### Trigger

A flake update starts when `check-request` changes.

### Transition table

| Starting condition | Event/result | Published status | Other effects |
| --- | --- | --- | --- |
| Not running | Request arrives | `checking` | Sets the update running guard and starts a mutating update |
| Running | Another request arrives | No change | Request is ignored |
| Running | Command times out | `error` with timeout message | Releases the running guard |
| Running | Command exits non-zero | `error` using trimmed stderr, then stdout, then fallback message | Releases the running guard |
| Running | Command succeeds with no parsed changes | `current` with an empty `changedInputs` array | Releases the running guard |
| Running | Command succeeds with parsed changes | `updates` with parsed `changedInputs` | Releases the running guard |
| Starting command fails | `runAsync` returns `false` | `error` with start-failure message | Releases the running guard |

### Reload behavior

On service load:

- a missing status becomes `idle`;
- a retained `checking` status becomes `idle`, because its callback was lost;
- `current`, `updates`, and `error` statuses are preserved.

The update running guard is process-local and therefore starts as `false` after reload.

## Current invariants to preserve

Unless deliberately changed and documented, the initial refactor should preserve these behaviors:

1. At most one command per workflow runs at a time.
2. The three workflows do not block one another.
3. Every callback path and every failure-to-start path releases its workflow's running guard.
4. A generation refresh retains the previous visible result while indicating `refreshing`.
5. Closure and update workflows replace their previous visible result with a running state.
6. Completed closure and update results survive service reloads.
7. Interrupted closure and update operations reset to idle after service reloads.
8. A successful closure comparison triggers a generation refresh.
9. Error output preference remains workflow-specific as described above.
10. Flake updates remain explicitly user-triggered and mutating.

## Candidate characterization tests

The next step can implement a fake Noctalia host and turn this baseline into executable tests. The minimum useful cases are:

### Generation

- Initial load with no state publishes `checking` and starts `readlink` with the expected paths.
- Refresh with an existing result preserves that result and adds `refreshing`.
- Equal and different paths publish `current` and `different`, respectively.
- Timeout, non-zero exit, malformed output, and failure to start publish the documented errors.
- A duplicate trigger does not start a second command.
- A completed command releases the guard and allows another command.

### Closure comparison

- Request publishes `running` and starts the expected `nix store diff-closures` command.
- Success publishes parsed output and triggers a generation check.
- Timeout, non-zero exit with each output fallback, and failure to start publish the documented errors.
- Truncation is retained in the ready status.
- Duplicate requests are ignored.
- Reload resets `running` but preserves completed states.

### Flake update

- Request publishes `checking` and starts the expected mutating command.
- Success with zero changes publishes `current`.
- Success with changes publishes `updates` and the parsed entries.
- Timeout, non-zero exit with each output fallback, and failure to start publish the documented errors.
- Duplicate requests are ignored.
- Reload resets `checking` but preserves completed states.
