---
name: hermes-status
description: Release status for every App Store app in one read, through the Hermes MCP or the asc CLI it wraps. Use when Joshua asks "what's in review", "any rejections", "fleet status", "where are my apps", or invokes /hermes-status.
---

# Hermes status

The Hermes app list, as a report. Read only.

1. If the `hermes` MCP server is connected, call `fleet_status`. Otherwise run `ASC_BYPASS_KEYCHAIN=1 asc versions list --app <id> --latest --output json` for each id from `asc apps list --paginate --output json`.
2. Group apps by state: rejected first (`REJECTED`, `METADATA_REJECTED`, `INVALID_BINARY`, `DEVELOPER_REJECTED`), then in review (`WAITING_FOR_REVIEW`, `IN_REVIEW`, `PENDING_*`), then preparing, then on sale.
3. For each rejected or blocked app, call `app_status` (or `asc status --app <id>`) and quote its `nextAction` and blockers word for word. For rejection history use `review_history` with `rejections_only`.
4. Report in a few short lines: what needs Joshua, what is waiting on Apple, what is live. Name apps by their current names.

Never change anything from this skill. Writes go through /hermes-ship.
