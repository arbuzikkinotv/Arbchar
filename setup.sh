#!/bin/bash
# Setup script for Arbchar ready project.
# Usage: run this from a machine with Flutter installed.
# It will create a flutter project named 'arbchar' (if missing) and overwrite files with the provided template.
set -e
if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter CLI not found. Install Flutter and ensure 'flutter' is in PATH."
  exit 1
fi
# create project if not exists
if [ ! -d "arbchar" ]; then
  flutter create arbchar
fi
# copy template files into project
cp -r template/lib ./arbchar/
cp template/pubspec.yaml ./arbchar/
cp template/README.md ./arbchar/
echo "Template files copied into ./arbchar. Now run:"
echo "  cd arbchar"
echo "  flutter pub get"
echo "  flutter run   # for testing on device"
echo "  flutter build apk --release   # to build release APK"
