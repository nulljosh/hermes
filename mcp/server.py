# /// script
# requires-python = ">=3.11"
# dependencies = ["mcp>=2"]
# ///
"""Hermes MCP: the Hermes window as tools an agent can call, over the same `asc` CLI the Mac app drives.

Read-only by default, like the app: every call gets `--read-only`, so asc refuses writes before they are sent.
Set HERMES_ALLOW_WRITES=1 to let the write tools through.

    uv run mcp/server.py            # stdio server
    uv run mcp/server.py --http     # the same tools over HTTP on 127.0.0.1:8787: /mcp, plus GET /api/<tool>?arg=value
    claude mcp add hermes -- uv run https://raw.githubusercontent.com/nulljosh/hermes/main/mcp/server.py
"""
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

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


# Resolve All, outside the app: the same rejections, facts and drafts the Mac app shows, so an agent can do the run.
GH = shutil.which("gh") or "/opt/homebrew/bin/gh"
OWNER = "nulljosh"
REVIEW = Path.home() / "Library/Caches/Hermes/review"
PASSED = {"READY_FOR_SALE", "READY_FOR_DISTRIBUTION", "PENDING_DEVELOPER_RELEASE", "PENDING_APPLE_RELEASE",
          "PROCESSING_FOR_DISTRIBUTION", "ACCEPTED"}


def gh(*args: str) -> str:
    p = subprocess.run([GH, *args], capture_output=True, text=True, timeout=60)
    return p.stdout if p.returncode == 0 else ""


def fleet() -> list[dict]:
    """Every non-fork repo: files with git blob SHAs, README head, bundle id to project.yml folder.
    Shares fleet.json with the Mac app, so whichever reads first pays for it, and it holds a day."""
    cache = REVIEW / "fleet.json"
    if cache.exists() and time.time() - cache.stat().st_mtime < 86_400:
        return json.loads(cache.read_text())
    out = []
    for r in json.loads(gh("repo", "list", OWNER, "--limit", "200", "--json", "name,isFork,isArchived") or "[]"):
        if r["isFork"] or r["isArchived"]:
            continue
        n = r["name"]
        tree = gh("api", f"repos/{OWNER}/{n}/git/trees/HEAD?recursive=1", "--jq", '.tree[]|select(.type=="blob")|"\\(.path)\\t\\(.sha)"')
        files = dict(line.split("\t", 1) for line in tree.splitlines() if "\t" in line)
        ids: dict[str, str] = {}
        for path in [f for f in files if f.endswith("project.yml") and f.count("/") <= 2]:
            folder = path.rpartition("/")[0]
            for m in set(re.findall(r"com\.[A-Za-z0-9._-]+", gh("api", f"repos/{OWNER}/{n}/contents/{path}", "-H", "Accept: application/vnd.github.raw"))):
                if m not in ids or len(folder) < len(ids[m]):
                    ids[m] = folder
        readme = gh("api", f"repos/{OWNER}/{n}/readme", "-H", "Accept: application/vnd.github.raw")[:1800]
        out.append({"name": n, "files": files, "readme": readme, "ids": ids})
    REVIEW.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(out))
    return out


def is_source(p: str) -> bool:
    return p.endswith(".swift") and not any(x in p for x in ("Test", "Snapshot", "Preview", "build/", ".build/", "Pods/"))


def folder_readme(repo: dict, tops: set[str]) -> str:
    """In a monorepo the repo README is about the whole repo; the app's own folder README is the one that describes it."""
    for t in sorted(tops):
        if f"{t}/README.md" in repo["files"]:
            return gh("api", f"repos/{OWNER}/{repo['name']}/contents/{t}/README.md", "-H", "Accept: application/vnd.github.raw")[:1800]
    return ""


@mcp.tool()
def app_facts(app_id: str) -> dict:
    """Checkable facts for an appeal: App Store history, versions App Review already approved, the source repo,
    Swift files shipped, files byte-identical to other apps on the account, and the README. Same rules as the Mac app."""
    app = next((a for a in list_apps() if a["id"] == app_id), None)
    if not app:
        raise RuntimeError(f"No app {app_id} on this account.")
    vs = [(v.get("platform"), v.get("versionString"), v.get("appVersionState") or v.get("appStoreState")) for v in list_versions(app_id)]
    ups = sorted(b.get("uploadedDate") or "" for b in list_builds(app_id, 200))
    facts = {"app": app["name"], "history": [" ".join(map(str, v)) for v in vs], "builds": len(ups), "firstBuild": ups[0][:10] if ups else None,
             "approvedBefore": [f"{p} {v}" for p, v, s in vs if s in PASSED]}
    repos, bid = fleet(), app["bundleId"]
    me = next((r for r in repos if bid in r["ids"]), None) or next(
        (r for r in repos if any(bid.startswith(i) or i.startswith(bid) for i in r["ids"])), None)
    if not me:
        return {**facts, "repo": None}
    stem = ".".join(bid.split(".")[:3])
    tops = {f.split("/")[0] for i, f in me["ids"].items() if i.startswith(stem)}
    whole = "" in tops or not tops
    mine = lambda p: whole or p.split("/")[0] in tops
    # Other apps in the same repo: top folders whose project.yml names a different app (not Apple's entitlement keys).
    apps_beside = {f.split("/")[0] for i, f in me["ids"].items()
                   if i.count(".") >= 2 and not i.startswith(("com.apple.", stem))} - tops - {""}
    src = {p: s for p, s in me["files"].items() if is_source(p) and mine(p)}
    shared: dict[str, list[str]] = {}
    for o in repos:
        same = o["name"] == me["name"]
        other = {s for p, s in o["files"].items() if is_source(p) and (not same or p.split("/")[0] in apps_beside)}
        hits = sorted({p.rsplit("/", 1)[-1] for p, s in src.items() if s in other})
        if hits:
            shared[f"other {me['name']} folders" if same else o["name"]] = hits
    return {**facts, "repo": f"{OWNER}/{me['name']}", "folders": sorted(tops) if not whole else ["/"], "swiftFiles": len(src),
            "sharedFiles": shared, "readme": folder_readme(me, tops) if not whole else me["readme"]}


@mcp.tool()
def open_rejections(app_id: str) -> dict:
    """The open Resolution Center thread for an app: Apple's message, the reasons, the thread id to reply to.
    Uses asc's Apple web session; if it has expired, run `asc web auth login` once (Joshua types the code)."""
    return asc("web", "review", "show", "--app", app_id, "--plain-text", "--out", str(REVIEW / app_id))


@mcp.tool()
def saved_drafts() -> dict:
    """The drafts from the last Resolve All run, in the app or here, and dry-run.md: the whole run on one page."""
    d, md = REVIEW / "drafts.json", REVIEW / "dry-run.md"
    return {"drafts": json.loads(d.read_text()) if d.exists() else {}, "dryRun": md.read_text() if md.exists() else ""}


@mcp.tool()
def send_rejection_reply(thread_id: str, message: str) -> dict:
    """Send one Resolution Center reply. Needs HERMES_ALLOW_WRITES=1 and Joshua's yes for this exact text.
    Refuses a message with a [placeholder] left in it. Never retried: Apple may have taken a send that reported an error."""
    if "[" in message:
        raise RuntimeError("The reply still has a [placeholder]. Fill it before sending.")
    return asc("web", "review", "reply", "--thread-id", thread_id, "--message", message, "--confirm", write=True)


def serve_http(port: int = 8787) -> None:
    """MCP at /mcp and a plain JSON API at /api/<tool>, on localhost only: asc's keys and session stay on this Mac."""
    from starlette.requests import Request
    from starlette.responses import JSONResponse

    tools = {f.__name__: f for f in (list_apps, fleet_status, app_status, list_versions, list_builds, list_reviews,
                                      review_history, app_facts, open_rejections, saved_drafts)}

    @mcp.custom_route("/api/{tool}", methods=["GET"])
    async def api(request: Request) -> JSONResponse:
        f = tools.get(request.path_params["tool"])
        if not f:
            return JSONResponse({"error": "unknown tool", "tools": sorted(tools)}, status_code=404)
        args = {k: (v == "true") if v in ("true", "false") else int(v) if v.isdigit() and k in ("limit",) else v
                for k, v in request.query_params.items()}
        try:
            return JSONResponse(f(**args))
        except Exception as e:  # asc's own message, so the caller sees why
            return JSONResponse({"error": str(e)}, status_code=400)

    mcp.run("streamable-http", host="127.0.0.1", port=port)


if __name__ == "__main__":
    serve_http() if "--http" in sys.argv else mcp.run()
