#!/usr/bin/env python3
"""Render a cached native Stadium arena for converter/debugging review."""

from __future__ import annotations

import argparse
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image

NATIVE_SCALE = 0.100


def read_u16(data: bytes, offset: int) -> int:
    return struct.unpack_from(">H", data, offset)[0]


def decode_texture(fmt: int, size: int, width: int, height: int, raw: bytes) -> np.ndarray:
    if not raw:
        return np.full((height, width, 4), 255, dtype=np.uint8)
    out = np.empty((height * width, 4), dtype=np.uint8)
    for pixel in range(width * height):
        if fmt == 0 and size == 2:
            packed = read_u16(raw, pixel * 2)
            out[pixel] = (
                ((packed >> 11) & 31) * 255 // 31,
                ((packed >> 6) & 31) * 255 // 31,
                ((packed >> 1) & 31) * 255 // 31,
                255 if packed & 1 else 0,
            )
        elif fmt == 0 and size == 3:
            out[pixel] = tuple(raw[pixel * 4 : pixel * 4 + 4])
        elif fmt == 3 and size == 0:
            packed = raw[pixel // 2]
            nibble = packed >> 4 if pixel % 2 == 0 else packed & 15
            out[pixel] = ((nibble >> 1) * 255 // 7,) * 3 + (255 if nibble & 1 else 0,)
        elif fmt == 3 and size == 1:
            packed = raw[pixel]
            out[pixel] = ((packed >> 4) * 17,) * 3 + ((packed & 15) * 17,)
        elif fmt == 3 and size == 2:
            intensity, alpha = raw[pixel * 2 : pixel * 2 + 2]
            out[pixel] = (intensity, intensity, intensity, alpha)
        elif fmt == 4 and size == 0:
            packed = raw[pixel // 2]
            intensity = (packed >> 4 if pixel % 2 == 0 else packed & 15) * 17
            out[pixel] = (intensity, intensity, intensity, 255)
        elif fmt == 4 and size == 1:
            intensity = raw[pixel]
            out[pixel] = (intensity, intensity, intensity, 255)
        else:
            raise ValueError(f"unsupported texture format {fmt}/{size}")
    return out.reshape((height, width, 4))


def load_groups(path: Path) -> list[dict]:
    data = path.read_bytes()
    if data[:4] != b"SNA2":
        raise ValueError("not a Stadium native arena cache")
    count, cursor = read_u16(data, 4), 6
    groups = []
    textures: dict[int, np.ndarray] = {}
    for _ in range(count):
        material, fmt, size, width, height, tex_bytes, vertex_count, index_count = struct.unpack_from(
            ">hBBHHIII", data, cursor
        )
        rgba = np.frombuffer(data[cursor + 20 : cursor + 24], dtype=np.uint8).astype(np.float32) / 255.0
        layer = data[cursor + 24]
        cursor += 28
        texture_raw = data[cursor : cursor + tex_bytes]
        cursor += tex_bytes
        vertex_raw = data[cursor : cursor + vertex_count * 16]
        cursor += vertex_count * 16
        vertices = np.empty((vertex_count, 6), dtype=np.float64)
        for index in range(vertex_count):
            at = index * 16
            x, y, z, s, t = struct.unpack_from(">hhhxxhh", vertex_raw, at)
            vertices[index] = (x, y, z, s / (32 * width), t / (32 * height), 1)
        indices = np.frombuffer(data[cursor : cursor + index_count * 2], dtype=">u2").astype(np.int32) - 1
        cursor += index_count * 2
        texture = textures.get(material)
        if texture is None:
            texture = decode_texture(fmt, size, width, height, texture_raw)
            textures[material] = texture
        groups.append({"vertices": vertices, "indices": indices, "texture": texture,
                       "tint": rgba, "layer": layer})
    return groups


def normalize(value: np.ndarray) -> np.ndarray:
    return value / max(np.linalg.norm(value), 1e-9)


def render(groups: list[dict], output: Path, width: int, height: int, complete: bool) -> None:
    eye = np.array((41.98, 28.48, 41.16), dtype=np.float64)
    focus = np.array((-3.24, -1.35, 0.0), dtype=np.float64)
    forward = normalize(focus - eye)
    right = normalize(np.cross(forward, np.array((0.0, 1.0, 0.0))))
    up = np.cross(right, forward)
    camera = np.stack((right, up, forward))
    fov = 2 * math.atan((55.62 / 2) / np.linalg.norm(focus - eye))
    focal = height / (2 * math.tan(fov / 2))

    canvas = np.zeros((height, width, 4), dtype=np.uint8)
    canvas[..., 3] = 255
    depth = np.full((height, width), np.inf, dtype=np.float64)

    for group in groups:
        vertices = group["vertices"].copy()
        x, z = vertices[:, 0].copy(), vertices[:, 2].copy()
        vertices[:, 0] = z * NATIVE_SCALE
        vertices[:, 1] *= NATIVE_SCALE
        vertices[:, 2] = -x * NATIVE_SCALE
        max_xz = np.max(np.abs(vertices[:, (0, 2)])) / NATIVE_SCALE
        min_y = np.min(vertices[:, 1]) / NATIVE_SCALE
        max_y = np.max(vertices[:, 1]) / NATIVE_SCALE
        old_hidden = max_xz > 2800 or min_y < -100 or (
            1800 < max_xz < 2800 and min_y > 350 and max_y > 1000
        )
        if not complete and old_hidden:
            continue

        positions = (camera @ (vertices[:, :3] - eye).T).T
        if np.all(positions[:, 2] <= 0.1):
            continue
        projected = np.column_stack((
            width / 2 + positions[:, 0] * focal / positions[:, 2],
            height / 2 - positions[:, 1] * focal / positions[:, 2],
        ))
        texture = group["texture"]
        tex_h, tex_w = texture.shape[:2]
        tint = group["tint"]
        indices = group["indices"]
        for tri in indices.reshape((-1, 3)):
            p = projected[tri]
            zc = positions[tri, 2]
            if np.any(zc <= 0.1):
                continue
            xmin = max(0, int(math.floor(np.min(p[:, 0]))))
            xmax = min(width - 1, int(math.ceil(np.max(p[:, 0]))))
            ymin = max(0, int(math.floor(np.min(p[:, 1]))))
            ymax = min(height - 1, int(math.ceil(np.max(p[:, 1]))))
            if xmin > xmax or ymin > ymax:
                continue
            denom = ((p[1, 1] - p[2, 1]) * (p[0, 0] - p[2, 0])
                     + (p[2, 0] - p[1, 0]) * (p[0, 1] - p[2, 1]))
            if abs(denom) < 1e-8:
                continue
            yy, xx = np.mgrid[ymin : ymax + 1, xmin : xmax + 1]
            w0 = ((p[1, 1] - p[2, 1]) * (xx - p[2, 0])
                  + (p[2, 0] - p[1, 0]) * (yy - p[2, 1])) / denom
            w1 = ((p[2, 1] - p[0, 1]) * (xx - p[2, 0])
                  + (p[0, 0] - p[2, 0]) * (yy - p[2, 1])) / denom
            w2 = 1 - w0 - w1
            inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
            invz = w0 / zc[0] + w1 / zc[1] + w2 / zc[2]
            fragment_depth = 1 / np.maximum(invz, 1e-9)
            target_depth = depth[ymin : ymax + 1, xmin : xmax + 1]
            visible = inside & (fragment_depth < target_depth)
            if not np.any(visible):
                continue
            uv = vertices[tri, 3:5]
            u = (w0 * uv[0, 0] / zc[0] + w1 * uv[1, 0] / zc[1]
                 + w2 * uv[2, 0] / zc[2]) / invz
            v = (w0 * uv[0, 1] / zc[0] + w1 * uv[1, 1] / zc[1]
                 + w2 * uv[2, 1] / zc[2]) / invz
            tx = np.mod(np.floor(u * tex_w).astype(np.int64), tex_w)
            ty = np.mod(np.floor(v * tex_h).astype(np.int64), tex_h)
            sampled = texture[ty, tx].astype(np.float32)
            sampled = np.clip(sampled * tint * 0.92, 0, 255).astype(np.uint8)
            alpha_visible = visible & (sampled[..., 3] > 8)
            canvas_region = canvas[ymin : ymax + 1, xmin : xmax + 1]
            canvas_region[alpha_visible] = sampled[alpha_visible]
            target_depth[alpha_visible] = fragment_depth[alpha_visible]

    output.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(canvas, "RGBA").save(output)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("cache", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--width", type=int, default=1280)
    parser.add_argument("--height", type=int, default=720)
    parser.add_argument("--legacy-clean-room", action="store_true")
    args = parser.parse_args()
    render(load_groups(args.cache), args.output, args.width, args.height,
           complete=not args.legacy_clean_room)
    print(f"rendered {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
