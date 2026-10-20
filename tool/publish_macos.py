#!/usr/bin/env python3
"""Собрать подписанный и нотариализированный DMG; --publish выпускает его на GitHub."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

from tool.macos_release import APP_NAME, BUNDLE_ID, PROJECT, identity, run, sign


REPOSITORY = "DartMule/walone"
FEED_URL = f"https://github.com/{REPOSITORY}/releases/latest/download/appcast.xml"
SPARKLE_NAMESPACE = "http://www.andymatuschak.org/xml-namespaces/sparkle"


def read_metadata(app):
    with (app / "Contents/Info.plist").open("rb") as source:
        metadata = plistlib.load(source)
    if metadata.get("CFBundleIdentifier") != BUNDLE_ID:
        raise RuntimeError("Неверный bundle ID")
    if metadata.get("SUFeedURL") != FEED_URL:
        raise RuntimeError("Адрес обновлений не совпадает с репозиторием релизов")
    try:
        valid_key = len(base64.b64decode(metadata["SUPublicEDKey"], validate=True)) == 32
    except (KeyError, ValueError):
        valid_key = False
    if not valid_key:
        raise RuntimeError("Не настроен публичный ключ Sparkle")
    version = metadata["CFBundleShortVersionString"]
    build = metadata["CFBundleVersion"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or not re.fullmatch(r"[1-9]\d*", build):
        raise RuntimeError("Ожидаются версия X.Y.Z и положительный целочисленный номер сборки")
    return metadata, version, int(build)


def validate_feed(path, version, build, archive):
    items = ET.parse(path).findall("./channel/item")
    if len(items) != 1:
        raise RuntimeError("В новом appcast должна быть ровно одна версия")
    item = items[0]
    ns = {"s": SPARKLE_NAMESPACE}
    enclosure = item.find("enclosure")
    expected = f"https://github.com/{REPOSITORY}/releases/download/v{version}/{archive.name}"
    if (item.findtext("s:version", namespaces=ns) != str(build)
            or enclosure is None or enclosure.get("url") != expected
            or enclosure.get("length") != str(archive.stat().st_size)
            or not enclosure.get(f"{{{SPARKLE_NAMESPACE}}}edSignature")):
        raise RuntimeError("Appcast не соответствует подписанному архиву")


def check_remote_build(build, directory):
    # Отсутствие релизов допустимо, сетевые ошибки и ошибки доступа — нет.
    releases = json.loads(run("gh", "release", "list", "--repo", REPOSITORY,
                              "--exclude-drafts", "--exclude-pre-releases", "--limit", "1",
                              "--json", "tagName", capture=True).stdout)
    if not releases:
        return
    run("gh", "release", "download", releases[0]["tagName"], "--repo", REPOSITORY,
        "--pattern", "appcast.xml", "--dir", directory)
    items = ET.parse(directory / "appcast.xml").findall("./channel/item")
    previous = max(int(item.findtext(f"{{{SPARKLE_NAMESPACE}}}version")) for item in items)
    if build <= previous:
        raise RuntimeError(f"Номер сборки должен быть больше опубликованного {previous}")


def notarize(archive, profile):
    result = json.loads(run("xcrun", "notarytool", "submit", archive,
                            "--keychain-profile", profile, "--wait",
                            "--output-format", "json", capture=True).stdout)
    if result.get("status") != "Accepted":
        raise RuntimeError(f"Apple отклонила архив: {result.get('id')} ({result.get('status')})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", default=os.environ.get("WALONE_SIGNING_IDENTITY"))
    parser.add_argument("--notary-profile", default=os.environ.get("WALONE_NOTARY_PROFILE"))
    parser.add_argument("--sparkle-tools", type=Path, required=True,
                        help="Каталог bin официального Sparkle 2.10.0")
    parser.add_argument("--flutter", default=os.environ.get("FLUTTER_BIN", "flutter"))
    parser.add_argument("--notes", type=Path, required=True, help="Описание релиза в Markdown")
    parser.add_argument("--skip-build", action="store_true")
    parser.add_argument("--publish", action="store_true", help="Опубликовать готовый релиз на GitHub")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise RuntimeError("Сборка релиза требует macOS")
    if not args.notary_profile:
        raise RuntimeError("Задайте --notary-profile: имя профиля notarytool в Keychain")
    notes = args.notes.resolve()
    if not notes.is_file() or not notes.read_text().strip():
        raise RuntimeError("Нужно непустое описание релиза")
    tools = args.sparkle_tools.resolve()
    for name in ["generate_keys", "generate_appcast"]:
        if not (tools / name).is_file():
            raise RuntimeError(f"Не найден {tools / name}")
    certificate, name = identity(args.identity)
    if not name.startswith("Developer ID Application:"):
        raise RuntimeError("Для распространения нужен Developer ID Application; Apple Development не подходит")
    run("xcrun", "notarytool", "history", "--keychain-profile", args.notary_profile,
        "--output-format", "json", capture=True)
    if args.publish:
        if not shutil.which("gh"):
            raise RuntimeError("Установите GitHub CLI и выполните gh auth login")
        repository = json.loads(run("gh", "repo", "view", REPOSITORY,
                                    "--json", "visibility", capture=True).stdout)
        if repository["visibility"] != "PUBLIC":
            raise RuntimeError("Репозиторий релизов должен быть публичным")
    if not args.skip_build:
        run(args.flutter, "build", "macos", "--release", "--no-pub")
    source = PROJECT / "build/macos/Build/Products/Release" / APP_NAME
    metadata, version, build = read_metadata(source)
    public_key = run(tools / "generate_keys", "--account", BUNDLE_ID, "-p", capture=True).stdout.strip()
    if public_key != metadata["SUPublicEDKey"]:
        raise RuntimeError("Ключ в Keychain не соответствует ключу приложения")
    output = PROJECT / "dist/macos" / f"{version}+{build}"
    if output.exists():
        raise RuntimeError(f"Каталог уже существует: {output}. Увеличьте номер сборки")
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="walone-release-") as temporary:
        staging = Path(temporary)
        if args.publish:
            check_remote_build(build, staging)
        image = staging / "image"
        image.mkdir()
        app = image / APP_NAME
        run("ditto", source, app)
        legal = app / "Contents/Resources/Legal"
        legal.mkdir(parents=True, exist_ok=True)
        for document in ["LICENSE.md", "NOTICE.md", "docs/licenses/Sparkle-LICENSE.txt"]:
            shutil.copyfile(PROJECT / document, legal / Path(document).name)
        sign(app, certificate, distribution=True)
        zip_path = staging / "notarization.zip"
        run("ditto", "-c", "-k", "--sequesterRsrc", "--keepParent", app, zip_path)
        notarize(zip_path, args.notary_profile)
        run("xcrun", "stapler", "staple", app)
        run("spctl", "--assess", "--type", "execute", "--verbose=2", app)
        (image / "Applications").symlink_to("/Applications")
        archives = staging / "archives"
        archives.mkdir()
        archive = archives / f"Walone-{version}-{build}-macos.dmg"
        run("hdiutil", "create", "-volname", "Walone", "-srcfolder", image,
            "-format", "UDZO", archive)
        run("codesign", "--sign", certificate, "--timestamp", archive)
        notarize(archive, args.notary_profile)
        run("xcrun", "stapler", "staple", archive)
        run("xcrun", "stapler", "validate", archive)
        shutil.copyfile(notes, archives / f"{archive.stem}.md")
        run(tools / "generate_appcast", "--account", BUNDLE_ID, "--maximum-deltas", "0",
            "--embed-release-notes", "--download-url-prefix",
            f"https://github.com/{REPOSITORY}/releases/download/v{version}/", archives)
        validate_feed(archives / "appcast.xml", version, build, archive)
        # Перемещаем артефакты только после всех проверок; рабочая установка не меняется.
        shutil.copytree(archives, output)
    archive = output / archive.name
    checksum = output / "SHA256SUMS"
    checksum.write_text(f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n")
    if args.publish:
        tag = f"v{version}"
        run("gh", "release", "create", tag, "--repo", REPOSITORY, "--draft",
            "--title", f"Walone {version}", "--notes-file", notes,
            archive, output / "appcast.xml", checksum)
        run("gh", "release", "edit", tag, "--repo", REPOSITORY, "--draft=false", "--latest")
    print(f"Готово: {output}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError, ET.ParseError) as error:
        print(f"Ошибка: {error}", file=sys.stderr)
        sys.exit(1)
