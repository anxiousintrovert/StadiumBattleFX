#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_dir="$project_dir/tools"
build_dir="$project_dir/build/announcer-builder-linux"
dist_dir="$project_dir/dist/announcer-builder-linux"
app_name="StadiumBattleFX-Announcer-Builder"
archive_name="StadiumBattleFX-Announcer-Builder-steamos-x86_64.tar.gz"
python_bin="${ANNOUNCER_BUILDER_PYTHON:-python3}"
decoder="$build_dir/native/mort_decoder"

"$python_bin" -c 'from lupa.luajit21 import LuaRuntime' || {
  printf 'The builder environment needs lupa (python3 -m pip install lupa).\n' >&2
  exit 1
}

rm -rf "$build_dir" "$dist_dir"
mkdir -p "$(dirname "$decoder")" "$dist_dir"

g++ \
  -std=c++17 \
  -O2 \
  -DNDEBUG \
  -march=x86-64 \
  -mtune=generic \
  -o "$decoder" \
  "$tools_dir/mort_decoder/main.cpp" \
  "$tools_dir/mort_decoder/MORTDecoder.cpp"

"$python_bin" -m PyInstaller \
  --noconfirm \
  --clean \
  --onedir \
  --noupx \
  --windowed \
  --name "$app_name" \
  --paths "$tools_dir" \
  --hidden-import "lupa.luajit21" \
  --add-binary "$decoder:." \
  --add-data "$tools_dir/build_stadium_cache.lua:." \
  --distpath "$dist_dir" \
  --workpath "$build_dir/pyinstaller" \
  --specpath "$build_dir/pyinstaller" \
  "$tools_dir/announcer_builder_gui.py"

install -m 0644 "$tools_dir/ANNOUNCER_BUILDER_LINUX_README.txt" \
  "$dist_dir/$app_name/README.txt"

archive="$project_dir/dist/$archive_name"
rm -f "$archive" "$archive.sha256"
tar \
  --sort=name \
  --mtime='UTC 1980-01-01' \
  --owner=0 \
  --group=0 \
  --numeric-owner \
  -C "$dist_dir" \
  -cf - "$app_name" | gzip -n -9 > "$archive"

(
  cd "$project_dir/dist"
  sha256sum "$archive_name" > "$archive_name.sha256"
)

printf 'Built %s\n' "$archive"
cat "$archive.sha256"
