---
name: hermes-ship
description: Walk one app version from build to App Review with Hermes and asc, checking each step and confirming before any write. Use when Joshua says "ship <app>", "submit <app> for review", "send it to Apple", or invokes /hermes-ship.
---

# Hermes ship

Every step reads first. Every write is confirmed with Joshua before it runs, with the exact command shown.

1. Find the app (`list_apps` or `asc apps list`) and its newest version per platform (`list_versions`). If no version is in `PREPARE_FOR_SUBMISSION`, say so and ask before creating one (`asc versions create --app <id> --version <x.y.z> --platform <P> --copy-metadata-from <last>`).
2. Check readiness: `asc validate --app <id> --output json`. Stop on any error and report it plainly.
3. Check the build: `list_builds`; the newest must be `VALID` and not expired. If it is still processing, wait with `asc builds wait`.
4. Check the store text has What's New for every language: `asc localizations list --version <versionId> --output json`.
5. Show Joshua the plan in one or two lines and the command: `asc review submit --version-id <versionId> --latest --confirm`. Only after his yes, run it (MCP `submit_for_review` needs HERMES_ALLOW_WRITES=1).
6. Confirm with `app_status`: the state should read `WAITING_FOR_REVIEW`. Report that, nothing more.

House rules still apply: never resubmit an unchanged binary after a rejection, and replies to App Review go through Joshua.
