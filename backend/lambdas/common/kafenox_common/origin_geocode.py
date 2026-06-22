import json
from pathlib import Path

_CENTROIDS_PATH = Path(__file__).parent / "origin_centroids.json"
_centroids: dict | None = None


def _load_centroids() -> dict:
    global _centroids
    if _centroids is None:
        with open(_CENTROIDS_PATH) as f:
            _centroids = json.load(f)
    return _centroids


def geocode_origin(
    country: str | None, region: str | None
) -> tuple[float, float] | tuple[None, None]:
    """Look up a lat/lng centroid for a coffee origin.

    Tries "Country:Region" first for region-level precision, falls back to
    "Country", falls back to (None, None) if neither is known -- the map UI
    simply omits unplaceable pins rather than guessing.
    """
    centroids = _load_centroids()

    if country and region:
        key = f"{country}:{region}"
        if key in centroids:
            point = centroids[key]
            return point["lat"], point["lng"]

    if country and country in centroids:
        point = centroids[country]
        return point["lat"], point["lng"]

    return None, None
