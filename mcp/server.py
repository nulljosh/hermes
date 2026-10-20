# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=2"]
# ///
"""Hermes MCP: the Hermes window as tools an agent can call, over the same `asc` CLI the Mac app drives.

Read-only by default, like the app: every call gets `--read-only`, so asc refuses writes before they are sent.
Set HERMES_ALLOW_WRITES=1 to let the write tools through.

    uv run mcp/server.py            # stdio server
    claude mcp add hermes -- uv run https://raw.githubusercontent.com/nulljosh/hermes/main/mcp/server.py
"""
import json
import os
import shutil
import subprocess

from mcp.server.mcpserver import MCPServer

ASC = shutil.which("asc") or "/opt/homebrew/bin/asc"
WRITES = os.environ.get("HERMES_ALLOW_WRITES") == "1"
mcp = MCPServer("hermes")


def asc(*args: str, write: bool = False) -> object:
    """Run asc and return its parsed JSON; raise with asc's own message on failure."""
    if write and not WRITES:
        raise RuntimeError("Writes are off. Set HERMES_ALLOW_WRITES=1 for this server to send changes to App Store Connect.")
    cmd = [ASC] + ([] if WRITES else ["--read-only"]) + list(args) + ["--output", "json"]
    env = {**os.environ, "ASC_BYPASS_KEYCHAIN": "1"}
    p = subprocess.run(cmd, capture_output=True, text=True, env=env, timeout=300)
    if p.returncode != 0:
        raise RuntimeError(p.stderr.strip() or p.stdout.strip() or f"asc exited {p.returncode}")
    return json.loads(p.stdout) if p.stdout.strip() else {}


def rows(data: object) -> list:
    """asc lists come back as {"data": [...]} or {"items": [...]}."""
    if isinstance(data, dict):
        return data.get("data") or data.get("items") or []
    return data if isinstance(data, list) else []


@mcp.tool()
def list_apps() -> list[dict]:
    """Every app on the account with its id, name and bundle id."""
    return [{"id": a["id"], "name": a["attributes"]["name"], "bundleId": a["attributes"]["bundleId"]}
            for a in rows(asc("apps", "list", "--paginate"))]


@mcp.tool()
def fleet_status() -> list[dict]:
    """The newest version on each platform for every app, with its App Store state. The app list screen, as data."""
    out = []
    for app in list_apps():
        versions = rows(asc("versions", "list", "--app", app["id"], "--latest"))
        out.append({**app, "versions": [{"platform": v["attributes"].get("platform"),
                                         "version": v["attributes"].get("versionString"),
                                         "state": v["attributes"].get("appVersionState") or v["attributes"].get("appStoreState")}
                                        for v in versions]})
    return out


@mcp.tool()
def app_status(app_id: str) -> dict:
    """One app's release status: health, next action, blockers, latest build, App Store and review state, links."""
    return asc("status", "--app", app_id)


@mcp.tool()
def list_versions(app_id: str) -> list[dict]:
    """All App Store versions of an app, newest first."""
    return [{"id": v["id"], **v["attributes"]} for v in rows(asc("versions", "list", "--app", app_id, "--paginate"))]


@mcp.tool()
def list_builds(app_id: str, limit: int = 20) -> list[dict]:
    """Recent builds with processing state and upload date."""
    return [{"id": b["id"], **{k: v for k, v in b["attributes"].items() if k != "iconAssetToken"}}
            for b in rows(asc("builds", "list", "--app", app_id, "--limit", str(limit)))]


@mcp.tool()
def list_reviews(app_id: str, unanswered_only: bool = False, limit: int = 50) -> list[dict]:
    """Customer reviews, newest first."""
    state = "unresponded" if unanswered_only else "any"
    return [{"id": r["id"], **r["attributes"]}
            for r in rows(asc("reviews", "list", "--app", app_id, "--sort", "-createdDate", "--limit", str(limit), "--response-state", state))]


@mcp.tool()
def review_history(app_id: str, rejections_only: bool = False) -> list[dict]:
    """Every App Review submission with its outcome. The Submissions tab, as data."""
    subs = asc("review", "history", "--app", app_id, "--limit", "50")
    subs = subs if isinstance(subs, list) else []
    if rejections_only:
        subs = [s for s in subs if "reject" in (s.get("outcome") or s.get("state") or "").lower() or s.get("state") == "UNRESOLVED_ISSUES"]
    return subs


@mcp.tool()
def reply_to_review(review_id: str, reply: str) -> dict:
    """Publish a reply to a customer review. Needs HERMES_ALLOW_WRITES=1."""
    return asc("reviews", "respond", "--review-id", review_id, "--response", reply, write=True)


@mcp.tool()
def submit_for_review(version_id: str) -> dict:
    """Attach the newest eligible build and submit the version for App Review. Needs HERMES_ALLOW_WRITES=1."""
    return asc("review", "submit", "--version-id", version_id, "--latest", "--confirm", write=True)


if __name__ == "__main__":
    mcp.run()
