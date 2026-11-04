#!/usr/bin/env python3
"""Build the MapLibre page of the animations worktree under another name,
librewxr-anim-test.html, next to the real one (same vendor/ folder). The
real librewxr-map.html is left alone. Usage:
build-test.py <LibreWXR checkout> (the sources build_librewxr_map.py reads)."""
import os, sys
WT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(WT, "scripts"))
import build_librewxr_map as b
name, shell, frags = b.PAGES[0]
page = b.build_page(sys.argv[1], shell, frags)
# Spikes kept out of the sources go at the end of the page's module, where
# they reach its variables (ANIM_LAYERS, anim, the adapter).
here = os.path.dirname(os.path.abspath(__file__))
spikes = [os.path.join(here, f) for f in ("pressure-spike.js", "aq-spike.js", "precip-spike.js", "clouds-spike.js", "humidity-spike.js", "wind-level-spike.js", "loop-spike.js") if os.path.isfile(os.path.join(here, f)) and not os.environ.get("NOSPIKE")]
if spikes:
    cut = page.rindex("</script>")
    page = page[:cut] + "".join(open(f, encoding="utf-8").read() + "\n" for f in spikes) + page[cut:]
out = os.path.join(WT, "contents/ui/components/librewxr-anim-test.html")
open(out, "w", encoding="utf-8").write(page)
print("wrote", out, len(page), "bytes")
