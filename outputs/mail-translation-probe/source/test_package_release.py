"""Real temporary bundles/ZIPs; only macOS codesign is replaced at its boundary."""
from pathlib import Path
import hashlib
import importlib.util
import os
import plistlib
import stat
import struct
import tempfile
import unittest
import zipfile

MODULE = Path(__file__).with_name('package_release.py')


class PackageReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.app = self.root / 'MailTrans.app'
        self.assertTrue(MODULE.exists(), 'Release packaging is not implemented')
        spec = importlib.util.spec_from_file_location('package_release', MODULE)
        self.package = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.package)
        self.make_bundle(self.app, 'local.codex.mailtranslationprobe', 'MailTrans')
        self.make_bundle(self.app / 'Contents/PlugIns/MailTranslationProbe.appex',
                         'local.codex.mailtranslationprobe.extension', 'MailTranslationProbeExtension', 'XPC!')
        self.make_bundle(self.app / 'Contents/Helpers/LanguageSetup.app',
                         'local.codex.mailtranslationprobe.languages', 'LanguageSetup')
        for name in ('TranslationWorker', 'MailTransLifecycle'):
            self.executable(self.app / 'Contents/MacOS' / name)
        resources = self.app / 'Contents/Resources'
        resources.mkdir()
        (resources / 'AppIcon.icns').write_bytes(b'icon')
        (resources / 'layout-sample.eml').write_bytes(b'Subject: synthetic sample\n')
        (self.root / 'private-mail.eml').write_bytes(b'not for release')

    def executable(self, path, *, cpu=0x0100000C, platform=1, minimum=0x001A0400):
        path.parent.mkdir(parents=True, exist_ok=True)
        # Mach-O 64 header and LC_BUILD_VERSION; independent hand-built fixture.
        path.write_bytes(struct.pack('<8I', 0xFEEDFACF, cpu, 0, 2, 1, 24, 0, 0)
                         + struct.pack('<6I', 0x32, 24, platform, minimum, 0x001A0500, 0))
        path.chmod(0o755)

    def make_bundle(self, path, identifier, executable, kind='APPL'):
        contents = path / 'Contents'
        contents.mkdir(parents=True)
        (contents / 'Info.plist').write_bytes(plistlib.dumps({
            'CFBundleIdentifier': identifier, 'CFBundleExecutable': executable,
            'CFBundlePackageType': kind, 'CFBundleShortVersionString': '0.10',
            'CFBundleVersion': '10', 'LSMinimumSystemVersion': '26.4',
        }))
        self.executable(contents / 'MacOS' / executable)
        (contents / '_CodeSignature').mkdir()
        (contents / '_CodeSignature/CodeResources').write_bytes(b'signature')

    def create(self, verifier=None):
        return self.package.package_app(self.app, self.root / 'release',
                                        signature_verifier=verifier or (lambda app: None))

    def test_app_only_archive_checksum_permissions_and_round_trip(self):
        verified = []
        archive, checksum = self.create(lambda app: verified.append(Path(app)))
        self.assertEqual(archive.name, 'MailTrans-0.10.0-macos-arm64-development.zip')
        with zipfile.ZipFile(archive) as zipped:
            self.assertTrue(all(name.startswith('MailTrans.app/') for name in zipped.namelist()))
            self.assertNotIn('private-mail.eml', '\n'.join(zipped.namelist()))
            binary = zipped.getinfo('MailTrans.app/Contents/MacOS/MailTrans')
            self.assertEqual(stat.S_IMODE(binary.external_attr >> 16), 0o755)
            self.assertEqual(zipped.read('MailTrans.app/Contents/Resources/layout-sample.eml'),
                             b'Subject: synthetic sample\n')
        self.assertEqual(checksum.read_text(), hashlib.sha256(archive.read_bytes()).hexdigest()
                         + '  ' + archive.name + '\n')
        self.assertEqual(len(verified), 2)
        self.assertEqual(verified[0], self.app)
        self.assertNotEqual(verified[1], self.app)
        self.assertFalse(verified[1].exists(), 'verification extraction must be temporary')

    def test_archive_reproducible_and_stale_outputs_replaced(self):
        archive, checksum = self.create()
        original = archive.read_bytes()
        os.utime(self.app / 'Contents/Info.plist', (1234567890, 1234567890))
        checksum.write_text('stale')
        self.create()
        self.assertEqual(archive.read_bytes(), original)
        self.assertNotEqual(checksum.read_text(), 'stale')

    def test_missing_required_file_rejected_before_output(self):
        (self.app / 'Contents/MacOS/TranslationWorker').unlink()
        with self.assertRaisesRegex(ValueError, 'TranslationWorker'):
            self.create()
        self.assertFalse((self.root / 'release').exists())

    def test_wrong_identity_version_or_floor_rejected(self):
        info_path = self.app / 'Contents/Info.plist'
        original = plistlib.loads(info_path.read_bytes())
        for key, value in [('CFBundleIdentifier', 'com.unrelated.app'),
                           ('CFBundleVersion', '9'), ('CFBundleShortVersionString', '0.9'),
                           ('LSMinimumSystemVersion', '26.5')]:
            with self.subTest(key=key):
                info_path.write_bytes(plistlib.dumps(dict(original, **{key: value})))
                with self.assertRaisesRegex(ValueError, key):
                    self.create()
        info_path.write_bytes(plistlib.dumps(original))

    def test_nested_bundle_identity_rejected(self):
        path = self.app / 'Contents/PlugIns/MailTranslationProbe.appex/Contents/Info.plist'
        info = plistlib.loads(path.read_bytes())
        info['CFBundleIdentifier'] = 'wrong.extension'
        path.write_bytes(plistlib.dumps(info))
        with self.assertRaisesRegex(ValueError, 'CFBundleIdentifier'):
            self.create()

    def test_non_arm_macos_or_incompatible_minimum_binary_rejected(self):
        binary = self.app / 'Contents/MacOS/MailTrans'
        for kwargs in ({'cpu': 0x01000007}, {'platform': 2}, {'minimum': 0x001A0500}):
            with self.subTest(kwargs=kwargs):
                self.executable(binary, **kwargs)
                with self.assertRaisesRegex(ValueError, 'Mach-O|arm64|macOS|deployment'):
                    self.create()

    def test_nonexecutable_binary_rejected(self):
        (self.app / 'Contents/MacOS/MailTrans').chmod(0o644)
        with self.assertRaisesRegex(ValueError, 'executable'):
            self.create()

    def test_unexpected_private_file_rejected(self):
        for name in ('inbox.eml', '.DS_Store', 'cache.json'):
            path = self.app / 'Contents/Resources' / name
            path.write_text('private')
            with self.assertRaisesRegex(ValueError, 'Unexpected'):
                self.create()
            path.unlink()

    def test_internal_symlink_preserved_and_escaping_symlink_rejected(self):
        icon = self.app / 'Contents/Resources/AppIcon.icns'
        icon.unlink()
        icon.symlink_to('layout-sample.eml')
        archive, _ = self.create()
        with zipfile.ZipFile(archive) as zipped:
            entry = zipped.getinfo('MailTrans.app/Contents/Resources/AppIcon.icns')
            self.assertTrue(stat.S_ISLNK(entry.external_attr >> 16))
            self.assertEqual(zipped.read(entry), b'layout-sample.eml')
        icon.unlink()
        icon.symlink_to(self.root / 'private-mail.eml')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.create()

    def test_signature_failures_never_publish_archive(self):
        for fail_on in (1, 2):
            with self.subTest(fail_on=fail_on):
                calls = []
                def verify(app):
                    calls.append(app)
                    if len(calls) == fail_on:
                        raise ValueError('signature invalid')
                with self.assertRaisesRegex(ValueError, 'signature invalid'):
                    self.create(verify)
                self.assertFalse((self.root / 'release/MailTrans-0.10.0-macos-arm64-development.zip').exists())

    def test_output_inside_app_rejected(self):
        with self.assertRaisesRegex(ValueError, 'output'):
            self.package.package_app(self.app, self.app / 'release', signature_verifier=lambda _: None)


if __name__ == '__main__':
    unittest.main()
