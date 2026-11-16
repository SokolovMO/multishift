#!/usr/bin/env python3
"""Package the shared native monochrome icon renderer into MultiShift's ICNS."""
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]

def main():
    cache = Path(os.environ.get("MULTISHIFT_BUILD_CACHE_DIR", str(ROOT / "build")))
    output = Path(os.environ.get("MULTISHIFT_ICON_OUTPUT", str(ROOT / "dragshift/assets/multishift.icns")))
    cache.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    renderer = cache / "render-app-icon"
    env = dict(os.environ, DEVELOPER_DIR=os.environ.get("DEVELOPER_DIR", "/Applications/Xcode.app/Contents/Developer"))
    subprocess.run(["xcrun", "swiftc", "-swift-version", "6", "-module-cache-path", str(cache / "icon-module-cache"),
                    str(ROOT / "macos/Sources/Core/MultiInterfaceMetrics.swift"),
                    str(ROOT / "macos/Sources/MultiDesignKit.swift"), str(ROOT / "macos/generate_icon.swift"),
                    "-o", str(renderer)], env=env, check=True)
    subprocess.run([str(renderer), str(cache), str(output)], env=env, check=True)
    print(f"Generated {output}")

if __name__ == "__main__":
    main()
