import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent / "lambdas" / "common"))

from kafenox_common.origin_geocode import geocode_origin  # noqa: E402


def test_region_level_lookup_takes_precedence():
    lat, lng = geocode_origin("Ethiopia", "Yirgacheffe")
    assert (lat, lng) == (6.1611, 38.2056)


def test_falls_back_to_country_level():
    lat, lng = geocode_origin("Ethiopia", "SomeUnknownRegion")
    assert (lat, lng) == (9.145, 40.4897)


def test_returns_none_for_unknown_origin():
    lat, lng = geocode_origin("Atlantis", None)
    assert (lat, lng) == (None, None)


def test_returns_none_when_country_missing():
    lat, lng = geocode_origin(None, None)
    assert (lat, lng) == (None, None)
