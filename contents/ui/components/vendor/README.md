# Open-Meteo file reader

Vendored for the radar map (librewxr-map.html), which reads the wind of the
whole planet from Open-Meteo's open-data files
(https://openmeteo.s3.amazonaws.com/data_spatial/).

- `index.browser.js`: `@openmeteo/file-reader` 0.0.20, `dist/esm/index.browser.js`
- `om_file_format.web.js`, `om_file_format.web.wasm`: `@openmeteo/file-format-wasm` 0.0.20, `dist/`

License: GPL-2.0-only (https://github.com/open-meteo/typescript-omfiles).

Served from unpkg, the WebAssembly arrives truncated in QtWebEngine, hence
this local copy.

# Coasts and borders

`coast-borders.bin`: the coasts and land borders the radar map draws over
its color layers (temperature...). Natural Earth 1:10m, public domain
(https://www.naturalearthdata.com/), simplified to about 500 m and packed by
`scripts/make_coast_lines.py`.

# Moon

`moon.jpg`: the Moon's colors, equirectangular, 0 degrees of longitude in
the middle, for the Moon drawn around the globe. NASA's Scientific
Visualization Studio, CGI Moon Kit (Lunar Reconnaissance Orbiter Camera
color map, `lroc_color_poles_1k.jpg`), public domain
(https://svs.gsfc.nasa.gov/4720), scaled down to 512 x 256.

# Night lights

`night-lights.jpg`: the lights of the Earth at night, grey,
equirectangular, 3600 x 1800 (0.1 degree), for the towns lit on the night
side of the map. NASA Earth Observatory, Black Marble 2016
(`BlackMarble_2016_01deg_gray.jpg`, Suomi NPP VIIRS), public domain
(https://earthobservatory.nasa.gov/features/NightLights), as published.
