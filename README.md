# Sapphire Sentinel

![Sapphire Sentinel Logo](assets/logo.png)

Sapphire Sentinel is a Linux-first terminal session intelligence platform built by Huffle’s IT Services LLC.

Instead of acting like a simple command logger, Sentinel is designed to help reconstruct and explain real work sessions. It captures structured activity, preserves session context, and turns terminal work into readable operational history through session stories and reporting.

## Current Status

Sapphire Sentinel is currently in an active beta rebuild phase.

This rebuild focuses on:
- a cleaner command structure
- structured session metadata
- canonical event logging
- story and reporting foundations
- a dual-mode path layout for both project and installed environments

## Core Command Style

Sentinel is designed around a clean command model:

sentinel init  
sentinel start  
sentinel stop  
sentinel status  
sentinel story  
sentinel report day  
sentinel report week  
sentinel report month  

## What Makes Sentinel Different

Sapphire Sentinel is built around the idea that terminal work should be understandable, not just recorded.

Sentinel aims to answer:
- What kind of work happened?
- What context was it tied to?
- Were there errors or notable signals?
- What happened across day, week, or month?

## Current Beta Features

- Session lifecycle (init, start, stop, status)
- Signal logging (command, error, note)
- Session summaries
- Story engine (early stage)
- Reporting (day, week, month)
- Update system (apt, flatpak, snap)

## Path Layout

Supports both:
- Project mode
- Installed mode

## Linux-First

Currently designed for Linux environments.

## License

See LICENSE file.

## Author

Christopher Lagasse  
Huffle’s IT Services LLC
