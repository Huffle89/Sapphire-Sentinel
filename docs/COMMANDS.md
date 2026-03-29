# Sapphire Sentinel — Command Reference

This document provides a complete reference for all available Sapphire Sentinel commands in Personal Mode Beta.

---

## Overview

Sapphire Sentinel is a session-based terminal intelligence tool.

Commands are organized around:

- initialization and configuration
- session lifecycle
- session views and stories
- reporting
- manual signals and context control
- system updates

---

## Initialization & Configuration

### sentinel init
Initializes Sapphire Sentinel and creates the initial configuration.

You will be prompted to choose:
- quick install (recommended defaults)
- custom install (manual configuration)

---

### sentinel config
Opens the configuration menu.

Allows you to change:
- prompt style (guided or minimal)
- storage location
- feature toggles (context reminders, notes, reports)

---

## Session Lifecycle

### sentinel start
Starts a guided Personal Mode session.

You will be prompted to select:
- whether to log the session
- session mode
- context type
- context value
- optional label or version note

---

### sentinel start <mode> <context_type> <context_value>
Starts a session without prompts.

Example:
sentinel start development project "Sapphire Sentinel"

---

### sentinel stop
Stops the active session.

This will:
- finalize session duration
- archive the session
- update logs
- finalize transcript output

---

### sentinel status
Displays the currently active session, including:
- session ID
- mode
- context
- start time

---

## Session Views

### sentinel session --last
Displays a quick summary of the most recent session.

---

### sentinel sessions --last
Displays recent sessions.

---

### sentinel sessions --today
Displays sessions from today.

---

## Story Output

### sentinel story --last
Displays a readable summary of the most recent session.

Includes:
- session metadata
- context
- command and error counts
- latest activity
- recent signals

---

### sentinel story <session_id>
Displays a story for a specific session.

---

## Reporting

### sentinel report day
Displays daily session activity.

---

### sentinel report week
Displays weekly session activity.

---

### sentinel report month
Displays monthly session activity.

---

## Signals (Advanced)

### sentinel signal command "<details>"
Logs a command signal manually.

### sentinel signal error "<details>"
Logs an error signal manually.

### sentinel signal note "<details>"
Logs a note signal manually.

---

## Context Management

### sentinel attach <context_type> <context_value>
Attaches or updates context for the active session.

Context types:
- project
- ticket
- classwork
- label
- none

---

## Updates

### sentinel update
Runs updates for:
- apt / apt-get
- flatpak
- snap

---

## Help

### sentinel help
Displays all available commands and usage.

---

## Session Modes

When starting a session, you will select:

- Development — building or creating something
- Maintenance — updates, installs, cleanup
- Troubleshooting — fixing issues
- Investigation — testing or learning
- Unclear — not yet defined

---

## Logging Behavior

During an active session, Sentinel automatically captures:

- commands executed
- exit codes
- errors (non-zero exit codes)
- optional notes

No logging occurs outside of an active session.

---

## Transcript Output

Each session may generate a transcript journal file.

The transcript includes:

- session metadata
- chronological command execution
- exit codes
- session end time
- total duration

---

## Quick Example

sentinel start  
pwd  
whoami  
notacommand  
sentinel stop  
sentinel story --last  
sentinel session --last  

---

## Notes

- Only one session can be active at a time
- A session must be stopped before starting another
- sentinel config can be used at any time without rerunning init
- Sentinel operates in Personal Mode during this beta
