#!/usr/bin/env bash
set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tools_dir="$project_dir/tools"
build_dir="$project_dir/build/announcer-builder-macos"
dist_dir="$project_dir/dist/announcer-builder-macos"
app_name="StadiumBattleFX-Announcer-Builder"
python_bin="${ANNOUNCER_BUILDER_PYTHON:-python3}"
requested_arch="${ANNOUNCER_BUILDER_MACOS_ARCH:-$(uname -m)}"
host_arch="$(uname -m)"

if [[ "$requested_arch" != "$host_arch" ]]; then
  printf 'Requested architecture %s does not match runner %s.\n' \
    "$requested_arch" "$host_arch" >&2
  exit 2
fi
if [[ "$requested_arch" != "arm64" && "$requested_arch" != "x86_64" ]]; then
  printf 'Unsupported macOS architecture: %s\n' "$requested_arch" >&2
  exit 2
fi

decoder="$build_dir/native/mort_decoder"
archive_name="StadiumBattleFX-Announcer-Builder-macos-${requested_arch}.zip"
stage_dir="$project_dir/build/StadiumBattleFX-Announcer-Builder-macos-${requested_arch}"

rm -rf "$build_dir" "$dist_dir" "$stage_dir"
mkdir -p "$(dirname "$decoder")" "$dist_dir" "$stage_dir"

clang++ \
  -std=c++17 \
  -O2 \
  -DNDEBUG \
  -arch "$requested_arch" \
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
  --add-binary "$decoder:." \
  --distpath "$dist_dir" \
  --workpath "$build_dir/pyinstaller" \
  --specpath "$build_dir/pyinstaller" \
  "$tools_dir/announcer_builder_gui.py"

app="$dist_dir/$app_name.app"
test -d "$app"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"

cp -R "$app" "$stage_dir/"
install -m 0644 "$tools_dir/ANNOUNCER_BUILDER_MACOS_README.txt" \
  "$stage_dir/README.txt"

archive="$project_dir/dist/$archive_name"
rm -f "$archive" "$archive.sha256"
ditto -c -k --sequesterRsrc --keepParent "$stage_dir" "$archive"
(
  cd "$project_dir/dist"
  shasum -a 256 "$archive_name" > "$archive_name.sha256"
)

printf 'Built %s\n' "$archive"
cat "$archive.sha256"
