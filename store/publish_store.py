#!/usr/bin/env python3
"""Publish App Store Connect listing data: metadata, release notes, screenshots.

The app binary is uploaded separately (CI / `xcrun altool`). This script handles
everything else on the App Store side, talking to the App Store Connect REST API
directly — no Fastlane.

Sources of truth:
    store/store_metadata.yaml   standing listing (description, keywords, subtitle, …)
    store/release_notes.yaml    per-version "What's New", keyed by version → language
    screenshots/final/<lang>/<device>/*.png

Usage:
    uv run --with "pyjwt[crypto]" --with requests --with pyyaml \
        store/publish_store.py [--metadata] [--notes] [--screenshots] [--dry-run]

With no section flag, all three run. --dry-run reads everything and reports the
changes it *would* make without writing anything.

Credentials (env, matching the CI workflow's secrets):
    ASC_KEY_ID        App Store Connect API key id (e.g. RQJSZ643B2)
    ASC_ISSUER_ID     issuer id (UUID)
    ASC_API_KEY_P8    the .p8 private key contents (optional; see key lookup below)
The private key is found, in order: $ASC_API_KEY_P8 (raw contents) →
--key <path> → ~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8.

This script is conservative: it only updates locales and the app-store version that
already exist in App Store Connect. It never creates a locale or version — those are
deliberate one-time actions you do in the web UI. Anything in the YAML without a
matching target is reported and skipped, not invented.
"""

import argparse
import hashlib
import os
import sys
import time
from pathlib import Path

import jwt
import requests
import yaml

ASC_BASE = "https://api.appstoreconnect.apple.com"
SCRIPT_DIR = Path(__file__).parent
PROJECT_DIR = SCRIPT_DIR.parent

BUNDLE_ID = "com.lexaway.app"

# Short code (our YAML keys) → canonical App Store Connect locale. Matching is
# by exact locale or language prefix, and a short code's text is applied to
# EVERY ASC locale of that language (en → en-US, en-GB, en-AU, en-CA, …).
LOCALE_MAP = {
    "en": "en-US",
    "de": "de-DE",
    "es": "es-ES",
    "fr": "fr-FR",
    "it": "it",
    "pt": "pt-BR",
    "nl": "nl-NL",
}

# Screenshot device folder → App Store display type. Android folders are skipped.
DISPLAY_TYPES = {
    "iPhone_16_Plus": "APP_IPHONE_67",     # 6.7"
    "iPhone_11_Pro_Max": "APP_IPHONE_65",  # 6.5"
}

# App Store version states we're allowed to edit metadata on.
EDITABLE_STATES = {
    "PREPARE_FOR_SUBMISSION",
    "METADATA_REJECTED",
    "DEVELOPER_REJECTED",
    "REJECTED",
    "INVALID_BINARY",
}

# Fields we write to an appStoreVersionLocalization for the standing metadata.
# (subtitle lives on appInfoLocalization, handled separately.)
VERSION_LOC_FIELDS = {
    "description": "description",
    "keywords": "keywords",
    "promotional_text": "promotionalText",
}


def log(msg):
    print(msg, flush=True)


# --------------------------------------------------------------------------- #
# Auth + thin API client
# --------------------------------------------------------------------------- #
def load_private_key(key_id, key_arg):
    raw = os.environ.get("ASC_API_KEY_P8")
    if raw:
        return raw
    candidates = []
    if key_arg:
        candidates.append(Path(key_arg))
    candidates.append(Path.home() / ".appstoreconnect" / "private_keys" / f"AuthKey_{key_id}.p8")
    for p in candidates:
        if p and p.exists():
            return p.read_text()
    sys.exit(
        "Could not find the App Store Connect private key.\n"
        "Set $ASC_API_KEY_P8, pass --key <path>, or place it at "
        f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"
    )


def make_token(key_id, issuer_id, key_pem):
    now = int(time.time())
    payload = {"iss": issuer_id, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, key_pem, algorithm="ES256",
                      headers={"alg": "ES256", "kid": key_id, "typ": "JWT"})


class ASC:
    def __init__(self, token, dry_run):
        self.s = requests.Session()
        self.s.headers["Authorization"] = f"Bearer {token}"
        self.dry_run = dry_run

    def _check(self, r):
        if not r.ok:
            sys.exit(f"ASC API {r.status_code} {r.request.method} {r.request.url}\n{r.text}")
        return r

    def get(self, path, **params):
        return self._check(self.s.get(ASC_BASE + path, params=params)).json()

    def get_all(self, path, **params):
        """Follow pagination, returning the concatenated `data` list."""
        out, url = [], ASC_BASE + path
        first = True
        while url:
            r = self._check(self.s.get(url, params=params if first else None)).json()
            out.extend(r.get("data", []))
            url = r.get("links", {}).get("next")
            first = False
        return out

    def patch(self, path, payload, what):
        if self.dry_run:
            log(f"    [dry-run] PATCH {path} :: {what}")
            return None
        return self._check(self.s.patch(ASC_BASE + path, json=payload)).json()

    def post(self, path, payload, what):
        if self.dry_run:
            log(f"    [dry-run] POST {path} :: {what}")
            return None
        return self._check(self.s.post(ASC_BASE + path, json=payload)).json()

    def delete(self, path, what):
        if self.dry_run:
            log(f"    [dry-run] DELETE {path} :: {what}")
            return None
        return self._check(self.s.delete(ASC_BASE + path))


# --------------------------------------------------------------------------- #
# Resolution helpers
# --------------------------------------------------------------------------- #
def normalize_version(v):
    """Compare versions tolerantly: '1.10' == '1.10.0', '1.2' == '1.2.0.0'.

    App Store Connect and our YAML disagree on whether to write the trailing
    '.0' (Apple has both '1.10' and '1.4.0'), so match on the numeric tuple with
    trailing zeros stripped.
    """
    parts = [int(p) for p in v.strip().split(".")]
    while len(parts) > 1 and parts[-1] == 0:
        parts.pop()
    return tuple(parts)


def read_pubspec_version():
    for line in (PROJECT_DIR / "pubspec.yaml").read_text().splitlines():
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip().split("+", 1)[0]
    sys.exit("No version: found in pubspec.yaml")


def resolve_app(asc):
    data = asc.get_all("/v1/apps", **{"filter[bundleId]": BUNDLE_ID})
    if not data:
        sys.exit(f"No app found for bundle id {BUNDLE_ID}")
    return data[0]["id"]


def resolve_version(asc, app_id, version, skip_if_missing=False):
    versions = asc.get_all(f"/v1/apps/{app_id}/appStoreVersions",
                           **{"filter[platform]": "IOS"})
    target = normalize_version(version)
    match = [v for v in versions
             if normalize_version(v["attributes"]["versionString"]) == target]
    if match:
        v = match[0]
        state = v["attributes"]["appStoreState"]
        if state not in EDITABLE_STATES:
            log(f"  ! version {version} is in state {state} (not editable) — "
                "metadata may be rejected")
        return v["id"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in EDITABLE_STATES]
    if editable:
        v = editable[0]
        log(f"  ! no version {version} in App Store Connect; using editable version "
            f"{v['attributes']['versionString']} ({v['attributes']['appStoreState']})")
        return v["id"]
    existing = ", ".join(f"{v['attributes']['versionString']} "
                         f"({v['attributes']['appStoreState']})" for v in versions) or "none"
    msg = (f"No editable App Store version found (looked for {version}).\n"
           f"  Existing versions: {existing}\n"
           "  Metadata can only be pushed to a version in an editable state "
           "(e.g. PREPARE_FOR_SUBMISSION). Create the next version in App Store "
           "Connect first, then re-run.")
    if skip_if_missing:
        log("  ! " + msg.replace("\n", "\n  "))
        log("  Skipping listing publish (--skip-if-no-version).")
        return None
    sys.exit(msg)


def short_for_locale(locale):
    """Map an ASC locale back to our short YAML key (en-US → en, pt-BR → pt)."""
    prefix = locale.split("-")[0].lower()
    for short, full in LOCALE_MAP.items():
        if full == locale or short == prefix:
            return short
    return None


def version_localizations(asc, version_id):
    """Return {short_code: [localization_dict, ...]} for the version.

    A language can exist under several ASC locales (en-US, en-GB, en-AU, …);
    the text for a short code applies to all of them.
    """
    locs = asc.get_all(f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations")
    out = {}
    for loc in locs:
        short = short_for_locale(loc["attributes"]["locale"])
        if short:
            out.setdefault(short, []).append(loc)
    return out


def appinfo_localizations(asc, app_id):
    """Return {short_code: [localization_dict, ...]} for the editable appInfo."""
    infos = asc.get_all(f"/v1/apps/{app_id}/appInfos")
    info = next((i for i in infos
                 if i["attributes"].get("appStoreState") in EDITABLE_STATES), infos[0])
    locs = asc.get_all(f"/v1/appInfos/{info['id']}/appInfoLocalizations")
    out = {}
    for loc in locs:
        short = short_for_locale(loc["attributes"]["locale"])
        if short:
            out.setdefault(short, []).append(loc)
    return out


def patch_if_changed(asc, kind, loc, wanted, label):
    """PATCH a localization only with attributes that actually differ."""
    attrs = loc["attributes"]
    changed = {k: v for k, v in wanted.items() if (attrs.get(k) or "") != (v or "")}
    if not changed:
        log(f"    {label}: up to date")
        return
    log(f"    {label}: updating {', '.join(sorted(changed))}")
    asc.patch(f"/v1/{kind}/{loc['id']}",
              {"data": {"type": kind, "id": loc["id"], "attributes": changed}},
              what=f"{label} {sorted(changed)}")


# --------------------------------------------------------------------------- #
# Sections
# --------------------------------------------------------------------------- #
def push_metadata(asc, app_id, version_id, meta):
    log("Metadata (description, keywords, promo, URLs, subtitle):")
    shared = {"marketingUrl": meta.get("marketing_url"),
              "supportUrl": meta.get("support_url")}
    shared = {k: v for k, v in shared.items() if v}

    vlocs = version_localizations(asc, version_id)
    ailocs = appinfo_localizations(asc, app_id)

    for short, block in meta.items():
        if not isinstance(block, dict):  # skip top-level shared scalars
            continue
        # Version localization: description / keywords / promotionalText / URLs
        if short in vlocs:
            wanted = {api: block[y] for y, api in VERSION_LOC_FIELDS.items() if y in block}
            wanted.update(shared)
            for loc in vlocs[short]:
                patch_if_changed(asc, "appStoreVersionLocalizations", loc, wanted,
                                 f"{loc['attributes']['locale']} listing")
        else:
            log(f"    {short}: no version localization in ASC — skipped")
        # App-info localization: subtitle
        if "subtitle" in block:
            if short in ailocs:
                for loc in ailocs[short]:
                    patch_if_changed(asc, "appInfoLocalizations", loc,
                                     {"subtitle": block["subtitle"]},
                                     f"{loc['attributes']['locale']} subtitle")
            else:
                log(f"    {short}: no appInfo localization in ASC — subtitle skipped")


def push_notes(asc, version_id, notes, version):
    log(f'Release notes ("What\'s New") for {version}:')
    target = normalize_version(version)
    entry = next((v for k, v in notes.items() if normalize_version(k) == target), None)
    if not entry:
        log(f"  ! no release_notes.yaml entry for {version} — nothing to push")
        return
    vlocs = version_localizations(asc, version_id)
    for short, text in entry.items():
        if short in vlocs:
            for loc in vlocs[short]:
                patch_if_changed(asc, "appStoreVersionLocalizations", loc,
                                 {"whatsNew": text},
                                 f"{loc['attributes']['locale']} whatsNew")
        else:
            log(f"    {short}: no version localization in ASC — skipped")


def screenshot_set(asc, loc_id, display_type):
    """Find or create the appScreenshotSet for a localization + display type."""
    sets = asc.get_all(f"/v1/appStoreVersionLocalizations/{loc_id}/appScreenshotSets")
    for s in sets:
        if s["attributes"]["screenshotDisplayType"] == display_type:
            return s["id"]
    created = asc.post("/v1/appScreenshotSets", {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {"appStoreVersionLocalization": {
                "data": {"type": "appStoreVersionLocalizations", "id": loc_id}}},
        }
    }, what=f"create set {display_type}")
    return created["data"]["id"] if created else f"<new {display_type}>"


def upload_screenshot(asc, set_id, png):
    data = png.read_bytes()
    reserved = asc.post("/v1/appScreenshots", {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileName": png.name, "fileSize": len(data)},
            "relationships": {"appScreenshotSet": {
                "data": {"type": "appScreenshotSets", "id": set_id}}},
        }
    }, what=f"reserve {png.name}")
    if asc.dry_run or not reserved:
        return
    shot = reserved["data"]
    for op in shot["attributes"]["uploadOperations"]:
        headers = {h["name"]: h["value"] for h in op.get("requestHeaders", [])}
        chunk = data[op["offset"]:op["offset"] + op["length"]]
        r = asc.s.request(op["method"], op["url"], headers=headers, data=chunk)
        asc._check(r)
    asc._check(asc.s.patch(f"{ASC_BASE}/v1/appScreenshots/{shot['id']}", json={
        "data": {"type": "appScreenshots", "id": shot["id"],
                 "attributes": {"uploaded": True,
                                "sourceFileChecksum": hashlib.md5(data).hexdigest()}}
    }))


def push_screenshots(asc, version_id):
    log("Screenshots:")
    vlocs = version_localizations(asc, version_id)
    root = PROJECT_DIR / "screenshots" / "final"
    for short, locales in sorted(vlocs.items()):
        lang_dir = root / short
        if not lang_dir.is_dir():
            log(f"    {short}: no screenshots/final/{short} — skipped")
            continue
        for device_dir in sorted(lang_dir.iterdir()):
            if not device_dir.is_dir():
                continue
            display = DISPLAY_TYPES.get(device_dir.name)
            if not display:
                continue  # Android / unmapped device
            pngs = sorted(device_dir.glob("*.png"))
            if not pngs:
                continue
            for loc in locales:
                locale = loc["attributes"]["locale"]
                log(f"    {locale}/{device_dir.name} → {display}: {len(pngs)} shots")
                set_id = screenshot_set(asc, loc["id"], display)
                # Clear the set first so re-runs stay idempotent (no piling up).
                for existing in asc.get_all(f"/v1/appScreenshotSets/{set_id}/appScreenshots") \
                        if not str(set_id).startswith("<new") else []:
                    asc.delete(f"/v1/appScreenshots/{existing['id']}", what="clear old shot")
                for png in pngs:
                    log(f"        {png.name}")
                    upload_screenshot(asc, set_id, png)


# --------------------------------------------------------------------------- #
def main():
    ap = argparse.ArgumentParser(description="Publish App Store Connect listing data.")
    ap.add_argument("--metadata", action="store_true", help="push standing metadata")
    ap.add_argument("--notes", action="store_true", help="push release notes")
    ap.add_argument("--screenshots", action="store_true", help="upload screenshots")
    ap.add_argument("--dry-run", action="store_true", help="report changes, write nothing")
    ap.add_argument("--version", help="override version (default: from pubspec.yaml)")
    ap.add_argument("--key", help="path to AuthKey_<id>.p8")
    ap.add_argument("--skip-if-no-version", action="store_true",
                    help="exit 0 (warn, don't fail) when no editable App Store version "
                         "exists — for CI where a version may not be prepped yet")
    args = ap.parse_args()

    do_all = not (args.metadata or args.notes or args.screenshots)
    do_meta = do_all or args.metadata
    do_notes = do_all or args.notes
    do_shots = do_all or args.screenshots

    key_id = os.environ.get("ASC_KEY_ID")
    issuer_id = os.environ.get("ASC_ISSUER_ID")
    if not key_id or not issuer_id:
        sys.exit("Set ASC_KEY_ID and ASC_ISSUER_ID (see store/publish_store.py docstring).")

    key_pem = load_private_key(key_id, args.key)
    asc = ASC(make_token(key_id, issuer_id, key_pem), args.dry_run)

    version = args.version or read_pubspec_version()
    log(f"{'DRY RUN — ' if args.dry_run else ''}Publishing listing for version {version}\n")

    app_id = resolve_app(asc)
    version_id = resolve_version(asc, app_id, version, skip_if_missing=args.skip_if_no_version)
    if version_id is None:
        log("\nNothing published (no editable version).")
        return

    if do_meta:
        meta = yaml.safe_load((SCRIPT_DIR / "store_metadata.yaml").read_text())
        push_metadata(asc, app_id, version_id, meta)
    if do_notes:
        notes = yaml.safe_load((SCRIPT_DIR / "release_notes.yaml").read_text())
        push_notes(asc, version_id, notes, version)
    if do_shots:
        push_screenshots(asc, version_id)

    log("\nDone." + (" (dry run — nothing was written)" if args.dry_run else ""))


if __name__ == "__main__":
    main()
