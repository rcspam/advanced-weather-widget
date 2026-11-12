# Weather Maps tab: how much data it downloads

Measured on 2026-11-12 with the Weather Maps branch (`claude/weather-map-layers`, including the 512 px radar tiles change, not pushed yet), view centered on France (46.5 N, 2.5 E).
Default range of the forecast layers: 24 h back, 48 h ahead, 25 images (one every 3 h).
Popup = 1050x680, full screen = 2200x1340, screen scale 1.15.

I run a LibreWXR in Docker at home, but radar and satellite were measured on the public server, api.librewxr.net. For the forecast layers the page pointed at my Docker. That changes nothing in the numbers: only the catalog went through it (1 request, 0 MB), and all the data came from openmeteo.s3.amazonaws.com, the same as with the public LibreWXR server.

## Where each piece comes from

| What is shown | Server |
|---|---|
| Radar, satellite | LibreWXR (api.librewxr.net by default, or the address in the settings) |
| Image catalog (`weather-maps.json`, WebSocket `/v2/ws`) | LibreWXR |
| Alerts, storm cells, lightning (radar options) | LibreWXR |
| Wind, temperature, pressure, precipitation, clouds, humidity, dew point | Open-Meteo, `.om` files on openmeteo.s3.amazonaws.com |
| Air quality | Open-Meteo, same storage (CAMS model) |
| Terrain under wind and temperature | s3.amazonaws.com (elevation tiles, < 1 MB) |
| Base map | OpenFreeMap or the chosen background |

Apart from radar and satellite, everything comes from Open-Meteo. No forecast layer goes through LibreWXR, local or public server alike: the widget never gives the page any other file address.

## How the cache works

### Open-Meteo layers

- The page never downloads a whole file. It reads the end of the file (the indexes), then only the bytes of the variable it needs.
- Each image read is stored in IndexedDB under the key "model, layer, run, hour". An Open-Meteo file never changes, so a stored image is never downloaded again.
- Future images always come from the latest published run. When a new run comes out, they are read again: ECMWF every 6 h; AROME, ICON-D2 every 3 h; UKMO every hour.
- Past images come from the run of their own 6 h slice, and do not change after that.
- The cache keeps 8 days (192 h). The oldest is removed at each opening.

What this gives (computed with the page's code and the publication delays seen on November 12):

| Reopening | ECMWF images to download again |
|---|---|
| Same run (a few minutes, or a few hours before the next run) | 0 of 25, measured: 0.03 MB, ready in 3.3 s |
| 3 h later, a new ECMWF run is out | 20 of 25 |
| 6 h later | 21 of 25 |
| 12 h later | 23 of 25 |
| Next day | 25 of 25: like a first opening |

So the cache helps when the map is reopened during the day, as long as no new run is out. The next day the range has moved by 24 h and everything is new. Regional models follow the same rule, and renew more often.

### Radar and satellite (LibreWXR server)

- Tiles go into the widget's HTTP cache, capped at 150 MB.
- The server answers `cache-control: public, max-age=300` with an ETag, behind Cloudflare. For 5 min a tile comes from the cache with no request at all. After that the browser asks again, and the server answers 304 without sending the image.
- Each radar image (every 10 min) or satellite image (every hour) has its own address. Reopening the map only downloads the new images. The radar range is 3 h (18 images) and the satellite range 12 h (12 images): the next day, everything is new.

## Open-Meteo layers: size and time at the first opening

Popup size. "My connection" time is measured. The 5 Mbit/s time is computed (size x 8 / rate), and checked on pressure: 28.7 s measured with the rate capped at 5 Mbit/s, for 26.4 s computed.

| Layer | Zoom | Models read | Size | My connection | 5 Mbit/s |
|---|---|---|---|---|---|
| Wind | 3 (wide view) | ECMWF | 38 MB | 14 s | 1 min |
| Wind | 5 and 7 (France) | ECMWF + AROME + ICON-D2 + UKMO | 117 MB | 41 to 46 s | 3 min 7 s |
| Temperature | 3 | ECMWF | 24 MB | 8 s | 38 s |
| Temperature | 5 and 7 | ECMWF + 3 regional | 75 MB | 22 s | 2 min |
| Clouds | all | ECMWF | 66 MB | 34 s | 1 min 45 s |
| Dew point | all | ECMWF | 35 MB | 12 s | 56 s |
| Precipitation | all | ECMWF | 22 MB | 22 s | 36 s |
| Humidity | all | ECMWF | 19 MB | 6 s | 31 s |
| Pressure | all | ECMWF | 17 MB | 7 s | 26 s (29 s measured) |
| Air quality | all | CAMS | 13 MB | 7 s | 20 s |

Zoom only matters for wind and temperature, the only two layers that add regional models:
- If the view is more than 60° wide, no regional model is read.
- Closer in, the page takes up to 3 models that cover at least 2 % of the view, each read over its whole domain. At zoom 7 over central France, ICON-D2 and UKMO still touch the frame: same weight as zoom 5.
- The window size changes nothing for these layers. Full screen does not download more.

Each layer turned on adds up. Wind + temperature over France: 192 MB the first time.

## Radar and satellite: what the LibreWXR server receives

Public server api.librewxr.net, browser cache off. For each case, first pass then second pass (Cloudflare cache warm).

| Window | Zoom | Radar (18 images) | Satellite (12 images) |
|---|---|---|---|
| Popup | 3 | 162 tiles, 9.8 MB, 3.9 s then 1.4 s | 108 tiles, 21.5 MB, 3.9 s then 1.2 s |
| Popup | 5 | 162 tiles, 12.9 MB, 4.6 s then 1.5 s | 108 tiles, 5.7 MB, 2.7 s then 1.1 s |
| Popup | 7 | 162 tiles, 18.1 MB, 5.3 s then 1.2 s | 108 tiles, 0.7 MB, 1.7 s then 0.8 s |
| Full screen | 3 | 324 tiles, 20.3 MB, 9.6 s then 2.2 s | 216 tiles, 46.2 MB, 3.1 s then 1.9 s |
| Full screen | 5 | 324 tiles, 18.1 MB, 4.3 s then 2.1 s | 216 tiles, 13.0 MB, 3.3 s then 1.7 s |
| Full screen | 7 | 270 tiles, 33.0 MB, 12.4 s then 2.1 s | 180 tiles, 1.1 MB, 3.1 s then 1.1 s |

- 512 px tiles, laid on a 512 grid since the radar tiles change. Before it, full screen asked for about 1080 radar tiles.
- At 5 Mbit/s, the heaviest case (satellite, full screen, zoom 3, 46 MB) would take about 74 s, and radar in the popup at zoom 5 about 21 s.
- One satellite pass, full screen at zoom 7, took 149 s for 1.1 MB, while the other passes of the same case took 1 to 3 s. The tiles had arrived, my bench was the one waiting. I don't count that number.
- The catalog arrives by WebSocket, through viewer-core. On top of that, the page reads `weather-maps.json` over HTTP every 5 min (`animCatalog`, in `glue-controls.js`). That is a duplicate that can go.

## Ideas for a limited connection

- For past images, accepting an image already stored from an older run would avoid reading them again after each new run. The image would be slightly less accurate.
- A shorter range reduces everything in proportion (25 images by default).

### Preparing the layers in the background

The goal: on a slow connection, the images are already on the computer when the user opens the map.

What already exists: with "Keep the radar loaded", the page stays alive while the popup is closed. It looks for a new radar image every 5 min and prepares it (`glue-prepare.js`). Forecast layers don't: they only read `latest.json` and their images when shown (`Frames.load`, `glue-anim.js`).

The addition: the hidden page reads `latest.json` of the layers turned on, for example every 10 min. At each new run, it stores the new images in IndexedDB, one at a time.

Volume per day if the page follows every run (simulated with the page's own run rules and the measured sizes, view over France):

| Model | New images per day | Wind | Temperature |
|---|---|---|---|
| ECMWF (run every 6 h) | 88 | 133 MB | 80 MB |
| AROME (3 h) | 144 | 147 MB | 99 MB |
| ICON-D2 (3 h) | 136 | 148 MB | 105 MB |
| UKMO (1 h) | 216 | 243 MB | 147 MB |
| Total | | 670 MB | 430 MB |

At 5 Mbit/s, 670 MB is about 18 min of download per day, in small pieces. ECMWF alone: 3 min 30 for wind.

**It does not download less, it downloads earlier, even if the map is never opened. Good for a slow unlimited connection, bad for a metered one. A switch in the widget settings is enough, off by default, next to "Keep the radar loaded". Everyone picks what fits their connection. Only the layers turned on are prepared.**
