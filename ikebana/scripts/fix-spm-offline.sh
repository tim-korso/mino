#!/bin/bash
PKG_SWIFT="ios/App/CapApp-SPM/Package.swift"
if [ -f "$PKG_SWIFT" ]; then
  sed -i '' 's|.package(url: "https://github.com/ionic-team/capacitor-swift-pm.git", exact: "8.4.0")|.package(path: "../../../.local-packages/capacitor-swift-pm")|' "$PKG_SWIFT"
  echo "[fix-spm] Package.swift → local path"
fi
