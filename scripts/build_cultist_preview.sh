#!/usr/bin/env bash
set -euo pipefail
python -m venv /tmp/chnpc
/tmp/chnpc/bin/pip install -q numpy trimesh
mkdir -p public
/tmp/chnpc/bin/python scripts/build_cultist_v08.py public/cultist_v08.glb
cp site/cultist/index.html public/index.html
/tmp/chnpc/bin/python - <<'PY'
from pathlib import Path
import trimesh

asset = Path("public/cultist_v08.glb")
scene = trimesh.load(asset, force="scene")
expected = {"Head","Torso","LeftArm","RightArm","LeftLeg","RightLeg","LeftShin","RightShin","LeftFoot","RightFoot"}
missing=expected-set(scene.graph.nodes)
assert not missing, f"Missing articulated asset groups: {missing}"
assert len(scene.geometry) == 10
triangles = sum(len(mesh.faces) for mesh in scene.geometry.values())
assert triangles >= 50000, triangles
assert asset.stat().st_size > 10000
html = Path("public/index.html").read_text()
assert 'MODEL DETAIL v0.8' in html
script = html.split('<script type="module">',1)[1].split('</script>',1)[0]
Path("/tmp/cultist_preview_check.mjs").write_text(script)
print("CULTIST_V08_OK",triangles,"triangles",asset.stat().st_size,"bytes",len(expected),"rig groups")
PY
node --check /tmp/cultist_preview_check.mjs
