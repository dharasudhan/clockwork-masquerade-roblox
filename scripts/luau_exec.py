#!/usr/bin/env python3
"""Upload a built place to a Roblox TEST place and run a Luau script in it via Open Cloud.

Modelled on github.com/Roblox/place-ci-cd-demo (MIT): scripts/python/luau_execution_task.py
and upload_and_run_task.py. Rewritten for this project; stdlib only.

Environment:
  ROBLOX_API_KEY      Open Cloud API key with universe-places:write and
                      universe.place.luau-execution-session:write (+ :read) scopes
  ROBLOX_UNIVERSE_ID  universe (experience) id of the TEST experience
  ROBLOX_PLACE_ID     place id of the TEST place

Usage:
  python3 scripts/luau_exec.py build/ClockworkMasquerade.rbxl tests/run.server.luau
  python3 scripts/luau_exec.py --dry-run build/ClockworkMasquerade.rbxl tests/run.server.luau
  python3 scripts/luau_exec.py --publish ...   # versionType=Published (private test experience only;
                                               # making the experience public is Gate 6)

Exit code 0 when the task COMPLETEs, 1 otherwise.
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request

API = "https://apis.roblox.com"
POLL_SECONDS = 3
TIMEOUT_SECONDS = int(os.environ.get("LUAU_EXEC_TIMEOUT", "600"))
FORBIDDEN_UNIVERSES = {"10773325904"}  # Ghost Mansion - never touched from this repo
MAX_409_RETRIES = int(os.environ.get("LUAU_EXEC_409_RETRIES", "5"))


def env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"error: environment variable {name} is not set")
    return value


def request(method, url, api_key, body=None, content_type=None, attempts=3):
    headers = {"x-api-key": api_key, "Accept": "application/json"}
    if content_type:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    conflicts = 0
    i = 0
    while i < attempts:
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                raw = resp.read()
                return json.loads(raw) if raw else {}
        except urllib.error.HTTPError as e:
            detail = e.read().decode("utf8", "replace")
            # 409: another Luau execution session / upload is still running on the place:
            # wait 60 s and retry, up to 5 times
            if e.code == 409 and conflicts < MAX_409_RETRIES:
                conflicts += 1
                print(f"HTTP 409 (busy), waiting 60 s (retry {conflicts}/{MAX_409_RETRIES})...")
                time.sleep(60)
                continue
            # retry on rate limiting / transient server errors only
            if e.code in (429, 500, 502, 503, 504) and i < attempts - 1:
                i += 1
                time.sleep(2 * i)
                continue
            sys.exit(f"error: {method} {url} -> HTTP {e.code}: {detail}")
        except urllib.error.URLError as e:
            if i < attempts - 1:
                i += 1
                time.sleep(2 * i)
                continue
            sys.exit(f"error: {method} {url} -> {e}")
    sys.exit(f"error: {method} {url} -> gave up")


def upload_place(api_key, universe_id, place_id, place_path, publish):
    version_type = "Published" if publish else "Saved"
    content_type = "application/xml" if place_path.endswith(".rbxlx") else "application/octet-stream"
    with open(place_path, "rb") as f:
        data = f.read()
    url = f"{API}/universes/v1/{universe_id}/places/{place_id}/versions?versionType={version_type}"
    print(f"Uploading {place_path} ({len(data)} bytes) as {version_type} version...")
    result = request("POST", url, api_key, body=data, content_type=content_type)
    version = result.get("versionNumber")
    print(f"Uploaded place version {version}")
    return version


def create_task(api_key, universe_id, place_id, version, script):
    url = f"{API}/cloud/v2/universes/{universe_id}/places/{place_id}/"
    if version:
        url += f"versions/{version}/"
    url += "luau-execution-session-tasks"
    body = json.dumps({"script": script}).encode("utf8")
    return request("POST", url, api_key, body=body, content_type="application/json")


def poll(api_key, task_path):
    deadline = time.time() + TIMEOUT_SECONDS
    while time.time() < deadline:
        task = request("GET", f"{API}/cloud/v2/{task_path}", api_key)
        if task.get("state") not in ("PROCESSING", "QUEUED"):
            sys.stderr.write("\n")
            return task
        sys.stderr.write(".")
        sys.stderr.flush()
        time.sleep(POLL_SECONDS)
    sys.exit("error: timed out waiting for the Luau execution task")


def logs(api_key, task_path):
    result = request("GET", f"{API}/cloud/v2/{task_path}/logs", api_key)
    out = []
    for entry in result.get("luauExecutionSessionTaskLogs", []):
        out.extend(entry.get("messages", []))
    return "\n".join(out)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("place", help="path to the built .rbxl/.rbxlx")
    parser.add_argument("script", help="path to the Luau task script (e.g. tests/run.server.luau)")
    parser.add_argument("--publish", action="store_true", help="publish instead of save (needs explicit approval)")
    parser.add_argument("--dry-run", action="store_true", help="check inputs and print the plan; no network calls")
    parser.add_argument("--no-upload", action="store_true", help="run against the place's current version (no upload)")
    parser.add_argument("--no-wait", action="store_true", help="create the task, print its path and exit (use --resume)")
    parser.add_argument("--resume", metavar="TASK_PATH", help="poll an existing task (from --no-wait) and print its logs")
    args = parser.parse_args()

    if args.resume:
        api_key = env("ROBLOX_API_KEY")
        task = poll(api_key, args.resume)
        return finish(api_key, task)

    for path in (args.place, args.script):
        if not os.path.isfile(path):
            sys.exit(f"error: file not found: {path}")
    with open(args.script, "r", encoding="utf8") as f:
        script = f.read()

    if args.dry_run:
        print(f"[dry-run] would upload {args.place} and run {args.script} ({len(script)} chars)")
        print("[dry-run] env present:", {k: bool(os.environ.get(k)) for k in ("ROBLOX_API_KEY", "ROBLOX_UNIVERSE_ID", "ROBLOX_PLACE_ID")})
        return 0

    api_key = env("ROBLOX_API_KEY")
    universe_id = env("ROBLOX_UNIVERSE_ID")
    if universe_id in FORBIDDEN_UNIVERSES:
        sys.exit(f"error: universe {universe_id} belongs to another game (Ghost Mansion) - refusing")
    place_id = env("ROBLOX_PLACE_ID")

    version = None if args.no_upload else upload_place(api_key, universe_id, place_id, args.place, args.publish)
    task = create_task(api_key, universe_id, place_id, version, script)
    print(f"Task created: {task.get('path')}")
    if args.no_wait:
        return 0
    task = poll(api_key, task["path"])
    return finish(api_key, task)


def finish(api_key, task):
    print(logs(api_key, task["path"]))
    state = task.get("state")
    print(f"Task state: {state}")
    if state == "COMPLETE":
        print("Results:", json.dumps(task.get("output", {}).get("results")))
        return 0
    print("Error:", json.dumps(task.get("error")), file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
