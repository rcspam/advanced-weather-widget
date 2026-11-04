#!/bin/bash
# Open the animation test window: the MapLibre page of this branch
# (contents/ui/components/librewxr-anim-test.html, built by build-test.py)
# in a window of its own, with the QML time bar of AnimWindow.qml. It uses
# the system Qt, so the same QtWebEngine and Kirigami as the widget.
# THEME=light ./run.sh for the light page, EXTRA=--narrow for a 600 px window.
D=$(dirname "$(readlink -f "$0")")
cd "$D" || exit 1

if [ ! -x launcher/build/qmlwindow ]; then
  cmake -S launcher -B launcher/build -DCMAKE_BUILD_TYPE=Release >/dev/null &&
    cmake --build launcher/build >/dev/null || { echo "launcher build failed"; exit 1; }
fi

if [ -z "$THEME" ]; then
  # Dark unless the KDE window background is light.
  BGC=$(kreadconfig6 --group Colors:Window --key BackgroundNormal 2>/dev/null)
  THEME=dark
  [ -n "$BGC" ] && [ "$(echo "$BGC" | awk -F, '{print ($1+$2+$3 > 384)}')" = 1 ] && THEME=light
fi

TOP=$(python3 -c 'import sys,urllib.parse as u; print(dict(u.parse_qsl(sys.argv[1]))["tempopacity"])' "$(python3 page-query.py "$D" "$THEME")")
printf '<!doctype html><script>location.replace("file://%s/contents/ui/components/librewxr-anim-test.html?%s")</script>\n' \
  "$(dirname "$D")" "$(python3 page-query.py "$D" "$THEME")" > launch.html

QT_QUICK_CONTROLS_STYLE=org.kde.desktop exec launcher/build/qmlwindow "$D/AnimWindow.qml" "--temp-opacity=$TOP" $EXTRA
