#!/usr/bin/env python3
"""Generate the deterministic terrestrial-planet proof assets."""

from __future__ import annotations

import argparse
from array import array
import hashlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import zipfile
import zlib


GENERATOR_VERSION = 2
SEED = 0x45415254
TEXTURE_WIDTH = 1024
TEXTURE_HEIGHT = 512
RADIAL_SEGMENTS = 256
VERTICAL_SEGMENTS = 128
SEA_LEVEL_SAMPLE = 32768

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT_DIRECTORY = REPOSITORY_ROOT / "Engine2/Game Content/Planet/Assets"

ELEVATION_NAME = "TerrestrialPlanetElevation.png"
SURFACE_NAME = "TerrestrialPlanetSurface.png"
CONTROL_NAME = "TerrestrialPlanetControl.png"
CLOUDS_NAME = "TerrestrialPlanetClouds.png"
USDA_NAME = "TerrestrialPlanet.usda"
USDZ_NAME = "TerrestrialPlanet.usdz"
MANIFEST_NAME = "TerrestrialPlanetManifest.json"

ASSET_NAMES = (
    ELEVATION_NAME,
    SURFACE_NAME,
    CONTROL_NAME,
    CLOUDS_NAME,
    USDA_NAME,
    USDZ_NAME,
)
GENERATED_NAMES = ASSET_NAMES + (MANIFEST_NAME,)

# These coarse, hand-authored silhouettes provide recognizable geography
# without consuming source pixels or map data from the visual reference.
AFRICA = (
    (-17.0, 37.0), (-7.0, 35.0), (1.0, 37.0), (10.0, 37.0),
    (19.0, 34.0), (27.0, 31.0), (32.0, 31.0), (35.0, 25.0),
    (36.0, 20.0), (41.0, 15.0), (51.0, 11.0), (47.0, 5.0),
    (43.0, -2.0), (41.0, -11.0), (36.0, -21.0), (32.0, -29.0),
    (25.0, -34.0), (18.0, -35.0), (11.0, -30.0), (7.0, -23.0),
    (10.0, -10.0), (13.0, -3.0), (12.0, 1.0), (9.0, 4.0),
    (2.0, 4.0), (-4.0, 6.0), (-10.0, 10.0), (-15.0, 17.0),
    (-17.0, 25.0),
)
ARABIA = (
    (33.0, 30.0), (47.0, 30.0), (56.0, 24.0), (54.0, 16.0),
    (47.0, 12.0), (42.0, 16.0), (37.0, 22.0),
)
EURASIA = (
    (-11.0, 36.0), (-9.0, 49.0), (3.0, 59.0), (22.0, 70.0),
    (55.0, 76.0), (95.0, 71.0), (132.0, 61.0), (168.0, 53.0),
    (165.0, 40.0), (145.0, 30.0), (113.0, 23.0), (94.0, 23.0),
    (84.0, 9.0), (74.0, 8.0), (66.0, 20.0), (55.0, 28.0),
    (47.0, 30.0), (40.0, 35.0), (30.0, 39.0), (16.0, 42.0),
    (5.0, 40.0),
)
SOUTH_AMERICA = (
    (-82.0, 12.0), (-69.0, 10.0), (-50.0, 4.0), (-36.0, -7.0),
    (-42.0, -21.0), (-54.0, -36.0), (-66.0, -56.0),
    (-74.0, -44.0), (-79.0, -22.0),
)
NORTH_AMERICA = (
    (-168.0, 69.0), (-133.0, 75.0), (-96.0, 72.0), (-61.0, 56.0),
    (-53.0, 45.0), (-67.0, 25.0), (-82.0, 15.0), (-98.0, 18.0),
    (-116.0, 30.0), (-127.0, 49.0), (-151.0, 58.0),
)
GREENLAND = (
    (-57.0, 59.0), (-28.0, 60.0), (-13.0, 73.0), (-28.0, 83.0),
    (-54.0, 82.0), (-72.0, 70.0),
)
AUSTRALIA = (
    (113.0, -11.0), (132.0, -10.0), (153.0, -25.0),
    (146.0, -42.0), (125.0, -44.0), (112.0, -30.0),
)
MADAGASCAR = (
    (47.0, -12.0), (51.0, -17.0), (49.0, -27.0),
    (45.0, -25.0), (43.5, -19.0),
)

LAND_SHAPES = (
    (AFRICA, (-20.0, 54.0, -39.0, 41.0)),
    (ARABIA, (30.0, 59.0, 9.0, 33.0)),
    (EURASIA, (-14.0, 172.0, 5.0, 80.0)),
    (SOUTH_AMERICA, (-86.0, -32.0, -60.0, 16.0)),
    (NORTH_AMERICA, (-172.0, -49.0, 11.0, 82.0)),
    (GREENLAND, (-76.0, -10.0, 56.0, 86.0)),
    (AUSTRALIA, (108.0, 157.0, -47.0, -7.0)),
    (MADAGASCAR, (41.0, 53.0, -30.0, -9.0)),
)

PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
UINT64_MASK = (1 << 64) - 1


def clamp(value: float, lower: float = 0.0, upper: float = 1.0) -> float:
    return max(lower, min(upper, value))


def smoothstep(lower: float, upper: float, value: float) -> float:
    normalized = clamp((value - lower) / (upper - lower))
    return normalized * normalized * (3.0 - 2.0 * normalized)


def mix(first: float, second: float, amount: float) -> float:
    return first + (second - first) * amount


def mix_color(
    first: tuple[float, float, float],
    second: tuple[float, float, float],
    amount: float,
) -> tuple[float, float, float]:
    return tuple(mix(a, b, amount) for a, b in zip(first, second))


def splitmix64(state: int) -> tuple[int, int]:
    next_state = (state + 0x9E3779B97F4A7C15) & UINT64_MASK
    value = next_state
    value = ((value ^ (value >> 30)) * 0xBF58476D1CE4E5B9) & UINT64_MASK
    value = ((value ^ (value >> 27)) * 0x94D049BB133111EB) & UINT64_MASK
    value ^= value >> 31
    return next_state, value


def next_unit_float(state: int) -> tuple[int, float]:
    state, value = splitmix64(state)
    return state, (value >> 11) * (1.0 / (1 << 53))


def make_waves(
    seed: int,
    octave_count: int,
    waves_per_octave: int,
    starting_frequency: float,
    persistence: float,
) -> list[tuple[float, float, float, float, float, float]]:
    state = seed & UINT64_MASK
    waves: list[tuple[float, float, float, float, float, float]] = []

    for octave in range(octave_count):
        for _ in range(waves_per_octave):
            state, vertical_unit = next_unit_float(state)
            state, azimuth_unit = next_unit_float(state)
            state, phase_unit = next_unit_float(state)
            state, frequency_unit = next_unit_float(state)
            state, amplitude_unit = next_unit_float(state)

            vertical = vertical_unit * 2.0 - 1.0
            azimuth = azimuth_unit * math.tau
            radial = math.sqrt(max(0.0, 1.0 - vertical * vertical))
            direction_x = radial * math.cos(azimuth)
            direction_z = radial * math.sin(azimuth)
            frequency = starting_frequency * (2.0 ** octave) * mix(0.86, 1.14, frequency_unit)
            amplitude = (persistence ** octave) * mix(0.72, 1.28, amplitude_unit)

            waves.append(
                (
                    direction_x,
                    vertical,
                    direction_z,
                    frequency,
                    phase_unit * math.tau,
                    amplitude,
                )
            )

    amplitude_sum = sum(wave[5] for wave in waves)
    return [(*wave[:5], wave[5] / amplitude_sum) for wave in waves]


def sample_waves(
    x: float,
    y: float,
    z: float,
    waves: list[tuple[float, float, float, float, float, float]],
) -> float:
    result = 0.0
    for direction_x, direction_y, direction_z, frequency, phase, amplitude in waves:
        projection = x * direction_x + y * direction_y + z * direction_z
        result += math.sin(projection * frequency + phase) * amplitude
    return result


def spherical_position(pixel_x: int, pixel_y: int) -> tuple[float, float, float, float, float]:
    longitude = ((pixel_x + 0.5) / TEXTURE_WIDTH - 0.5) * math.tau
    latitude = (0.5 - (pixel_y + 0.5) / TEXTURE_HEIGHT) * math.pi
    cosine_latitude = math.cos(latitude)
    return (
        cosine_latitude * math.cos(longitude),
        math.sin(latitude),
        cosine_latitude * math.sin(longitude),
        latitude,
        longitude,
    )


def point_is_inside_polygon(
    longitude: float,
    latitude: float,
    polygon: tuple[tuple[float, float], ...],
) -> bool:
    inside = False
    previous_longitude, previous_latitude = polygon[-1]

    for current_longitude, current_latitude in polygon:
        crosses_latitude = (current_latitude > latitude) != (previous_latitude > latitude)
        if crosses_latitude:
            crossing_longitude = (
                (previous_longitude - current_longitude)
                * (latitude - current_latitude)
                / (previous_latitude - current_latitude)
                + current_longitude
            )
            if longitude < crossing_longitude:
                inside = not inside
        previous_longitude = current_longitude
        previous_latitude = current_latitude

    return inside


def distance_to_polygon_edge(
    longitude: float,
    latitude: float,
    polygon: tuple[tuple[float, float], ...],
) -> float:
    longitude_scale = max(math.cos(math.radians(latitude)), 0.16)
    minimum_distance = math.inf
    previous_longitude, previous_latitude = polygon[-1]

    for current_longitude, current_latitude in polygon:
        start_x = (previous_longitude - longitude) * longitude_scale
        start_y = previous_latitude - latitude
        end_x = (current_longitude - longitude) * longitude_scale
        end_y = current_latitude - latitude
        edge_x = end_x - start_x
        edge_y = end_y - start_y
        edge_length_squared = edge_x * edge_x + edge_y * edge_y
        if edge_length_squared > 0.0:
            amount = clamp(
                -(start_x * edge_x + start_y * edge_y) / edge_length_squared
            )
            nearest_x = start_x + edge_x * amount
            nearest_y = start_y + edge_y * amount
        else:
            nearest_x = start_x
            nearest_y = start_y
        minimum_distance = min(
            minimum_distance,
            math.hypot(nearest_x, nearest_y),
        )
        previous_longitude = current_longitude
        previous_latitude = current_latitude

    return minimum_distance


def signed_distance_to_land_shape(
    longitude: float,
    latitude: float,
    polygon: tuple[tuple[float, float], ...],
    bounds: tuple[float, float, float, float],
) -> float:
    minimum_longitude, maximum_longitude, minimum_latitude, maximum_latitude = bounds
    margin = 18.0
    if (
        longitude < minimum_longitude - margin
        or longitude > maximum_longitude + margin
        or latitude < minimum_latitude - margin
        or latitude > maximum_latitude + margin
    ):
        longitude_distance = max(
            minimum_longitude - longitude,
            0.0,
            longitude - maximum_longitude,
        ) * max(math.cos(math.radians(latitude)), 0.16)
        latitude_distance = max(
            minimum_latitude - latitude,
            0.0,
            latitude - maximum_latitude,
        )
        return -math.hypot(longitude_distance, latitude_distance)

    distance = distance_to_polygon_edge(longitude, latitude, polygon)
    return distance if point_is_inside_polygon(longitude, latitude, polygon) else -distance


def authored_land_distance(longitude: float, latitude: float) -> float:
    distance = max(
        signed_distance_to_land_shape(
            shifted_longitude,
            latitude,
            polygon,
            bounds,
        )
        for polygon, bounds in LAND_SHAPES
        for shifted_longitude in (longitude - 360.0, longitude, longitude + 360.0)
    )
    antarctic_boundary = (
        -67.0
        + math.sin(math.radians(longitude * 3.0)) * 2.4
        + math.sin(math.radians(longitude * 7.0 + 35.0)) * 1.1
    )
    return max(distance, antarctic_boundary - latitude)


def elliptical_influence(
    longitude: float,
    latitude: float,
    center_longitude: float,
    center_latitude: float,
    longitude_radius: float,
    latitude_radius: float,
) -> float:
    longitude_delta = (
        (longitude - center_longitude + 180.0) % 360.0 - 180.0
    ) * max(
        math.cos(math.radians(center_latitude)),
        0.16,
    )
    distance = math.hypot(
        longitude_delta / longitude_radius,
        (latitude - center_latitude) / latitude_radius,
    )
    return 1.0 - smoothstep(0.35, 1.0, distance)


def authored_mountain_influence(longitude: float, latitude: float) -> float:
    return max(
        elliptical_influence(longitude, latitude, 37.0, 5.0, 5.0, 23.0),
        elliptical_influence(longitude, latitude, 4.0, 32.0, 15.0, 4.0),
        elliptical_influence(longitude, latitude, 78.0, 31.0, 25.0, 5.0),
        elliptical_influence(longitude, latitude, -72.0, -18.0, 5.0, 34.0),
        elliptical_influence(longitude, latitude, 148.0, -27.0, 5.0, 16.0),
    )


def generate_height_field() -> tuple[array, array, float, dict[str, float]]:
    coast_waves = make_waves(SEED ^ 0xC01A71E17, 4, 5, 9.0, 0.52)
    terrain_waves = make_waves(SEED ^ 0x7E22A1, 4, 4, 4.2, 0.50)
    ridge_waves = make_waves(SEED ^ 0xA11CE5, 3, 4, 11.0, 0.52)
    normalized_heights = array("f")
    encoded_heights = array("H")
    minimum_land_field = math.inf
    maximum_land_field = -math.inf

    for pixel_y in range(TEXTURE_HEIGHT):
        for pixel_x in range(TEXTURE_WIDTH):
            x, y, z, latitude, longitude = spherical_position(pixel_x, pixel_y)
            latitude_degrees = math.degrees(latitude)
            longitude_degrees = math.degrees(longitude)
            coast_detail = sample_waves(x, y, z, coast_waves) * 4.2
            land_field = authored_land_distance(
                longitude_degrees,
                latitude_degrees,
            ) + coast_detail - 2.0
            minimum_land_field = min(minimum_land_field, land_field)
            maximum_land_field = max(maximum_land_field, land_field)

            if land_field >= 0.0:
                interior = smoothstep(0.0, 18.0, land_field)
                terrain = clamp(0.5 + sample_waves(x, y, z, terrain_waves) * 1.8)
                ridge_signal = sample_waves(x, y, z, ridge_waves)
                ridge_detail = (1.0 - abs(ridge_signal)) ** 8.0
                mountain = authored_mountain_influence(
                    longitude_degrees,
                    latitude_degrees,
                ) * mix(0.42, 1.0, ridge_detail)
                height = clamp(
                    0.012
                    + interior * 0.17
                    + terrain * mix(0.025, 0.10, interior)
                    + mountain * 0.70
                )
                encoded = SEA_LEVEL_SAMPLE + round(height * (65535 - SEA_LEVEL_SAMPLE))
                normalized_heights.append(height)
            else:
                depth = clamp(-land_field / 58.0) ** 0.72
                encoded = SEA_LEVEL_SAMPLE - round(depth * SEA_LEVEL_SAMPLE)
                normalized_heights.append(-depth)
            encoded_heights.append(encoded)

    metrics = {
        "minimumRawElevation": minimum_land_field,
        "maximumRawElevation": maximum_land_field,
        "rawSeaLevel": 0.0,
    }
    return normalized_heights, encoded_heights, 0.0, metrics


def height_slope(normalized_heights: array, pixel_x: int, pixel_y: int, cosine_latitude: float) -> float:
    left_x = (pixel_x - 1) % TEXTURE_WIDTH
    right_x = (pixel_x + 1) % TEXTURE_WIDTH
    upper_y = max(0, pixel_y - 1)
    lower_y = min(TEXTURE_HEIGHT - 1, pixel_y + 1)
    row_offset = pixel_y * TEXTURE_WIDTH
    horizontal = (
        normalized_heights[row_offset + right_x] - normalized_heights[row_offset + left_x]
    ) / max(abs(cosine_latitude), 0.18)
    vertical = (
        normalized_heights[lower_y * TEXTURE_WIDTH + pixel_x]
        - normalized_heights[upper_y * TEXTURE_WIDTH + pixel_x]
    )
    return smoothstep(0.012, 0.12, math.hypot(horizontal, vertical))


def encode_byte(value: float) -> int:
    return round(clamp(value) * 255.0)


def append_color(pixels: bytearray, color: tuple[float, float, float], alpha: float) -> None:
    pixels.extend((encode_byte(color[0]), encode_byte(color[1]), encode_byte(color[2]), encode_byte(alpha)))


def authored_moisture_adjustment(longitude: float, latitude: float) -> float:
    congo = elliptical_influence(longitude, latitude, 22.0, 0.0, 18.0, 11.0)
    east_africa = elliptical_influence(longitude, latitude, 36.0, -7.0, 11.0, 18.0)
    sahara = elliptical_influence(longitude, latitude, 15.0, 23.0, 34.0, 12.0)
    arabia = elliptical_influence(longitude, latitude, 46.0, 24.0, 18.0, 10.0)
    kalahari = elliptical_influence(longitude, latitude, 22.0, -24.0, 13.0, 9.0)
    australian_interior = elliptical_influence(
        longitude,
        latitude,
        133.0,
        -25.0,
        19.0,
        13.0,
    )
    return (
        congo * 0.42
        + east_africa * 0.12
        - sahara * 0.62
        - arabia * 0.52
        - kalahari * 0.26
        - australian_interior * 0.34
    )


def cyclone_cloud_influence(
    longitude: float,
    latitude: float,
    center_longitude: float,
    center_latitude: float,
    rotation: float,
) -> float:
    longitude_delta = (
        (longitude - center_longitude + 180.0) % 360.0 - 180.0
    ) * max(
        math.cos(math.radians(center_latitude)),
        0.16,
    )
    latitude_delta = latitude - center_latitude
    radius = math.hypot(longitude_delta, latitude_delta)
    if radius > 27.0:
        return 0.0

    angle = math.atan2(latitude_delta, longitude_delta)
    spiral = 0.5 + 0.5 * math.sin(angle * 3.0 + radius * 0.58 * rotation)
    envelope = math.exp(-((radius - 13.0) / 9.5) ** 2)
    eye = smoothstep(2.2, 6.0, radius)
    return envelope * eye * smoothstep(0.42, 0.78, spiral)


def generate_surface_maps(normalized_heights: array) -> tuple[bytearray, bytearray, bytearray, dict[str, float]]:
    moisture_waves = make_waves(SEED ^ 0xB10A3, 4, 4, 2.8, 0.51)
    cloud_waves = make_waves(SEED ^ 0xC10D5, 5, 5, 4.0, 0.54)
    cloud_detail_waves = make_waves(SEED ^ 0xDE7A11, 3, 4, 24.0, 0.50)
    cloud_filament_waves = make_waves(SEED ^ 0xF11A6E, 2, 4, 58.0, 0.47)

    surface_pixels = bytearray()
    control_pixels = bytearray()
    cloud_pixels = bytearray()
    land_count = 0
    vegetation_count = 0
    ice_count = 0
    mountain_count = 0
    cloud_count = 0
    cloud_coverage_sum = 0.0
    dense_cloud_count = 0
    transitional_cloud_count = 0
    northern_strong_cloud_count = 0
    northern_cloud_sample_count = 0
    southern_strong_cloud_count = 0
    southern_cloud_sample_count = 0
    africa_region_land_count = 0
    africa_region_sample_count = 0
    antarctic_ice_count = 0
    antarctic_sample_count = 0
    surface_area_weight = 0.0

    for pixel_y in range(TEXTURE_HEIGHT):
        for pixel_x in range(TEXTURE_WIDTH):
            index = pixel_y * TEXTURE_WIDTH + pixel_x
            x, y, z, latitude, longitude = spherical_position(pixel_x, pixel_y)
            latitude_degrees = math.degrees(latitude)
            longitude_degrees = math.degrees(longitude)
            cosine_latitude = math.cos(latitude)
            area_weight = cosine_latitude
            surface_area_weight += area_weight
            normalized_height = normalized_heights[index]
            is_land = normalized_height >= 0.0
            land_height = max(0.0, normalized_height)
            ocean_depth = max(0.0, -normalized_height)
            slope = height_slope(normalized_heights, pixel_x, pixel_y, cosine_latitude)

            moisture_noise = sample_waves(x, y, z, moisture_waves)
            moisture = clamp(
                0.48
                + moisture_noise * 1.65
                + cosine_latitude * 0.06
                - slope * 0.15
                + authored_moisture_adjustment(
                    longitude_degrees,
                    latitude_degrees,
                )
            )
            temperature_noise = moisture_noise * 0.08 + math.sin(longitude * 3.0 + latitude * 2.0) * 0.025
            temperature = clamp((max(0.0, cosine_latitude) ** 0.62) + temperature_noise - land_height * 0.52)

            polar_cap = smoothstep(64.0, 78.0, abs(latitude_degrees))
            polar_ice = max(
                smoothstep(0.50, 0.20, temperature),
                polar_cap * 0.96,
            )
            mountain_snow = smoothstep(0.50, 0.21, temperature) * smoothstep(0.14, 0.55, land_height)
            ice = max(polar_ice, mountain_snow)
            temperate_gate = smoothstep(0.18, 0.42, temperature) * (1.0 - smoothstep(0.86, 1.0, temperature))
            vegetation = (
                smoothstep(0.24, 0.64, moisture)
                * temperate_gate
                * (1.0 - smoothstep(0.34, 0.78, land_height))
                * (1.0 - slope * 0.64)
                * (1.0 - ice)
                if is_land
                else 0.0
            )
            desert = (
                (1.0 - smoothstep(0.20, 0.52, moisture))
                * smoothstep(0.39, 0.70, temperature)
                * (1.0 - ice)
                if is_land
                else 0.0
            )

            if is_land:
                soil = (0.31, 0.21, 0.14)
                desert_color = (0.57, 0.40, 0.24)
                dry_grass = (0.32, 0.34, 0.20)
                forest = (0.07, 0.20, 0.10)
                rain_forest = (0.045, 0.25, 0.12)
                rock = (0.31, 0.29, 0.27)
                snow = (0.88, 0.91, 0.90)
                beach = (0.53, 0.46, 0.34)

                color = mix_color(soil, desert_color, desert)
                vegetation_color = mix_color(dry_grass, forest, smoothstep(0.28, 0.70, moisture))
                vegetation_color = mix_color(vegetation_color, rain_forest, smoothstep(0.70, 0.96, moisture))
                color = mix_color(color, vegetation_color, vegetation)
                rock_amount = max(slope * 0.72, smoothstep(0.38, 0.82, land_height)) * (1.0 - ice)
                color = mix_color(color, rock, rock_amount)
                color = mix_color(color, beach, (1.0 - smoothstep(0.008, 0.030, land_height)) * (1.0 - ice) * 0.55)
                color = mix_color(color, snow, ice)
                roughness = mix(0.83, 0.73, rock_amount)
                roughness = mix(roughness, 0.89, vegetation * 0.55 + desert * 0.25)
                roughness = mix(roughness, 0.48, ice)
                land_count += area_weight
            else:
                deep_ocean = (0.012, 0.055, 0.14)
                middle_ocean = (0.018, 0.14, 0.29)
                shallow_ocean = (0.035, 0.29, 0.38)
                shallow_amount = 1.0 - smoothstep(0.02, 0.48, ocean_depth)
                color = mix_color(deep_ocean, middle_ocean, 1.0 - ocean_depth)
                color = mix_color(color, shallow_ocean, shallow_amount * 0.68)
                color = mix_color(color, (0.77, 0.87, 0.90), ice)
                roughness = mix(0.16, 0.23, ocean_depth)
                roughness = mix(roughness, 0.39, ice)

            append_color(surface_pixels, color, 1.0 if is_land else 0.0)
            control_pixels.extend(
                (
                    encode_byte(moisture),
                    encode_byte(vegetation),
                    encode_byte(ice),
                    encode_byte(roughness),
                )
            )

            cloud_noise = sample_waves(x, y, z, cloud_waves)
            cloud_detail_noise = sample_waves(x, y, z, cloud_detail_waves)
            cloud_filament_noise = sample_waves(x, y, z, cloud_filament_waves)
            cloud_detail = clamp(
                0.50
                + cloud_detail_noise * 1.65
                + cloud_filament_noise * 0.65
            )
            latitude_band = math.sin(
                latitude * 9.0 + math.sin(longitude * 3.0) * 2.2
            ) * 0.055
            equatorial_band = math.exp(-(latitude_degrees / 9.0) ** 2) * 0.085
            southern_storm_belt = math.exp(
                -((latitude_degrees + 46.0) / 18.0) ** 2
            ) * 0.30
            cyclones = max(
                cyclone_cloud_influence(
                    longitude_degrees,
                    latitude_degrees,
                    -25.0,
                    -44.0,
                    1.0,
                ),
                cyclone_cloud_influence(
                    longitude_degrees,
                    latitude_degrees,
                    83.0,
                    -42.0,
                    -1.0,
                ),
            )
            cloud_source = clamp(
                0.425
                + cloud_noise * 1.70
                + cloud_detail_noise * 0.44
                + cloud_filament_noise * 0.22
                + latitude_band
                + equatorial_band
                + southern_storm_belt
                + cyclones * 0.45
            )
            cloud_coverage = smoothstep(0.36, 0.78, cloud_source)
            cloud_coverage *= mix(0.82, 1.0, max(0.0, cosine_latitude) ** 0.28)
            southern_bias = smoothstep(35.0, -45.0, latitude_degrees)
            cloud_coverage = clamp(
                cloud_coverage * mix(0.70, 1.35, southern_bias)
            )
            blue_marble_northern_clear = elliptical_influence(
                longitude_degrees,
                latitude_degrees,
                30.0,
                18.0,
                110.0,
                48.0,
            )
            cloud_coverage *= mix(
                1.0,
                0.55,
                blue_marble_northern_clear,
            )
            cloud_density = cloud_coverage * mix(0.42, 1.0, cloud_detail)
            cloud_pixels.extend(
                (
                    encode_byte(cloud_coverage),
                    encode_byte(cloud_density),
                    encode_byte(cloud_detail),
                    encode_byte(cloud_coverage),
                )
            )

            if vegetation > 0.35:
                vegetation_count += area_weight
            if ice > 0.50:
                ice_count += area_weight
            if is_land and (land_height > 0.44 or slope > 0.72):
                mountain_count += area_weight
            if cloud_coverage > 0.20:
                cloud_count += area_weight
            cloud_coverage_sum += cloud_coverage * area_weight
            if cloud_coverage > 0.80:
                dense_cloud_count += area_weight
            if 0.10 < cloud_coverage < 0.80:
                transitional_cloud_count += area_weight
            if latitude_degrees > 10.0:
                northern_cloud_sample_count += area_weight
                if cloud_coverage > 0.60:
                    northern_strong_cloud_count += area_weight
            elif latitude_degrees < -10.0:
                southern_cloud_sample_count += area_weight
                if cloud_coverage > 0.60:
                    southern_strong_cloud_count += area_weight
            if -20.0 <= longitude_degrees <= 55.0 and -38.0 <= latitude_degrees <= 38.0:
                africa_region_sample_count += area_weight
                if is_land:
                    africa_region_land_count += area_weight
            if latitude_degrees < -68.0:
                antarctic_sample_count += area_weight
                if ice > 0.75:
                    antarctic_ice_count += area_weight

    northern_strong_cloud_fraction = (
        northern_strong_cloud_count / northern_cloud_sample_count
    )
    southern_strong_cloud_fraction = (
        southern_strong_cloud_count / southern_cloud_sample_count
    )
    metrics = {
        "landFraction": land_count / surface_area_weight,
        "vegetatedFraction": vegetation_count / surface_area_weight,
        "iceFraction": ice_count / surface_area_weight,
        "mountainFraction": mountain_count / surface_area_weight,
        "cloudFraction": cloud_count / surface_area_weight,
        "meanCloudCoverage": cloud_coverage_sum / surface_area_weight,
        "denseCloudFraction": dense_cloud_count / surface_area_weight,
        "transitionalCloudFraction": transitional_cloud_count / surface_area_weight,
        "northernStrongCloudFraction": northern_strong_cloud_fraction,
        "southernStrongCloudFraction": southern_strong_cloud_fraction,
        "southernToNorthernStrongCloudRatio": (
            southern_strong_cloud_fraction
            / max(northern_strong_cloud_fraction, 1e-6)
        ),
        "africaRegionLandFraction": (
            africa_region_land_count / africa_region_sample_count
        ),
        "antarcticIceFraction": antarctic_ice_count / antarctic_sample_count,
    }
    return surface_pixels, control_pixels, cloud_pixels, metrics


def png_chunk(chunk_type: bytes, contents: bytes) -> bytes:
    checksum = zlib.crc32(chunk_type)
    checksum = zlib.crc32(contents, checksum) & 0xFFFFFFFF
    return struct.pack(">I", len(contents)) + chunk_type + contents + struct.pack(">I", checksum)


def make_png(
    width: int,
    height: int,
    bit_depth: int,
    color_type: int,
    pixels: bytes,
    bytes_per_row: int,
    channel_description: str,
    color_space: str,
) -> bytes:
    expected_byte_count = height * bytes_per_row
    if len(pixels) != expected_byte_count:
        raise RuntimeError(f"PNG pixel data has {len(pixels)} bytes; expected {expected_byte_count}.")

    scanlines = bytearray()
    for row in range(height):
        start = row * bytes_per_row
        scanlines.append(0)
        scanlines.extend(pixels[start : start + bytes_per_row])

    header = struct.pack(">IIBBBBB", width, height, bit_depth, color_type, 0, 0, 0)
    chunks = [png_chunk(b"IHDR", header)]
    if color_space == "sRGB":
        chunks.append(png_chunk(b"sRGB", b"\x00"))
        chunks.append(png_chunk(b"gAMA", struct.pack(">I", 45455)))
    chunks.extend(
        (
            png_chunk(b"tEXt", b"Engine2Channels\x00" + channel_description.encode("latin-1")),
            png_chunk(b"tEXt", b"Engine2ColorSpace\x00" + color_space.encode("ascii")),
            png_chunk(b"tEXt", b"Engine2Seed\x00" + str(SEED).encode("ascii")),
            png_chunk(b"IDAT", zlib.compress(bytes(scanlines), level=9)),
            png_chunk(b"IEND", b""),
        )
    )
    return PNG_SIGNATURE + b"".join(chunks)


def make_elevation_bytes(encoded_heights: array) -> bytes:
    pixels = bytearray()
    for value in encoded_heights:
        pixels.extend(((value >> 8) & 0xFF, value & 0xFF))
    return bytes(pixels)


def format_scalar(value: float) -> str:
    if abs(value) < 5e-10:
        value = 0.0
    return format(value, ".9g")


def sphere_points() -> object:
    for vertical_index in range(VERTICAL_SEGMENTS + 1):
        latitude = math.pi * (0.5 - vertical_index / VERTICAL_SEGMENTS)
        cosine_latitude = math.cos(latitude)
        for radial_index in range(RADIAL_SEGMENTS + 1):
            longitude = math.tau * (radial_index / RADIAL_SEGMENTS - 0.5)
            yield "({}, {}, {})".format(
                format_scalar(cosine_latitude * math.cos(longitude)),
                format_scalar(math.sin(latitude)),
                format_scalar(cosine_latitude * math.sin(longitude)),
            )


def sphere_texture_coordinates() -> object:
    for vertical_index in range(VERTICAL_SEGMENTS + 1):
        texture_v = 1.0 - vertical_index / VERTICAL_SEGMENTS
        for radial_index in range(RADIAL_SEGMENTS + 1):
            texture_u = radial_index / RADIAL_SEGMENTS
            yield f"({format_scalar(texture_u)}, {format_scalar(texture_v)})"


def sphere_face_indices() -> object:
    row_width = RADIAL_SEGMENTS + 1
    for vertical_index in range(VERTICAL_SEGMENTS):
        for radial_index in range(RADIAL_SEGMENTS):
            upper_left = vertical_index * row_width + radial_index
            upper_right = upper_left + 1
            lower_left = upper_left + row_width
            lower_right = lower_left + 1
            yield str(upper_left)
            yield str(upper_right)
            yield str(lower_left)
            yield str(upper_right)
            yield str(lower_right)
            yield str(lower_left)


def repeated_face_counts() -> object:
    for _ in range(RADIAL_SEGMENTS * VERTICAL_SEGMENTS * 2):
        yield "3"


def write_usda_array(
    file,
    declaration: str,
    values: object,
    indentation: str,
    values_per_line: int,
    closing_suffix: str = "",
) -> None:
    file.write(f"{indentation}{declaration} = [\n")
    line: list[str] = []
    for value in values:
        line.append(value)
        if len(line) == values_per_line:
            file.write(f"{indentation}    {', '.join(line)},\n")
            line = []
    if line:
        file.write(f"{indentation}    {', '.join(line)}\n")
    file.write(f"{indentation}]{closing_suffix}\n")


def write_sphere_usda(path: Path) -> None:
    triangle_count = RADIAL_SEGMENTS * VERTICAL_SEGMENTS * 2
    with path.open("w", encoding="utf-8", newline="\n") as file:
        file.write(
            "#usda 1.0\n"
            "# Unit UV sphere generated by Tools/PlanetAssetGenerator.\n"
            "(\n"
            "    customLayerData = {\n"
            '        string creator = "Engine2 deterministic Planet Asset Generator"\n'
            f"        int engine2GeneratorVersion = {GENERATOR_VERSION}\n"
            f"        int engine2RadialSegments = {RADIAL_SEGMENTS}\n"
            f"        int engine2Seed = {SEED}\n"
            f"        int engine2TriangleCount = {triangle_count}\n"
            f"        int engine2VerticalSegments = {VERTICAL_SEGMENTS}\n"
            "    }\n"
            '    defaultPrim = "TerrestrialPlanet"\n'
            "    metersPerUnit = 1\n"
            '    upAxis = "Y"\n'
            ")\n\n"
            'def Xform "TerrestrialPlanet" (\n'
            "    assetInfo = {\n"
            '        string name = "TerrestrialPlanet"\n'
            "    }\n"
            '    kind = "component"\n'
            ")\n"
            "{\n"
            '    def Mesh "Mesh" (\n'
            '        prepend apiSchemas = ["MaterialBindingAPI"]\n'
            "    )\n"
            "    {\n"
            "        float3[] extent = [(-1, -1, -1), (1, 1, 1)]\n"
        )
        write_usda_array(file, "int[] faceVertexCounts", repeated_face_counts(), "        ", 32)
        write_usda_array(file, "int[] faceVertexIndices", sphere_face_indices(), "        ", 18)
        file.write('        rel material:binding = </TerrestrialPlanet/Materials/Default>\n')
        write_usda_array(file, "normal3f[] normals", sphere_points(), "        ", 3, " (")
        file.write('            interpolation = "vertex"\n        )\n')
        write_usda_array(file, "point3f[] points", sphere_points(), "        ", 3)
        write_usda_array(file, "texCoord2f[] primvars:st", sphere_texture_coordinates(), "        ", 4, " (")
        file.write(
            '            interpolation = "vertex"\n        )\n'
            '        uniform token subdivisionScheme = "none"\n'
            "    }\n\n"
            '    def Scope "Materials"\n'
            "    {\n"
            '        def Material "Default"\n'
            "        {\n"
            "            token outputs:surface.connect = "
            "</TerrestrialPlanet/Materials/Default/surfaceShader.outputs:surface>\n\n"
            '            def Shader "surfaceShader"\n'
            "            {\n"
            '                uniform token info:id = "UsdPreviewSurface"\n'
            "                token outputs:surface\n"
            "            }\n"
            "        }\n"
            "    }\n"
            "}\n"
        )


def write_aligned_usdz(usda_path: Path, usdz_path: Path) -> None:
    contents = usda_path.read_bytes()
    archive_name = usda_path.name
    archive_name_bytes = archive_name.encode("ascii")

    with zipfile.ZipFile(usdz_path, "w", compression=zipfile.ZIP_STORED, allowZip64=True) as archive:
        info = zipfile.ZipInfo(archive_name, date_time=(1980, 1, 1, 0, 0, 0))
        info.compress_type = zipfile.ZIP_STORED
        info.create_system = 0
        base_data_offset = 30 + len(archive_name_bytes)
        padding_length = (-(base_data_offset + 4)) % 64
        info.extra = struct.pack("<HH", 0x1986, padding_length) + bytes(padding_length)
        archive.writestr(info, contents)


def file_record(path: Path) -> dict[str, object]:
    contents = path.read_bytes()
    return {
        "byteCount": len(contents),
        "sha256": hashlib.sha256(contents).hexdigest(),
    }


def pixel_component(
    pixels: bytes,
    pixel_offset: int,
    channel: int,
    bytes_per_channel: int,
) -> int:
    component_offset = pixel_offset + channel * bytes_per_channel
    if bytes_per_channel == 1:
        return pixels[component_offset]
    return int.from_bytes(pixels[component_offset : component_offset + bytes_per_channel], "big")


def raw_seam_ratio(
    pixels: bytes,
    width: int,
    height: int,
    channel_count: int,
    bytes_per_channel: int = 1,
) -> float:
    seam_difference = 0
    interior_difference = 0
    seam_sample_count = 0
    interior_sample_count = 0
    bytes_per_pixel = channel_count * bytes_per_channel
    bytes_per_row = width * bytes_per_pixel

    for row in range(height):
        row_offset = row * bytes_per_row
        first_offset = row_offset
        last_offset = row_offset + (width - 1) * bytes_per_pixel
        for channel in range(channel_count):
            seam_difference += abs(
                pixel_component(pixels, first_offset, channel, bytes_per_channel)
                - pixel_component(pixels, last_offset, channel, bytes_per_channel)
            )
            seam_sample_count += 1
        for column in range(0, width - 1, 17):
            first = row_offset + column * bytes_per_pixel
            second = first + bytes_per_pixel
            for channel in range(channel_count):
                interior_difference += abs(
                    pixel_component(pixels, first, channel, bytes_per_channel)
                    - pixel_component(pixels, second, channel, bytes_per_channel)
                )
                interior_sample_count += 1

    seam_average = seam_difference / seam_sample_count
    interior_average = interior_difference / interior_sample_count
    return seam_average / max(interior_average, 1.0)


def validate_metrics(metrics: dict[str, float]) -> None:
    requirements = {
        "landFraction": (0.27, 0.31),
        "vegetatedFraction": (0.025, 0.20),
        "iceFraction": (0.02, 0.12),
        "mountainFraction": (0.005, 0.12),
        "cloudFraction": (0.30, 0.60),
        "meanCloudCoverage": (0.25, 0.44),
        "denseCloudFraction": (0.10, 0.35),
        "transitionalCloudFraction": (0.18, 0.50),
        "northernStrongCloudFraction": (0.06, 0.48),
        "southernStrongCloudFraction": (0.22, 0.60),
        "southernToNorthernStrongCloudRatio": (2.00, 8.00),
        "africaRegionLandFraction": (0.35, 0.65),
        "antarcticIceFraction": (0.50, 1.0),
    }
    for name, (minimum, maximum) in requirements.items():
        value = metrics[name]
        if not minimum <= value <= maximum:
            raise RuntimeError(f"{name} is {value:.6f}; expected {minimum:.3f}...{maximum:.3f}.")


def generate_assets(output_directory: Path, report: bool = True) -> None:
    output_directory.mkdir(parents=True, exist_ok=True)
    normalized_heights, encoded_heights, _, elevation_metrics = generate_height_field()
    surface_pixels, control_pixels, cloud_pixels, content_metrics = generate_surface_maps(normalized_heights)
    validate_metrics(content_metrics)

    elevation_pixels = make_elevation_bytes(encoded_heights)
    elevation_png = make_png(
        TEXTURE_WIDTH,
        TEXTURE_HEIGHT,
        16,
        0,
        elevation_pixels,
        TEXTURE_WIDTH * 2,
        "R=unsigned elevation; 32768 is sea level",
        "linear",
    )
    surface_png = make_png(
        TEXTURE_WIDTH,
        TEXTURE_HEIGHT,
        8,
        6,
        surface_pixels,
        TEXTURE_WIDTH * 4,
        "RGB=sRGB surface color; A=binary land mask",
        "sRGB",
    )
    control_png = make_png(
        TEXTURE_WIDTH,
        TEXTURE_HEIGHT,
        8,
        6,
        control_pixels,
        TEXTURE_WIDTH * 4,
        "R=moisture; G=vegetation; B=ice; A=perceptual roughness",
        "linear",
    )
    clouds_png = make_png(
        TEXTURE_WIDTH,
        TEXTURE_HEIGHT,
        8,
        6,
        cloud_pixels,
        TEXTURE_WIDTH * 4,
        "R=coverage; G=density; B=detail; A=coverage",
        "linear",
    )

    (output_directory / ELEVATION_NAME).write_bytes(elevation_png)
    (output_directory / SURFACE_NAME).write_bytes(surface_png)
    (output_directory / CONTROL_NAME).write_bytes(control_png)
    (output_directory / CLOUDS_NAME).write_bytes(clouds_png)
    write_sphere_usda(output_directory / USDA_NAME)
    write_aligned_usdz(output_directory / USDA_NAME, output_directory / USDZ_NAME)

    seam_ratios = {
        "elevation": raw_seam_ratio(elevation_pixels, TEXTURE_WIDTH, TEXTURE_HEIGHT, 1, 2),
        "surface": raw_seam_ratio(surface_pixels, TEXTURE_WIDTH, TEXTURE_HEIGHT, 4),
        "control": raw_seam_ratio(control_pixels, TEXTURE_WIDTH, TEXTURE_HEIGHT, 4),
        "clouds": raw_seam_ratio(cloud_pixels, TEXTURE_WIDTH, TEXTURE_HEIGHT, 4),
    }
    for name, ratio in seam_ratios.items():
        if ratio > 4.0:
            raise RuntimeError(f"{name} longitude seam ratio is {ratio:.3f}; expected at most 4.0.")

    files = {name: file_record(output_directory / name) for name in ASSET_NAMES}
    manifest = {
        "schemaVersion": 2,
        "generatorVersion": GENERATOR_VERSION,
        "seed": SEED,
        "visualTarget": {
            "name": "Apollo 17 Blue Marble",
            "photoID": "AS17-148-22727",
            "presentation": "iconic processed square crop",
            "sourceURL": "https://eol.jsc.nasa.gov/SearchPhotos/photo.pl?mission=AS17&roll=148&frame=22727",
            "usage": "art direction only; no source pixels or map data consumed",
        },
        "texture": {
            "width": TEXTURE_WIDTH,
            "height": TEXTURE_HEIGHT,
            "projection": "equirectangular",
            "longitudeSampling": "periodic pixel centers",
        },
        "elevation": {
            "bitDepth": 16,
            "seaLevelSample": SEA_LEVEL_SAMPLE,
            "minimumSample": min(encoded_heights),
            "maximumSample": max(encoded_heights),
        },
        "surfaceChannels": {
            "R": "sRGB red",
            "G": "sRGB green",
            "B": "sRGB blue",
            "A": "binary land mask",
        },
        "controlChannels": {
            "R": "moisture",
            "G": "vegetation",
            "B": "ice and snow",
            "A": "perceptual roughness",
        },
        "cloudChannels": {
            "R": "coverage",
            "G": "density",
            "B": "detail",
            "A": "coverage",
        },
        "mesh": {
            "radialSegments": RADIAL_SEGMENTS,
            "verticalSegments": VERTICAL_SEGMENTS,
            "vertexCount": (RADIAL_SEGMENTS + 1) * (VERTICAL_SEGMENTS + 1),
            "triangleCount": RADIAL_SEGMENTS * VERTICAL_SEGMENTS * 2,
            "radius": 1.0,
        },
        "metrics": {
            "surfaceFractionWeighting": "cosine latitude",
            **elevation_metrics,
            **content_metrics,
            "longitudeSeamRatio": seam_ratios,
        },
        "files": files,
    }
    manifest_path = output_directory / MANIFEST_NAME
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    if report:
        print(f"Generated terrestrial planet assets in {output_directory}")
        for name in GENERATED_NAMES:
            record = file_record(output_directory / name)
            print(f"{record['sha256']}  {name}  ({record['byteCount']} bytes)")
        print("Content metrics:")
        for name, value in content_metrics.items():
            print(f"  {name}: {value:.6f}")
        print("Longitude seam ratios:")
        for name, value in seam_ratios.items():
            print(f"  {name}: {value:.3f}")


def inspect_png(path: Path) -> dict[str, object]:
    contents = path.read_bytes()
    if not contents.startswith(PNG_SIGNATURE):
        raise RuntimeError(f"{path.name} does not have a PNG signature.")

    offset = len(PNG_SIGNATURE)
    header = None
    compressed_data = bytearray()
    while offset < len(contents):
        if offset + 12 > len(contents):
            raise RuntimeError(f"{path.name} has a truncated PNG chunk.")
        length = struct.unpack(">I", contents[offset : offset + 4])[0]
        chunk_type = contents[offset + 4 : offset + 8]
        chunk_data = contents[offset + 8 : offset + 8 + length]
        checksum = struct.unpack(">I", contents[offset + 8 + length : offset + 12 + length])[0]
        actual_checksum = zlib.crc32(chunk_type)
        actual_checksum = zlib.crc32(chunk_data, actual_checksum) & 0xFFFFFFFF
        if checksum != actual_checksum:
            raise RuntimeError(f"{path.name} has an invalid {chunk_type.decode('ascii')} checksum.")
        if chunk_type == b"IHDR":
            header = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"IDAT":
            compressed_data.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
        offset += 12 + length

    if header is None:
        raise RuntimeError(f"{path.name} has no IHDR chunk.")
    width, height, bit_depth, color_type, compression, filter_method, interlace = header
    if compression != 0 or filter_method != 0 or interlace != 0:
        raise RuntimeError(f"{path.name} uses an unsupported PNG encoding.")
    is_elevation = (bit_depth, color_type) == (16, 0)
    channel_count = 1 if is_elevation else 4
    bytes_per_channel = 2 if is_elevation else 1
    bytes_per_pixel = channel_count * bytes_per_channel
    decompressed = zlib.decompress(bytes(compressed_data))
    bytes_per_row = width * bytes_per_pixel
    expected_length = height * (bytes_per_row + 1)
    if len(decompressed) != expected_length:
        raise RuntimeError(f"{path.name} has {len(decompressed)} decoded bytes; expected {expected_length}.")

    pixels = bytearray()
    for row in range(height):
        row_offset = row * (bytes_per_row + 1)
        if decompressed[row_offset] != 0:
            raise RuntimeError(f"{path.name} row {row} does not use PNG filter 0.")
        pixels.extend(decompressed[row_offset + 1 : row_offset + 1 + bytes_per_row])
    return {
        "width": width,
        "height": height,
        "bitDepth": bit_depth,
        "colorType": color_type,
        "channelCount": channel_count,
        "bytesPerChannel": bytes_per_channel,
        "pixels": bytes(pixels),
    }


def check_assets(output_directory: Path) -> None:
    manifest_path = output_directory / MANIFEST_NAME
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest["schemaVersion"] != 2:
        raise RuntimeError("The manifest does not use schema version 2.")
    if manifest["generatorVersion"] != GENERATOR_VERSION or manifest["seed"] != SEED:
        raise RuntimeError("The manifest does not match this generator version and seed.")

    for name, expected in manifest["files"].items():
        actual = file_record(output_directory / name)
        if actual != expected:
            raise RuntimeError(f"{name} does not match its manifest size and SHA-256 digest.")

    expected_png_formats = {
        ELEVATION_NAME: (16, 0),
        SURFACE_NAME: (8, 6),
        CONTROL_NAME: (8, 6),
        CLOUDS_NAME: (8, 6),
    }
    for name, expected_format in expected_png_formats.items():
        inspected = inspect_png(output_directory / name)
        actual_format = (inspected["bitDepth"], inspected["colorType"])
        if inspected["width"] != TEXTURE_WIDTH or inspected["height"] != TEXTURE_HEIGHT:
            raise RuntimeError(f"{name} does not have the required {TEXTURE_WIDTH}x{TEXTURE_HEIGHT} dimensions.")
        if actual_format != expected_format:
            raise RuntimeError(f"{name} has PNG format {actual_format}; expected {expected_format}.")
        seam_ratio = raw_seam_ratio(
            inspected["pixels"],
            TEXTURE_WIDTH,
            TEXTURE_HEIGHT,
            inspected["channelCount"],
            inspected["bytesPerChannel"],
        )
        if seam_ratio > 4.0:
            raise RuntimeError(f"{name} longitude seam ratio is {seam_ratio:.3f}; expected at most 4.0.")

    usda_path = output_directory / USDA_NAME
    with zipfile.ZipFile(output_directory / USDZ_NAME) as archive:
        if archive.namelist() != [USDA_NAME]:
            raise RuntimeError(f"{USDZ_NAME} must contain only {USDA_NAME}.")
        info = archive.getinfo(USDA_NAME)
        data_offset = info.header_offset + 30 + len(info.filename.encode("ascii")) + len(info.extra)
        if data_offset % 64 != 0:
            raise RuntimeError(f"{USDZ_NAME} payload starts at byte {data_offset}; USDZ requires 64-byte alignment.")
        if info.compress_type != zipfile.ZIP_STORED:
            raise RuntimeError(f"{USDZ_NAME} must store its USD layer without compression.")
        if archive.read(USDA_NAME) != usda_path.read_bytes():
            raise RuntimeError(f"{USDZ_NAME} does not contain the checked-in {USDA_NAME} bytes.")

    validate_metrics(manifest["metrics"])

    with tempfile.TemporaryDirectory(prefix="engine2-planet-assets-") as temporary_directory:
        regenerated_directory = Path(temporary_directory)
        generate_assets(regenerated_directory, report=False)
        for name in GENERATED_NAMES:
            checked_in = (output_directory / name).read_bytes()
            regenerated = (regenerated_directory / name).read_bytes()
            if checked_in != regenerated:
                raise RuntimeError(f"{name} does not match a fresh deterministic generation.")

    print(f"Validated {len(GENERATED_NAMES)} generated files in {output_directory}")
    for name, record in manifest["files"].items():
        print(f"{record['sha256']}  {name}  ({record['byteCount']} bytes)")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-directory",
        type=Path,
        default=DEFAULT_OUTPUT_DIRECTORY,
        help=f"Asset output directory. Default: {DEFAULT_OUTPUT_DIRECTORY}",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate the existing generated assets without changing them.",
    )
    return parser.parse_args()


def main() -> int:
    arguments = parse_arguments()
    try:
        if arguments.check:
            check_assets(arguments.output_directory)
        else:
            generate_assets(arguments.output_directory)
    except (KeyError, OSError, RuntimeError, ValueError, zipfile.BadZipFile, zlib.error) as error:
        print(f"Planet asset generation failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
