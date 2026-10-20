import contextlib
import io
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tool import macos_release as release


class InstallationSearchTest(unittest.TestCase):
    def test_distribution_signs_sparkle_helpers_before_enclosing_bundles(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Walone.app'
            framework = app / 'Contents/Frameworks/Sparkle.framework'
            helper = framework / 'Versions/B/Updater.app'
            executable = helper / 'Contents/MacOS/Updater'
            executable.parent.mkdir(parents=True)
            executable.write_bytes(bytes.fromhex('feedfacf') + b'executable')
            with patch.object(release, 'run') as command, \
                 patch.object(release, 'verify', return_value='requirement'):
                release.sign(app, 'certificate', distribution=True)
            calls = [call.args for call in command.call_args_list]
            self.assertEqual([call[-1] for call in calls], [executable, helper, framework, app])
            for call in calls:
                self.assertIn('--timestamp', call)
                self.assertNotIn('--timestamp=none', call)
                self.assertEqual(call.count('--options'), 1)
                self.assertIn('runtime', call)

    def test_unregister_ignores_only_missing_application_records(self):
        for code in [-10811, -10814]:
            with self.subTest(code=code), patch.object(release, 'run', side_effect=
                    subprocess.CalledProcessError(1, 'lsregister', stderr=f'failed to scan: {code}')):
                release.unregister(Path('/unindexed/Walone.app'))
        with patch.object(release, 'run', side_effect=
                subprocess.CalledProcessError(1, 'lsregister', stderr='permission denied')):
            with self.assertRaises(subprocess.CalledProcessError):
                release.unregister(Path('/unindexed/Walone.app'))

    def test_repeated_updates_leave_only_installed_app(self):
        self.check_installation()

    def test_failed_installed_verification_restores_previous_app(self):
        self.check_installation(failure='verification')

    def test_failed_registration_restores_previous_app(self):
        self.check_installation(failure='registration')

    def test_failed_signing_keeps_previous_app(self):
        self.check_installation(failure='signing')

    def check_installation(self, failure=None):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / 'flutter_app'
            source = project / 'build/macos/Build/Products/Release' / release.APP_NAME
            destination = root / 'Applications' / release.APP_NAME
            for bundle, version in [(source, 'new'), (destination, 'previous')]:
                bundle.mkdir(parents=True)
                (bundle / 'version').write_text(version)
            registered = {source: {'new'}, destination: {'previous'}}

            def command(program, *arguments, capture=False):
                if program == 'ditto':
                    origin, target = map(Path, arguments)
                    shutil.copytree(origin, target)
                    # Spotlight может обнаружить скопированный артефакт самостоятельно.
                    if not target.name.startswith('.'):
                        registered[target] = {(target / 'version').read_text()}
                elif program == release.LSREGISTER:
                    action, path = arguments[0], Path(arguments[1])
                    if action == '-f':
                        if failure == 'registration' and (path / 'version').read_text() == 'new':
                            raise subprocess.CalledProcessError(1, program, stderr='registration failed')
                        registered.setdefault(path, set()).add((path / 'version').read_text())
                    elif path in registered:
                        del registered[path]
                    else:
                        raise subprocess.CalledProcessError(1, program, stderr='error -10811')
                return subprocess.CompletedProcess([], 0, '', '')

            def verify(bundle):
                if failure == 'verification' and bundle == destination and (bundle / 'version').read_text() == 'new':
                    raise RuntimeError('installed verification failed')
                return 'requirement'

            def sign(bundle, certificate):
                if failure == 'signing':
                    raise RuntimeError('signing failed')
                return 'requirement'

            with patch.object(release, 'PROJECT', project), \
                 patch.object(release, 'run', side_effect=command), \
                 patch.object(release, 'identity', return_value=('certificate', 'test identity')), \
                 patch.object(release, 'sign', side_effect=sign), \
                 patch.object(release, 'verify', side_effect=verify), \
                 patch.object(release.subprocess, 'run', return_value=subprocess.CompletedProcess([], 1)), \
                 patch.object(release.sys, 'platform', 'darwin'), \
                 patch.object(release.sys, 'argv', ['release', '--skip-build', '--destination', str(destination)]), \
                 contextlib.redirect_stdout(io.StringIO()):
                if failure:
                    with self.assertRaises((RuntimeError, subprocess.CalledProcessError)):
                        release.main()
                else:
                    for version in ['new', 'newer']:
                        source.mkdir(parents=True, exist_ok=True)
                        (source / 'version').write_text(version)
                        registered[source] = {version}
                        release.main()
                        self.assertEqual(registered, {destination: {version}})
                        self.assertFalse(source.exists())
            expected = 'previous' if failure else 'newer'
            self.assertEqual((destination / 'version').read_text(), expected)
            if failure:
                self.assertEqual(registered[destination], {'previous'})
                self.assertTrue(source.exists())
            self.assertEqual(list(destination.parent.glob('.WaloneFlutter-*.app')), [])
            self.assertFalse((root / 'dist').exists())


if __name__ == '__main__':
    unittest.main()
