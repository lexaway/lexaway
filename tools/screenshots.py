"""Capture and compose marketing screenshots for iOS and Android.

Usage:
    uv run --with pyyaml tools/screenshots.py [options]

Handles iOS simulators and Android emulators, with proper YAML/JSON parsing.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import yaml

SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent
CONFIG_PATH = SCRIPT_DIR / "screenshot_config.yaml"


def load_config():
    with open(CONFIG_PATH) as f:
        return yaml.safe_load(f)


def _find_android_home() -> Path | None:
    """Resolve ANDROID_HOME / ANDROID_SDK_ROOT, or guess the default location."""
    for var in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        val = os.environ.get(var)
        if val and Path(val).is_dir():
            return Path(val)
    # macOS default
    default = Path.home() / "Library" / "Android" / "sdk"
    if default.is_dir():
        return default
    return None


def _android_sdk_tool(name: str) -> str:
    """Return the full path to an Android SDK CLI tool, or fall back to bare name."""
    home = _find_android_home()
    if home is None:
        return name
    candidates = {
        "emulator": home / "emulator" / "emulator",
        "adb": home / "platform-tools" / "adb",
        "sdkmanager": home / "cmdline-tools" / "latest" / "bin" / "sdkmanager",
        "avdmanager": home / "cmdline-tools" / "latest" / "bin" / "avdmanager",
    }
    path = candidates.get(name)
    if path and path.exists():
        return str(path)
    return name


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    """Run a command, printing it for visibility."""
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, check=True, **kwargs)


def run_quiet(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, **kwargs)


# ---------------------------------------------------------------------------
# iOS simulators
# ---------------------------------------------------------------------------

def ios_find_or_create_simulator(name: str, sim_type: str, runtime: str) -> str:
    """Return UDID of an existing or newly-created iOS simulator."""
    result = run_quiet(["xcrun", "simctl", "list", "devices", "-j"])
    data = json.loads(result.stdout)

    for _runtime_id, devices in data["devices"].items():
        for d in devices:
            if d["name"] == name and d.get("isAvailable", False):
                print(f"  Found existing simulator: {d['udid']}")
                return d["udid"]

    print(f"  Creating simulator {name}...")
    result = run_quiet(["xcrun", "simctl", "create", name, sim_type, runtime])
    udid = result.stdout.strip()
    print(f"  Created: {udid}")
    return udid


def ios_boot_simulator(udid: str):
    """Boot an iOS simulator if it isn't already booted."""
    result = run_quiet(["xcrun", "simctl", "list", "devices", "-j"])
    data = json.loads(result.stdout)

    for _runtime_id, devices in data["devices"].items():
        for d in devices:
            if d["udid"] == udid and d["state"] == "Booted":
                print("  Already booted")
                return

    print("  Booting...")
    run(["xcrun", "simctl", "boot", udid])
    run(["xcrun", "simctl", "bootstatus", udid, "-b"])


def ios_shutdown_simulator(udid: str):
    run_quiet(["xcrun", "simctl", "shutdown", udid])


def ios_capture(devices: list[dict], languages: list[str]):
    """Capture screenshots on iOS simulators."""
    for lang in languages:
        print(f"\n=== Language: {lang} ===")
        for device in devices:
            name = device["name"]
            print(f"\n--- {name} ---")

            udid = ios_find_or_create_simulator(
                name, device["simulator_type"], device["runtime"],
            )
            ios_boot_simulator(udid)

            print(f"  Running integration test ({lang})...")
            run(
                [
                    "flutter", "drive",
                    "--driver=test_driver/integration_test.dart",
                    "--target=integration_test/screenshot_test.dart",
                    f"--dart-define=SCREENSHOT_LANG={lang}",
                    "-d", udid,
                    "--no-pub",
                ],
                cwd=str(PROJECT_DIR),
                env={
                    **dict(__import__("os").environ),
                    "SCREENSHOT_DEVICE_NAME": name,
                    "SCREENSHOT_LANG": lang,
                },
            )

            ios_shutdown_simulator(udid)
            print(f"  Done: screenshots/raw/{lang}/{name}/")


# ---------------------------------------------------------------------------
# Android emulators
# ---------------------------------------------------------------------------

def android_avd_exists(avd_name: str) -> bool:
    result = run_quiet([_android_sdk_tool("emulator"), "-list-avds"])
    return avd_name in result.stdout.strip().splitlines()


def android_create_avd(avd_name: str, package: str):
    """Create an Android AVD. Installs the system image if needed."""
    print(f"  Installing system image {package}...")
    run([_android_sdk_tool("sdkmanager"), "--install", package])

    print(f"  Creating AVD {avd_name}...")
    run(
        [_android_sdk_tool("avdmanager"), "create", "avd", "-n", avd_name,
         "-k", package, "-d", "pixel_9", "--force"],
        input=b"no\n",
    )


def android_boot_emulator(avd_name: str) -> str:
    """Boot an Android emulator and return its serial (e.g. emulator-5554)."""
    adb = _android_sdk_tool("adb")

    # Check if already running
    result = run_quiet([adb, "devices"])
    for line in result.stdout.strip().splitlines()[1:]:
        if line.strip() and "emulator" in line and "device" in line:
            serial = line.split()[0]
            # Check if this is our AVD
            name_result = run_quiet([adb, "-s", serial, "emu", "avd", "name"])
            if avd_name in name_result.stdout:
                print(f"  Already running: {serial}")
                return serial

    print(f"  Starting emulator {avd_name}...")
    subprocess.Popen(
        [_android_sdk_tool("emulator"), "-avd", avd_name, "-no-audio", "-no-window"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )

    # Wait for device to come online
    print("  Waiting for device...")
    run([adb, "wait-for-device"])

    # Wait for boot to complete
    for _ in range(60):
        result = run_quiet([adb, "shell", "getprop", "sys.boot_completed"])
        if result.stdout.strip() == "1":
            break
        time.sleep(2)
    else:
        print("  Warning: boot timeout — continuing anyway")

    # Find the serial
    result = run_quiet([adb, "devices"])
    for line in result.stdout.strip().splitlines()[1:]:
        if "emulator" in line and "device" in line:
            return line.split()[0]

    raise RuntimeError("Could not find booted emulator")


def android_shutdown_emulator(serial: str):
    run_quiet([_android_sdk_tool("adb"), "-s", serial, "emu", "kill"])


ANDROID_SCREENSHOT_DIR = "/sdcard/Download/lexaway_screenshots"


def android_capture(devices: list[dict], languages: list[str]):
    """Capture screenshots on Android emulators.

    Uses `flutter test` (not `flutter drive`) so the native integration_test
    plugin is loaded — required for convertFlutterSurfaceToImage on Android.
    The test writes PNGs to device storage; we adb pull them afterwards.
    """
    for lang in languages:
        print(f"\n=== Language: {lang} ===")
        for device in devices:
            avd_name = device["name"]
            print(f"\n--- {avd_name} ---")

            if not android_avd_exists(avd_name):
                android_create_avd(avd_name, device["system_image"])

            serial = android_boot_emulator(avd_name)
            adb = _android_sdk_tool("adb")

            # Clear any previous screenshots on device
            run_quiet([adb, "-s", serial, "shell", "rm", "-rf", ANDROID_SCREENSHOT_DIR])

            print(f"  Running integration test ({lang})...")
            run(
                [
                    "flutter", "test",
                    "integration_test/screenshot_test.dart",
                    f"--dart-define=SCREENSHOT_LANG={lang}",
                    "-d", serial,
                ],
                cwd=str(PROJECT_DIR),
            )

            # Pull screenshots from device to host
            raw_dir = PROJECT_DIR / "screenshots" / "raw" / lang / avd_name
            raw_dir.mkdir(parents=True, exist_ok=True)
            print(f"  Pulling screenshots to {raw_dir}...")
            run([adb, "-s", serial, "pull", f"{ANDROID_SCREENSHOT_DIR}/{lang}/.", str(raw_dir)])

            # Clean up device storage
            run_quiet([adb, "-s", serial, "shell", "rm", "-rf", ANDROID_SCREENSHOT_DIR])

            android_shutdown_emulator(serial)
            print(f"  Done: screenshots/raw/{lang}/{avd_name}/")


# ---------------------------------------------------------------------------
# Compose step (delegates to compose.py)
# ---------------------------------------------------------------------------

def compose(lang_filter: str | None):
    """Run compose.py to overlay scrims and captions on raw screenshots."""
    cmd = [
        "uv", "run", "--with", "pillow", "--with", "pyyaml",
        str(SCRIPT_DIR / "compose.py"),
    ]
    if lang_filter:
        cmd += ["--lang", lang_filter]
    run(cmd, cwd=str(PROJECT_DIR))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Capture and compose marketing screenshots",
    )
    parser.add_argument(
        "--platform", choices=["ios", "android", "all"], default="all",
        help="Which platform to capture (default: all)",
    )
    parser.add_argument("--capture-only", action="store_true")
    parser.add_argument("--compose-only", action="store_true")
    parser.add_argument("--device", help="Filter to a single device name")
    parser.add_argument("--lang", help="Filter to a single language code")
    args = parser.parse_args()

    config = load_config()
    languages = [args.lang] if args.lang else config["languages"]

    do_capture = not args.compose_only
    do_compose = not args.capture_only

    # --- Capture ---
    if do_capture:
        print("==> Capturing screenshots")

        ios_devices = config.get("ios_devices", config.get("devices", []))
        android_devices = config.get("android_devices", [])

        if args.device:
            ios_devices = [d for d in ios_devices if d["name"] == args.device]
            android_devices = [d for d in android_devices if d["name"] == args.device]

        if args.platform in ("ios", "all") and ios_devices:
            print("\n==> iOS")
            ios_capture(ios_devices, languages)

        if args.platform in ("android", "all") and android_devices:
            print("\n==> Android")
            android_capture(android_devices, languages)

    # --- Compose ---
    if do_compose:
        print("\n==> Composing marketing assets")
        compose(args.lang)

    print("\n==> All done!")


if __name__ == "__main__":
    main()
