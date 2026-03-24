# Styx — Future Plans

## iTerm2 Shell Integration

iTerm2 Shell Integration provides per-session awareness of the current working directory, running command, and command boundaries. With it installed, Styx could leverage richer terminal state.

### Auto-detect working directory
- Read the current working directory from the active session instead of requiring manual `homeDir` configuration
- Keep `homeDir` as an override/default, but show the live cwd when available

### Show running command in bubble
- Display the currently running command (e.g. `vim`, `npm run dev`) in the bubble label or as a tooltip
- Useful for at-a-glance identification when multiple bubbles have the same icon

### Busy/idle indicator
- Track whether a command is actively running in a bubble's terminal
- Show a visual indicator (e.g. spinner or pulsing ring) for busy bubbles vs idle ones
- Could inform "Min All" behavior — prompt before minimizing a bubble with a long-running command
