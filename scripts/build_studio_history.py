"""Export the exact build's complete reachable Git history (no browser API/token)."""
import argparse
import json
import subprocess
from pathlib import Path


def git(*args):
    return subprocess.check_output(["git", *args])


def history():
    if git("rev-parse", "--is-shallow-repository").strip() != b"false":
        raise RuntimeError("Studio history requires full Git checkout")
    head = git("rev-parse", "HEAD").decode().strip()
    fields = git("log", "-z", "--date-order", "--format=%H%x00%cI%x00%P%x00%B", head).decode("utf-8", errors="replace").split("\0")
    if fields.pop() != "" or len(fields) % 4:
        raise RuntimeError("Unexpected Git history format")
    entries = []
    for i in range(0, len(fields), 4):
        sha, date, parents, message = fields[i:i+4]
        lines = message.strip().splitlines()
        entries.append(dict(sha=sha, date=date, parents=parents.split(),
                            title=lines[0] if lines else "(без описания)",
                            body="\n".join(lines[1:]).strip()))
    if not entries or entries[0]["sha"] != head or len({x["sha"] for x in entries}) != len(entries):
        raise RuntimeError("Incomplete or duplicate Git history")
    return dict(schema="chernozerye.studio.commit-history", version=1, head=head, entries=entries)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    doc = history()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(doc, ensure_ascii=False) + "\n", encoding="utf-8")
    print("STUDIO_COMMIT_HISTORY_READY:", len(doc["entries"]), doc["head"])
