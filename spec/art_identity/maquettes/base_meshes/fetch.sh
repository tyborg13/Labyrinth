#!/bin/sh
# Re-download and verify the CC0 Blender Human Base Meshes bundle into the local cache (see PROVENANCE.md).
set -e
D="$HOME/.cache/labyrinth/blender_human_base_meshes_v1.4.1"; Z="$D/human-base-meshes-bundle-v1.4.1.zip"
mkdir -p "$D"
[ -f "$Z" ] || curl -fsSL -o "$Z" https://mirror.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip
echo "811f43accbb31a88266d932f8f5563b2d13586fca0ba2693aad1f5fe582b3515  $Z" | shasum -a 256 -c -
[ -d "$D/extracted" ] || unzip -q "$Z" -d "$D/extracted"
echo "$D/extracted/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend"
