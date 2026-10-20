#!/usr/bin/env python3
"""Локальная сертификатная сборка, проверка и установка Walone для macOS."""

import argparse
from datetime import datetime
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import uuid


PROJECT = Path(__file__).resolve().parents[1]
BUNDLE_ID = "dev.soyjanks.walone.flutter"
APP_NAME = "Walone.app"
LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
MACHO = {bytes.fromhex(value) for value in (
    "feedface", "cefaedfe", "feedfacf", "cffaedfe",
    "cafebabe", "bebafeca", "cafebabf", "bfbafeca",
)}


def run(*arguments, capture=False):
    return subprocess.run(
        [str(argument) for argument in arguments], cwd=PROJECT, check=True,
        text=True, stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def unregister(app):
    try:
        run(LSREGISTER, "-u", app, capture=True)
    except subprocess.CalledProcessError as error:
        # Неизвестный или исключённый из Spotlight путь не требует очистки.
        diagnostic = (error.stdout or "") + (error.stderr or "")
        if not any(code in diagnostic for code in ("-10811", "-10814")):
            raise


def identity(requested):
    output = run("security", "find-identity", "-v", "-p", "codesigning", capture=True).stdout
    candidates = re.findall(r'\b([0-9A-F]{40}) "((?:Apple Development:|Developer ID Application:)[^"]+)"', output)
    if requested:
        candidates = [(digest, name) for digest, name in candidates
                      if requested.upper() == digest or requested == name]
    if len(candidates) != 1:
        raise RuntimeError("Нужен один действующий Apple Development / Developer ID Application сертификат. "
                           "При нескольких задайте WALONE_SIGNING_IDENTITY (имя или SHA-1). Ad-hoc не используется.")
    return candidates[0]


def requirement(app):
    result = run("codesign", "-d", "-r-", app, capture=True)
    for line in (result.stdout + result.stderr).splitlines():
        if "designated => " in line:
            return line.split("designated => ", 1)[1]
    raise RuntimeError("Не найдено designated requirement приложения")


def verify(app):
    run("codesign", "--verify", "--deep", "--strict", "--verbose=2", app)
    metadata = run("codesign", "-d", "--verbose=2", app, capture=True).stderr
    rule = requirement(app)
    if "Signature=adhoc" in metadata or "cdhash" in rule or "anchor apple" not in rule:
        raise RuntimeError("Сборка не имеет постоянной сертификатной идентичности")
    if f'identifier "{BUNDLE_ID}"' not in rule:
        raise RuntimeError("Неверный bundle ID подписанного приложения")
    print(rule, flush=True)
    return rule


def sign(app, certificate, *, distribution=False):
    options = ["--timestamp", "--options", "runtime"] if distribution else ["--timestamp=none"]
    # Сначала внутренний Mach-O код, затем enclosing frameworks и основное приложение.
    for path in sorted(app.rglob("*")):
        if path.is_symlink() or not path.is_file() or path.parent == app / "Contents/MacOS":
            continue
        with path.open("rb") as source:
            executable = source.read(4) in MACHO
        if executable:
            run("codesign", "--force", "--sign", certificate, *options, path)
    # Sparkle содержит вложенные приложения и XPC: подписываем изнутри наружу.
    bundles = sorted((path for path in app.rglob("*")
                      if path.suffix in (".framework", ".app", ".xpc") and path.is_dir()
                      and not path.is_symlink()), key=lambda path: len(path.parts), reverse=True)
    for bundle in bundles:
        run("codesign", "--force", "--sign", certificate, *options, bundle)
    app_options = options if distribution else [*options, "--options", "runtime"]
    run("codesign", "--force", "--sign", certificate, *app_options,
        "--entitlements", PROJECT / "macos/Runner/Release.entitlements", app)
    return verify(app)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--destination", type=Path, default=Path("/Applications") / APP_NAME)
    parser.add_argument("--identity", default=os.environ.get("WALONE_SIGNING_IDENTITY"))
    parser.add_argument("--flutter", default=os.environ.get("FLUTTER_BIN", "flutter"))
    parser.add_argument("--skip-build", action="store_true", help="Подписать уже собранный Release")
    parser.add_argument("--verify-only", action="store_true", help="Только проверить установленную копию")
    args = parser.parse_args()
    if sys.platform != "darwin":
        raise RuntimeError("Команда предназначена для macOS")
    destination = args.destination.expanduser().absolute()
    if args.verify_only:
        verify(destination)
        return
    if destination.name != APP_NAME or destination.is_symlink():
        raise RuntimeError(f"Назначение должно быть обычным bundle {APP_NAME}")
    pattern = "^" + re.escape(str(destination / "Contents/MacOS/Walone")) + r"([[:space:]]|$)"
    running = subprocess.run(["pgrep", "-f", pattern], stdout=subprocess.DEVNULL).returncode
    if running not in (0, 1):
        raise RuntimeError("Не удалось проверить работающие экземпляры приложения")
    if running == 0:
        raise RuntimeError("Сначала завершите установленную Walone через её меню")
    certificate, name = identity(args.identity)
    print(f"Подпись: {name}\nУстановка: {destination}", flush=True)
    if not args.skip_build:
        run(args.flutter, "build", "macos", "--release", "--no-pub")
    source = PROJECT / "build/macos/Build/Products/Release" / APP_NAME
    if not source.is_dir():
        raise RuntimeError("Release-сборка отсутствует")
    token = datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:8]
    destination.parent.mkdir(parents=True, exist_ok=True)
    staging = destination.with_name(f".WaloneFlutter-install-{token}.app")
    backup = None
    try:
        run("ditto", source, staging)
        rule = sign(staging, certificate)
        if destination.exists():
            previous_rule = verify(destination)
            run("codesign", "--verify", "--strict", "-R", "=" + previous_rule, staging)
            # Регистрация относится к исходному пути до переноса в резервную копию.
            unregister(destination)
            previous = destination.with_name(f".WaloneFlutter-previous-{token}.app")
            destination.rename(previous)
            backup = previous
        try:
            staging.rename(destination)
            verify(destination)
            run(LSREGISTER, "-f", destination)
        except (OSError, RuntimeError, subprocess.CalledProcessError):
            # Даже ошибка проверки после замены возвращает предыдущую версию.
            if destination.exists():
                destination.rename(staging)
            if backup is not None:
                backup.rename(destination)
                backup = None
                run(LSREGISTER, "-f", destination)
            raise
    finally:
        if staging.exists():
            unregister(staging)
            shutil.rmtree(staging)
    # Удаляем только после проверки и регистрации установленной версии.
    unregister(source)
    shutil.rmtree(source)
    if backup is not None:
        unregister(backup)
        shutil.rmtree(backup)
    (PROJECT / "build/macos-installation.json").write_text(json.dumps({
        "bundleID": BUNDLE_ID, "destination": str(destination),
        "identity": certificate, "identityName": name,
        "requirement": rule, "notarized": False,
    }, ensure_ascii=False, indent=2) + "\n")
    print(f"Готово: {destination}\nПромежуточная сборка и резервная копия удалены.", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, subprocess.CalledProcessError, OSError) as error:
        print(f"Ошибка: {error}", file=sys.stderr)
        sys.exit(1)
