# shellcheck shell=bash
# Loadout deliberately enables Copilot's permissive autonomous mode.

copilot() {
    command copilot --autopilot --allow-all "$@"
}

alias cop='copilot'
