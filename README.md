# Ethiopia Cities and Towns — R

Collect OpenStreetMap features tagged `place=city` or `place=town` throughout Ethiopia using the R `osmdata` package. Export a CSV and point GeoJSON with names, longitude (x), latitude (y), and the area of a mapped place polygon **when available**.

## Run

Install [R](https://cran.r-project.org/) and run in this directory:

```bash
Rscript fetch_cities.R
```

The script automatically installs any missing CRAN packages. It divides Ethiopia's bounding box into 2-degree tiles and requests features from the public Overpass API. It may take a while, and some requests may fail due to server limits. Failed tiles are recorded in `data/failed_tiles.txt`. **If there are failed tiles, the extracted dataset is incomplete.**

The generated files are:
- `data/ethiopia_cities_towns.csv`: tabular results
- `data/ethiopia_cities_towns.geojson`: point locations
- `data/failed_tiles.txt`: failed query tiles (ideally empty)

## Fields

`name`, `name_am`, `name_en`, `type`, `x`, `y`, `area_km2`, `area_method`, `osm_type`, `osm_id`.

Coordinates are WGS84 EPSG:4326. `x` means longitude and `y` latitude. Polygon areas are measured in an equal-area projection (EPSG:6933). Missing area is left blank, not approximated. If a place polygon is present, its area is **not necessarily the city's administrative area or built-up area**. Polygon features and point features may both represent the same named settlement; the script deduplicates repeated OSM IDs, not different objects that may refer to the same town.

This dataset includes *mapped* cities and towns, not necessarily every town in Ethiopia. The Natural Earth country outline is simplified; a few settlements close to international borders may be excluded. For a more robust nationwide data pipeline, use the full Ethiopia OSM PBF extract and official boundary data.

## Publish on GitHub

```bash
git init
git add .
git commit -m "Add Ethiopia cities and towns R extractor"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/ethiopia-cities-towns-r.git
git push -u origin main
```

Replace `YOUR_USERNAME` and first create an empty repository with the same name on GitHub. Generated CSV/GeoJSON are ignored by default in `.gitignore`; remove those patterns if you wish to publish generated results **after checking that no tiles failed**.

## Data license and credit

© OpenStreetMap contributors. OpenStreetMap data is licensed under the [Open Database License (ODbL)](https://www.openstreetmap.org/copyright). See its attribution and share-alike requirements when distributing a derived database. Natural Earth provides the simplified country outline. The R source code in this repository is released under MIT License.

## Run on GitHub without installing R locally

This repository contains `.github/workflows/build-dataset.yml` (GitHub Actions). Once the repository is on GitHub, open **Actions → Build Ethiopia cities and towns dataset → Run workflow**. When finished, open the workflow run and download the `ethiopia-cities-towns-data` artifact. The generated data is *not* committed to the repository automatically. Check `failed_tiles.txt` before treating the dataset as complete. Public Overpass servers may return errors or time out, and the run may take a long time.

**Privacy & licensing:** Only public OSM geographical feature data is requested. Credit © OpenStreetMap contributors. Review ODbL obligations before redistributing the generated data files.
