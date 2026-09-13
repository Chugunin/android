#!/usr/bin/env python3
import argparse
import concurrent.futures as cf
import hashlib
import json
import os
import stat
import sys
import time
import urllib.parse
import urllib.request

UA = "gts3llte-prebuilt-downloader/1.1"

def api_get(url, token=None):
    headers = {"User-Agent": UA, "Accept": "application/vnd.github+json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def resolve_tag(owner, repo, tag, token=None):
    base = f"https://api.github.com/repos/{owner}/{repo}"
    ref = api_get(f"{base}/git/ref/tags/{urllib.parse.quote(tag, safe='')}", token)
    obj = ref["object"]
    for _ in range(8):
        if obj["type"] == "commit":
            return obj["sha"]
        if obj["type"] != "tag":
            raise RuntimeError(f"Unexpected ref object type: {obj['type']}")
        obj = api_get(f"{base}/git/tags/{obj['sha']}", token)["object"]
    raise RuntimeError("Too many nested tag objects")

def get_tree(owner, repo, commit_sha, token=None):
    base = f"https://api.github.com/repos/{owner}/{repo}"
    commit = api_get(f"{base}/git/commits/{commit_sha}", token)
    tree_sha = commit["tree"]["sha"]
    tree = api_get(f"{base}/git/trees/{tree_sha}?recursive=1", token)
    if tree.get("truncated"):
        raise RuntimeError("GitHub returned a truncated recursive tree")
    return tree_sha, tree["tree"]

def git_blob_sha_file(path):
    size = os.path.getsize(path)
    h = hashlib.sha1()
    h.update(f"blob {size}\0".encode("ascii"))
    with open(path, "rb") as f:
        while True:
            b = f.read(8 * 1024 * 1024)
            if not b:
                break
            h.update(b)
    return h.hexdigest()

def git_blob_sha_bytes(data):
    h = hashlib.sha1()
    h.update(f"blob {len(data)}\0".encode("ascii"))
    h.update(data)
    return h.hexdigest()

def raw_url(owner, repo, commit_sha, path):
    q = "/".join(urllib.parse.quote(p, safe="") for p in path.split("/"))
    return f"https://raw.githubusercontent.com/{owner}/{repo}/{commit_sha}/{q}"

def download_one(owner, repo, commit_sha, e, dest_root, retries, token):
    rel = e["path"]
    mode = e["mode"]
    expected_sha = e["sha"]
    expected_size = e.get("size")
    dest = os.path.join(dest_root, *rel.split("/"))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    try:
        if mode == "120000" and os.path.islink(dest):
            if git_blob_sha_bytes(os.readlink(dest).encode("utf-8")) == expected_sha:
                return ("skip", rel, expected_size or 0)
        elif os.path.isfile(dest) and not os.path.islink(dest):
            if expected_size is None or os.path.getsize(dest) == expected_size:
                if git_blob_sha_file(dest) == expected_sha:
                    if mode == "100755":
                        os.chmod(dest, os.stat(dest).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
                    return ("skip", rel, expected_size or os.path.getsize(dest))
    except OSError:
        pass
    part = dest + ".part"
    url = raw_url(owner, repo, commit_sha, rel)
    for attempt in range(1, retries + 1):
        try:
            headers = {"User-Agent": UA}
            if token:
                headers["Authorization"] = f"Bearer {token}"
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=120) as r, open(part, "wb") as out:
                while True:
                    b = r.read(8 * 1024 * 1024)
                    if not b:
                        break
                    out.write(b)
            actual_sha = git_blob_sha_file(part)
            if actual_sha != expected_sha:
                raise IOError(f"SHA mismatch: expected {expected_sha}, got {actual_sha}")
            if mode == "120000":
                with open(part, "rb") as f:
                    target = f.read().decode("utf-8")
                try:
                    os.remove(dest)
                except FileNotFoundError:
                    pass
                os.symlink(target, dest)
                os.remove(part)
            else:
                os.replace(part, dest)
                if mode == "100755":
                    os.chmod(dest, os.stat(dest).st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
            return ("ok", rel, expected_size or os.path.getsize(dest))
        except Exception as ex:
            try:
                if os.path.exists(part):
                    os.remove(part)
            except OSError:
                pass
            if attempt >= retries:
                return ("fail", rel, str(ex))
            time.sleep(min(5 * attempt, 30))

def main():
    p = argparse.ArgumentParser()
    p.add_argument("repo")
    p.add_argument("tag")
    p.add_argument("dest")
    p.add_argument("-j", "--jobs", type=int, default=8)
    p.add_argument("--retries", type=int, default=10)
    a = p.parse_args()
    if "/" not in a.repo:
        p.error("repo must be owner/repo")
    owner, repo = a.repo.split("/", 1)
    token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    dest_root = os.path.abspath(os.path.expanduser(a.dest))
    os.makedirs(dest_root, exist_ok=True)
    print(f"[1/4] Resolve {a.repo}@{a.tag}", flush=True)
    commit_sha = resolve_tag(owner, repo, a.tag, token)
    print(f"      commit {commit_sha}", flush=True)
    print("[2/4] Get recursive tree", flush=True)
    tree_sha, entries = get_tree(owner, repo, commit_sha, token)
    blobs = [e for e in entries if e["type"] == "blob"]
    dirs = [e for e in entries if e["type"] == "tree"]
    print(f"      tree {tree_sha}; files={len(blobs)} dirs={len(dirs)}", flush=True)
    for d in dirs:
        os.makedirs(os.path.join(dest_root, *d["path"].split("/")), exist_ok=True)
    meta_dir = os.path.join(dest_root, ".bootstrap-meta")
    os.makedirs(meta_dir, exist_ok=True)
    with open(os.path.join(meta_dir, "github-tree-manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"repo": a.repo, "tag": a.tag, "commit": commit_sha, "tree": tree_sha, "files": blobs}, f, ensure_ascii=False, indent=2)
    print(f"[3/4] Download/verify -> {dest_root}", flush=True)
    ok = skipped = failed = verified = 0
    failures = []
    with cf.ThreadPoolExecutor(max_workers=max(1, a.jobs)) as ex:
        futures = [ex.submit(download_one, owner, repo, commit_sha, e, dest_root, a.retries, token) for e in blobs]
        total = len(futures)
        for i, fut in enumerate(cf.as_completed(futures), 1):
            status, rel, info = fut.result()
            if status == "ok":
                ok += 1; verified += int(info or 0)
            elif status == "skip":
                skipped += 1; verified += int(info or 0)
            else:
                failed += 1; failures.append((rel, info)); print(f"\nFAIL {rel}: {info}", file=sys.stderr, flush=True)
            if i == 1 or i % 25 == 0 or i == total:
                print(f"\r      {i}/{total} ok={ok} skip={skipped} fail={failed} verified={verified/(1024**3):.2f} GiB", end="", flush=True)
    print()
    print("[4/4] Result")
    print(f"      ok={ok} skipped={skipped} failed={failed}")
    if failures:
        fp = os.path.join(meta_dir, "download-failures.txt")
        with open(fp, "w", encoding="utf-8") as f:
            for rel, err in failures:
                f.write(f"{rel}\t{err}\n")
        print(f"      failures: {fp}")
        print("Run the exact same command again; verified files will be skipped.")
        sys.exit(2)
    print("SUCCESS: all files match the Git SHA from the requested tag.")

if __name__ == "__main__":
    main()
