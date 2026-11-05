#!/usr/bin/env python3
"""Switches the Release configurations of the app and the Live Activity
extension in ios/Runner.xcodeproj to manual signing with the given profiles.

Used by .github/workflows/ios-release.yml on the CI runner only; the committed
project keeps automatic signing for local and sideload builds.

    ios_release_signing.py <team id> <app profile name> <extension profile name>
"""
import re
import sys

PROJECT = "ios/Runner.xcodeproj/project.pbxproj"
APP_ID = "io.github.valijuu.retrail"
EXTENSION_ID = "io.github.valijuu.retrail.RideActivity"

# One XCBuildConfiguration named Release, up to its closing brace.
BLOCK = re.compile(
    r"(\t\t[0-9A-F]{24} /\* Release \*/ = \{\n\t\t\tisa = XCBuildConfiguration;"
    r".*?\n\t\t\};)",
    re.DOTALL,
)


def patch(block: str, team: str, profiles: dict) -> str:
    match = re.search(r"PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);", block)
    if match is None or match.group(1) not in profiles:
        return block
    block = re.sub(r"\t\t\t\tCODE_SIGN_STYLE = Automatic;\n", "", block)
    signing = (
        "\t\t\t\tCODE_SIGN_STYLE = Manual;\n"
        f"\t\t\t\tDEVELOPMENT_TEAM = {team};\n"
        '\t\t\t\tCODE_SIGN_IDENTITY = "Apple Distribution";\n'
        '\t\t\t\t"CODE_SIGN_IDENTITY[sdk=iphoneos*]" = "Apple Distribution";\n'
        f'\t\t\t\tPROVISIONING_PROFILE_SPECIFIER = "{profiles[match.group(1)]}";\n'
    )
    return block.replace("buildSettings = {\n", "buildSettings = {\n" + signing, 1)


def main() -> None:
    team, app_profile, extension_profile = sys.argv[1:4]
    profiles = {APP_ID: app_profile, EXTENSION_ID: extension_profile}
    with open(PROJECT, encoding="utf-8") as handle:
        text = handle.read()
    patched = BLOCK.sub(lambda m: patch(m.group(1), team, profiles), text)
    if patched.count("CODE_SIGN_STYLE = Manual;") != 2:
        sys.exit("expected to switch exactly two Release configurations to manual signing")
    with open(PROJECT, "w", encoding="utf-8") as handle:
        handle.write(patched)


if __name__ == "__main__":
    main()
