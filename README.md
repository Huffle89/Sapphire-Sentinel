# Sapphire Sentinel

![Sapphire Sentinel Logo](assets/logo.png)

Sapphire Sentinel is a Linux-first terminal session intelligence tool that records, reconstructs, and explains your work so you can understand it later without relying on memory.

Sapphire Sentinel is developed and maintained by Christopher Lagasse / Huffle’s IT Services LLC.
All intellectual property rights to Sapphire Sentinel are owned by Christopher Lagasse and Huffle’s IT Services LLC.

**Status:** Personal Mode Beta (v3)
---

## What Sentinel Does

Sentinel captures your terminal activity and turns it into a clear, readable narrative of what you did.

It is built for:

- developers
- sysadmins
- cybersecurity professionals
- homelab users
- anyone who works in the terminal and needs to understand their own work later

---

## Core Philosophy

> Sentinel should always allow the user to look back at what they did and understand it.

Everything in Personal Mode is built around that rule.

---

## Features (Personal Mode - Free)

### Session Tracking

- Start, stop, and monitor sessions
- Automatic command capture
- Context support:
  - project
  - ticket
  - label
  - none

### Story Output

- Converts raw terminal activity into readable session narratives
- Makes past work understandable instead of cryptic

### Reporting

- `sentinel report day`
- `sentinel report week`
- `sentinel report month`
- Session summaries with signal counts and highlights

### Logging System

- Passive shell logging
- Structured event tracking:
  - commands
  - errors
  - notes
- Clean transcript journaling

### Full Log Access

- No forced deletion
- Manual cleanup available
- Complete visibility into your own history

### System Update (Multi-Manager Support)

Sentinel can update multiple package systems in a single run:

- APT (Debian / Ubuntu / KDE Neon / Mint)
- DNF (Fedora / RHEL-based)
- Pacman (Arch / Manjaro)
- Zypper (openSUSE)
- Flatpak
- Snap

**Behavior:**

- Detects supported package managers on the system
- Updates all supported managers in one run
- Skips missing managers without error
- Continues even if one manager fails
- Provides a clean summary of results

---

## Planned Premium Features (Sentinel Insight)

Premium expands Sentinel beyond single-session understanding into deeper intelligence:

### Insight & Analytics

- Cross-session trend analysis
- Productivity and error pattern detection
- Session comparison and scoring

### Search & Memory

- Search across commands, errors, and sessions
- Advanced filtering and timeline navigation

### Enhanced Story

- Smarter summaries
- Multi-session narrative linking
- Problem -> resolution tracking

### Reporting & Export

- Clean export (text / markdown)
- Client-ready summaries
- Weekly/monthly digest reports

### Retention & Storage Control

- Auto-clean policies
- Archive tiers
- Configurable retention rules

### System Awareness

- Detect installs outside the terminal
- Track GUI package manager activity
- Correlate system changes with sessions

---

## Installation (Current)

Clone the repository:

```bash
git clone https://github.com/Huffle89/Sapphire-Sentinel.git
cd Sapphire-Sentinel
chmod +x bin/sentinel
