#!/usr/bin/env python3
"""Check real macOS input denial in a temporary app with a fresh identity.

Run through resource_queue.py. Does not reset or grant TCC permissions.
Pass --profile to also check AOT code without debug assertions.
"""
import argparse
from pathlib import Path
import plistlib
import subprocess
import tempfile
import uuid


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', action='store_true')
    arguments = parser.parse_args()
    mode = 'profile' if arguments.profile else 'debug'
    root = Path(__file__).resolve().parent.parent
    flutter = str(root / '.fvm/flutter_sdk/bin/flutter')
    target = 'integration_test/keyboard_permission_native_test.dart'

    def run(*arguments):
        subprocess.run(arguments, cwd=root, check=True)

    run(flutter, 'build', 'macos', f'--{mode}', '--no-pub', f'--target={target}')
    with tempfile.TemporaryDirectory(prefix='walone-no-input-') as directory:
        app = Path(directory) / 'Walone.app'
        run('ditto', str(root / f'build/macos/Build/Products/{mode.title()}/Walone.app'), str(app))
        plist = app / 'Contents/Info.plist'
        data = plistlib.loads(plist.read_bytes())
        data['CFBundleIdentifier'] = f'dev.soyjanks.walone.permission-test.{uuid.uuid4().hex}'
        plist.write_bytes(plistlib.dumps(data))
        run('codesign', '--force', '--deep', '--sign', '-', '--entitlements',
            'macos/Runner/DebugProfile.entitlements', str(app))
        run(flutter, 'drive', f'--{mode}', '--no-pub', '-d', 'macos',
            '--driver=test_driver/integration_test.dart', f'--target={target}',
            f'--use-application-binary={app}')


if __name__ == '__main__':
    main()
