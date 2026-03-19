# Sapphire Sentinel Command Reference

This document outlines the core command structure for Sapphire Sentinel.

---

## Core Commands

### sentinel init
Initializes Sentinel in the current environment.

Creates required directories, configuration files, and log structure.

---

### sentinel start
Starts a new session.

Supports optional context:
- project
- ticket
- label
- none

Examples:
sentinel start project sapphire_sentinel
sentinel start ticket INC-1024
sentinel start label investigation

---

### sentinel stop
Stops the active session and archives it.

---

### sentinel status
Displays the current active session.

Includes:
- session ID
- mode
- context
- start time
- state

---

### sentinel story
Generates a readable narrative of the most recent session.

Includes:
- context history
- signal summaries
- notable actions

---

## Reporting Commands

### sentinel report day
Shows activity for the current day.

Includes:
- total signals
- session breakdown
- top sessions
- recent activity

---

### sentinel report week
Shows activity for the last 7 days.

Includes:
- totals
- mode breakdown
- daily breakdown
- top sessions

---

### sentinel report month
Shows activity for the last 30 days.

Includes:
- totals
- session counts
- signal summaries

---

## Update Command

### sentinel update
Runs system updates across supported managers:

- apt / apt-get
- flatpak
- snap

Provides:
- detection of available managers
- categorized results (updated, deferred, none, failed)
- structured logging of update activity

---

## Notes

- Manual sessions override automatic grouping
- Context is flexible and not limited to projects
- All activity is recorded in the canonical log format

timestamp | mode | action | target | status | details
