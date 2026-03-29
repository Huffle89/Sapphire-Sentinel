# Sapphire Sentinel

![Sapphire Sentinel Logo](assets/logo.png)

Sapphire Sentinel is a Linux-first terminal session intelligence platform built by Huffle’s IT Services LLC.

Instead of acting like a simple command logger, Sentinel is designed to help reconstruct and explain real terminal work sessions. It captures session context, records command activity, flags failures, and turns shell work into readable stories and reports.

## Current Status

Sapphire Sentinel is currently in **Personal Mode Beta**.

The current beta focuses on guided session startup, structured session tracking, readable story output, shell-based command logging, and transcript generation for Linux environments.

## What Sentinel Does

Sapphire Sentinel helps answer questions like:

- What kind of work happened?
- What was that work tied to?
- Which commands were run?
- Were there failures or notable events?
- What happened in the session overall?

## Core Commands

```bash
sentinel init
sentinel config
sentinel start
sentinel stop
sentinel status
sentinel story --last
sentinel story <session_id>
sentinel session --last
sentinel sessions --last
sentinel sessions --today
sentinel report day
sentinel report week
sentinel report month
sentinel update
sentinel help
