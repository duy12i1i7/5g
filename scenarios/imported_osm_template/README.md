# Imported OSM Scenario Template

Use this directory as the landing zone for larger SUMO road networks generated from OpenStreetMap inputs.

Recommended workflow:

1. Export or download an `.osm.xml` file for the target city area.
2. Run:

   ```bash
   ./scripts/import_osm_map.sh \
     --osm-file /path/to/city.osm.xml \
     --output-dir scenarios/imported_osm_template/assets \
     --prefix city_core
   ```

3. Copy or adapt the vehicular scenario:

   - start from `scenarios/vehicular_multi_cell/UrbanGrid5G.ned`
   - duplicate `scenarios/vehicular_multi_cell/omnetpp.ini`
   - point the launchd and SUMO config files at the generated assets

4. Keep imported map assets out of git unless the dataset is intentionally pinned for a benchmark release.

This template is intentionally documentation-first. The pinned research baseline remains the generated urban grid scenario so the repository stays lightweight and deterministic.
