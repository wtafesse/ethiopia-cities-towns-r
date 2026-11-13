# Ethiopia cities and towns via OpenStreetMap's Overpass API.
# Run: Rscript fetch_cities.R
# X = longitude, Y = latitude (EPSG:4326).

packages <- c("osmdata", "sf", "dplyr", "readr", "rnaturalearth", "rnaturalearthdata")
missing <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")

library(sf)
library(dplyr)

if (!dir.exists("data")) dir.create("data")

# Natural Earth outline is only used to exclude neighboring countries.
ethiopia <- rnaturalearth::ne_countries(country = "Ethiopia", scale = "small", returnclass = "sf")
ethiopia <- st_transform(ethiopia, 4326)
bbox <- st_bbox(ethiopia)

# Overpass is a shared public service. Smaller requests reduce timeouts.
step_deg <- 2
x_edges <- seq(floor(bbox["xmin"]), ceiling(bbox["xmax"]) + step_deg, by = step_deg)
y_edges <- seq(floor(bbox["ymin"]), ceiling(bbox["ymax"]) + step_deg, by = step_deg)

tiles <- expand.grid(ix = seq_len(length(x_edges) - 1),
                     iy = seq_len(length(y_edges) - 1))

extract_layer <- function(layer, kind) {
  if (is.null(layer) || nrow(layer) == 0L) return(NULL)
  if (!("name" %in% names(layer))) return(NULL)
  layer <- layer[!is.na(layer$name) & nzchar(layer$name), ]
  if (nrow(layer) == 0L) return(NULL)
  for (col in c("name:am", "name:en", "place")) {
    if (!col %in% names(layer)) layer[[col]] <- NA_character_
  }
  layer$osm_type <- kind
  layer[, c("osm_id", "osm_type", "name", "name:am", "name:en", "place", "geometry")]
}

parts <- list()
failed_tiles <- character()

for (k in seq_len(nrow(tiles))) {
  i <- tiles$ix[k]
  j <- tiles$iy[k]
  tile_bbox <- c(x_edges[i], y_edges[j], x_edges[i + 1], y_edges[j + 1])
  tile_id <- sprintf("%g_%g", tile_bbox[1], tile_bbox[2])
  tile_geom <- st_as_sfc(st_bbox(c(xmin = tile_bbox[1], ymin = tile_bbox[2],
                                  xmax = tile_bbox[3], ymax = tile_bbox[4]), crs = 4326))
  if (!lengths(st_intersects(tile_geom, ethiopia))) next
  message("Fetching tile ", k, "/", nrow(tiles), " (", tile_id, ")")
  result <- NULL
  for (attempt in 1:3) {
    result <- tryCatch({
      q <- osmdata::opq(bbox = tile_bbox, timeout = 180)
      q <- osmdata::add_osm_feature(q, key = "place", value = c("city", "town"))
      osmdata::osmdata_sf(q)
    }, error = function(e) {
      message("  Attempt ", attempt, " failed: ", conditionMessage(e))
      NULL
    })
    if (!is.null(result)) break
    Sys.sleep(attempt * 3)
  }
  if (is.null(result)) {
    failed_tiles <- c(failed_tiles, tile_id)
    next
  }
  layers <- list(
    extract_layer(result$osm_points, "node"),
    extract_layer(result$osm_polygons, "way"),
    extract_layer(result$osm_multipolygons, "relation")
  )
  layers <- Filter(Negate(is.null), layers)
  if (length(layers)) parts <- append(parts, layers)
  Sys.sleep(1) # be considerate of the public Overpass service
}

if (!length(parts)) stop("No OSM features were returned. Check internet access / Overpass availability.")

features <- dplyr::bind_rows(parts) |>
  dplyr::distinct(osm_type, osm_id, .keep_all = TRUE)

# Use a point inside each feature, then filter out points in neighboring countries.
# sf operations are carried out in EPSG:4326 for coordinates and equal-area EPSG:6933 for area.
feature_points <- suppressWarnings(st_point_on_surface(st_transform(features, 6933))) |>
  st_transform(4326)
inside <- lengths(st_intersects(feature_points, ethiopia)) > 0
features <- features[inside, ]
feature_points <- feature_points[inside, ]

xy <- st_coordinates(feature_points)
geom_types <- as.character(st_geometry_type(features))
area <- rep(NA_real_, nrow(features))
polygon_rows <- which(geom_types %in% c("POLYGON", "MULTIPOLYGON"))
if (length(polygon_rows)) {
  area[polygon_rows] <- round(as.numeric(st_area(st_transform(features[polygon_rows, ], 6933))) / 1e6, 3)
}

output <- data.frame(
  name = features$name,
  name_am = features[["name:am"]],
  name_en = features[["name:en"]],
  type = features$place,
  x = round(xy[, "X"], 6),
  y = round(xy[, "Y"], 6),
  area_km2 = area,
  area_method = ifelse(is.na(area), "not_available", "OSM_place_polygon"),
  osm_type = features$osm_type,
  osm_id = features$osm_id,
  stringsAsFactors = FALSE
) |>
  dplyr::arrange(name, osm_type, osm_id)

readr::write_csv(output, "data/ethiopia_cities_towns.csv", na = "")
st_write(st_as_sf(output, coords = c("x", "y"), crs = 4326, remove = FALSE),
         "data/ethiopia_cities_towns.geojson", delete_dsn = TRUE, quiet = TRUE)
writeLines(failed_tiles, "data/failed_tiles.txt")
message("Done: ", nrow(output), " records. Polygon areas: ", sum(!is.na(area)))
if (length(failed_tiles)) warning(length(failed_tiles), " tiles failed. Dataset is incomplete; see data/failed_tiles.txt")
message("Files saved to data/.")
