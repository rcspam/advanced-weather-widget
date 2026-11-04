#!/usr/bin/env python3
"""Print the query of the animation test page, taken from the settings of
the first Advanced Weather Widget found in the Plasma config (location,
LibreWXR server, base map, temperature opacity), with the widget's defaults
when there is none. Usage: page-query.py <preview dir> <theme>"""
import json, locale, os, sys, urllib.parse as u

here, theme = sys.argv[1], sys.argv[2]
cfg = os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
                   "plasma-org.kde.plasma.desktop-appletsrc")

groups, cur = {}, None
if os.path.isfile(cfg):
    for line in open(cfg, encoding="utf-8", errors="replace"):
        line = line.rstrip("\n")
        if line.startswith("["):
            cur = line
            groups[cur] = {}
        elif "=" in line and cur:
            k, v = line.split("=", 1)
            groups[cur][k] = v

conf = {}
for g, kv in groups.items():
    if kv.get("plugin") == "org.kde.plasma.advanced-weather-widget":
        conf = groups.get(g + "[Configuration][General]", {})
        break

lang = (os.environ.get("LANG") or locale.getlocale()[0] or "en_US").split(".")[0]
q = {
    "lat": conf.get("latitude", "48.85"),
    "lon": conf.get("longitude", "2.35"),
    "zoom": "6", "layer": "radar", "color": "3", "arrows": "1", "wind": "0",
    "cells": "", "alerts": "1", "smooth": "1", "snow": "1",
    "format": "webp", "tilesize": "256", "theme": theme,
    "server": (conf.get("librewxrUrl") or "https://api.librewxr.net").strip(),
    "hour12": "0", "locale": lang.replace("_", "-"),
    "bg": conf.get("mapBackground") or "auto",
    "bglist": open(os.path.join(here, "bglist-%s.json" % theme), encoding="utf-8").read().strip(),
    "temp": "0",
    "tempopacity": conf.get("librewxrTempOpacity") or "45",
}
print(u.urlencode(q, quote_via=u.quote))
