# Changelog

All notable changes to Sapphire Sentinel will be documented in this file.

---

## [v3.0.0-beta2] - 2026-03

### Added
- Clean-slate rebuild of Sapphire Sentinel
- Modular engine architecture
- Session lifecycle commands (init, start, stop, status)
- Context system (project, ticket, label, none)
- Signal system (command, error, note)
- Story engine (early-stage narrative output)
- Reporting system:
  - report day
  - report week
  - report month (initial)
- Analytics engine:
  - signal counting
  - session scoring
  - mode and daily breakdowns
- Update system:
  - apt / apt-get full-upgrade
  - flatpak update
  - snap refresh

### Changed
- Transitioned from logger-based system to structured event model
- Unified canonical log format:
  timestamp | mode | action | target | status | details
- Introduced dual-mode path system:
  - project mode
  - installed mode

### Notes
- This version represents a major architectural shift from earlier Sentinel versions
- Focus is on stability, structure, and future extensibility
