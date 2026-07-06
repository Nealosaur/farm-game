extends Node
## Alive Stride 2: single global gate for "the player does not get to act
## right now" — cutscenes (EventRunner) AND the end-of-day sequence
## (DayFlow.end_day) both set/clear the SAME `cutscene_active` flag, so every
## input-polling call site only has to check one bool regardless of WHY
## input is currently suspended.
##
## Rationale for reusing one flag rather than two: before this stride,
## DayFlow's fade-to-black window had NO input gate at all (Clock.paused
## stopped the clock/crops, but Player.Idle/Move still polled input and could
## walk/attack/dodge during the fade) — a long-standing debt called out in
## the contract. Rather than ship a second, cutscene-only flag and leave that
## debt in place, DayFlow.end_day() now sets this SAME gate for its own
## duration. Nothing outside DayFlow/EventRunner should set this directly.
##
## Deliberately NOT reentrant-counted (no int depth): EventRunner scenes never
## nest today (a script's own preconditions/once-per-day gate prevent a second
## scene from starting mid-scene), and DayFlow's end_day() already no-ops via
## its own `_busy` guard if called again while busy — a plain bool is enough
## and avoids a counting bug (forgetting to decrement) becoming a permanent
## input lock.

var cutscene_active := false
