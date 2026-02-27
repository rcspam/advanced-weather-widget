#!/bin/sh
# Extract and merge translations for the plasmoid
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
PACKAGE_ROOT="$DIR/.."
DOMAIN="plasma_applet_org.kde.plasma.advanced-weather-widget"

# List translatable sources
find "$PACKAGE_ROOT" -name '*.qml' -o -name '*.js' | sort > "$DIR/infiles.list"

xgettext \
  --files-from="$DIR/infiles.list" \
  --from-code=UTF-8 \
  --width=400 \
  --add-location=file \
  -C -kde -ci18n -ki18n:1 -ki18nc:1c,2 -ki18np:1,2 -ki18ncp:1c,2,3 -ktr2i18n:1 \
  --package-name="$DOMAIN" \
  -o "$DIR/template.pot.new" \
  || { echo "[merge] xgettext failed"; exit 1; }

# Ensure charset is UTF-8
sed -i 's/charset=CHARSET/charset=UTF-8/' "$DIR/template.pot.new"

# Replace template if changed
if [ ! -f "$DIR/template.pot" ] || ! cmp -s "$DIR/template.pot.new" "$DIR/template.pot"; then
  mv "$DIR/template.pot.new" "$DIR/template.pot"
else
  rm "$DIR/template.pot.new"
fi

# Merge updates into existing .po files
for POFILE in "$DIR"/*.po; do
  [ -f "$POFILE" ] || continue
  msgmerge --update --backup=none "$POFILE" "$DIR/template.pot"
done

echo "Done. Run ./build.sh to generate .mo files."
