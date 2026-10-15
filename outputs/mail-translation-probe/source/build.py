#!/usr/bin/env python3
"""Build MailTrans locally, or run native regressions without Swift/model dependencies."""
import argparse
import base64
import json
import os
from pathlib import Path
import platform
import plistlib
import shutil
import struct
import subprocess
import sys
import zlib

SOURCE = Path(__file__).resolve().parent
OUT = SOURCE.parent
WORK = OUT.parent.parent / "work" / "mail-real"


def developer_environment(selected, environ=None):
    env = dict(os.environ if environ is None else environ)
    if selected:
        env['DEVELOPER_DIR'] = str(selected)
    # Without an override, xcrun honors DEVELOPER_DIR or xcode-select itself.
    return env


def require_app_toolchain(sdk_version, architecture):
    try:
        version = tuple(int(part) for part in sdk_version.split('.')[:2])
    except ValueError as error:
        raise ValueError(f'Cannot determine macOS SDK version: {sdk_version}') from error
    if version < (26, 5):
        raise ValueError(f'Full build requires macOS SDK 26.5 or newer; selected SDK is {sdk_version}')
    if architecture != 'arm64':
        raise ValueError(f'Full build requires an arm64 Mac; found {architecture}')


def compiler(sdk, minimum):
    return ['/usr/bin/xcrun', '--sdk', 'macosx', 'clang', '-fobjc-arc', '-fblocks', '-Wall', '-Wextra',
            '-Wno-unused-parameter', '-Wno-incompatible-pointer-types',
            '-mmacosx-version-min=' + minimum, '-isysroot', sdk,
            '-I' + sdk + '/usr/include/libxml2', '-lxml2', '-framework', 'Cocoa',
            '-framework', 'MailKit', '-framework', 'NaturalLanguage']


def native_test_commands(source, work, sdk, minimum):
    cc = compiler(sdk, minimum)
    src = lambda name: str(source / name)
    executable = lambda name: str(work / name)
    core = src('MIMECore.m')
    life = src('MailLifecycle.m')
    management = [src('MTProcessRunner.m'), src('MTAppManagement.m'), src('MTSetupController.m')]
    commands = []
    def test(name, sources, arguments=()):
        commands.append(cc + sources + ['-o', executable(name)])
        commands.append([executable(name), *arguments])
    commands.append(cc + [life, src('PreferencesFixture.m'), '-o', executable('preferences-fixture')])
    commands.append([sys.executable, src('verify_lifecycle_preferences.py'), executable('preferences-fixture')])
    commands.append(cc + [src('LifecycleFixture.m'), '-o', executable('lifecycle-fixture')])
    test('lifecycle-tests', [life, src('LifecycleTests.m')], [executable('lifecycle-fixture')])
    test('core-tests', [core, src('CoreTests.m')])
    test('process-runner-tests', [src('MTProcessRunner.m'), src('ProcessRunnerTests.m')])
    test('management-tests', management + [src('ManagementTests.m')])
    test('setup-tests', management + [src('SetupTests.m')])
    test('app-tests', [core, life, *management, src('AppTests.m')])
    test('extension-tests', [core, src('ExtensionTests.m')])
    return commands


def plist(path, value):
    path.write_bytes(plistlib.dumps(value, sort_keys=False))


def synthetic_fixture():
    # Small generated PNG; it is embedded via CID and never fetched over the network.
    width, height = 320, 60
    pixels = b"".join(b"\0" + bytes(c for x in range(width) for c in (35+x//3, 90+y, 160)) for y in range(height))
    def png_chunk(kind, content):
        return struct.pack(">I", len(content)) + kind + content + struct.pack(">I", zlib.crc32(kind + content))
    png = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    png += png_chunk(b"IDAT", zlib.compress(pixels)) + png_chunk(b"IEND", b"")
    image64 = "\r\n".join(base64.b64encode(png).decode()[i:i+76] for i in range(0, len(base64.b64encode(png)), 76))
    html = '''<!doctype html>
<html><body style="margin:0;padding:28px;background:#f2f4f7;font-family:Helvetica,Arial,sans-serif;color:#172334">
<table role="presentation" style="max-width:640px;width:100%;border-collapse:collapse;background:white"><tr><td style="padding:28px">
<h1 style="font-size:26px;margin:0 0 18px;color:#264e85">Thursday workshop briefing</h1>
<p style="font-size:16px;line-height:1.8">The workshop has moved to Thursday morning. Please bring the revised schedule.</p>
<p style="font-size:16px;line-height:1.8;background:#eaf2ff;padding:16px;border-radius:8px">We will review the prototype together and collect feedback before lunch.</p>
<h2 style="font-size:20px">Meeting arrangements</h2>
<table style="width:100%;border-collapse:collapse;font-size:15px" border="1" cellpadding="12">
<tr style="background:#f2f4f7"><th align="left">Task</th><th align="left">Status</th></tr>
<tr><td>Review the revised budget</td><td><strong>Thursday at 10:30</strong></td></tr>
<tr><td>Bring the printed schedule</td><td>Conference room 3</td></tr></table>
<p><img src="cid:probe-gradient" width="320" height="60" alt="Embedded gradient" style="display:block;border-radius:8px"></p>
<p style="font-size:13px;color:#667085">This picture is embedded in the email, not downloaded.</p>
<p><a href="https://example.com/" style="color:#2359a8">Read the example link</a></p>
<p style="font-size:12px;color:#667085">This is a fresh synthetic email for testing local machine translation.</p>
</td></tr></table></body></html>'''.replace("\n", "\r\n")
    fixture = ("From: Layout Probe <probe@example.invalid>\r\n"
        "To: Local Preview <preview@example.invalid>\r\n"
        "Subject: Local translation acceptance - Thursday workshop\r\n"
        "Date: Tue, 13 Oct 2026 12:00:00 +0800\r\n"
        "Message-ID: <local-translation-acceptance-v2@example.invalid>\r\n"
        "X-Apple-Mail-Translation-Probe: local-translation-acceptance-v2\r\n"
        "MIME-Version: 1.0\r\n"
        "Content-Type: multipart/related; boundary=local-layout-probe-boundary\r\n\r\n"
        "--local-layout-probe-boundary\r\nContent-Type: text/html; charset=utf-8\r\n"
        "Content-Transfer-Encoding: 8bit\r\n\r\n" + html + "\r\n"
        "--local-layout-probe-boundary\r\nContent-Type: image/png\r\n"
        "Content-ID: <probe-gradient>\r\nContent-Disposition: inline; filename=gradient.png\r\n"
        "Content-Transfer-Encoding: base64\r\n\r\n" + image64 + "\r\n"
        "--local-layout-probe-boundary--\r\n").encode()
    return fixture


def prepare_resources(app, work, env, run):
    out = OUT
    fixture = synthetic_fixture()
    sample = out / "layout-sample.eml"
    sample.write_bytes(fixture)
    (app / "Contents/Resources/layout-sample.eml").write_bytes(fixture)

    # Package the generated artwork in all standard macOS icon representations.
    # Keep intermediate sizes in work; version only the original PNG artwork.
    icon_png = out / "assets/mail-translation-icon.png"
    iconset = work / "AppIcon.iconset"
    iconset.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 128, 256, 512):
        for scale in (1, 2):
            suffix = "@2x" if scale == 2 else ""
            name = f"icon_{size}x{size}{suffix}.png"
            pixels = str(size * scale)
            subprocess.run(["/usr/bin/sips", "-z", pixels, pixels, str(icon_png),
                            "--out", str(iconset / name)], env=env, check=True,
                           stdout=subprocess.DEVNULL, timeout=60)
    icon_icns = work / "AppIcon.icns"
    run(["/usr/bin/iconutil", "-c", "icns", str(iconset), "-o", str(icon_icns)])
    shutil.copyfile(icon_icns, app / "Contents/Resources/AppIcon.icns")



def write_bundle_plists(app, ext, helper):
    for directory in [app / 'Contents/MacOS', app / 'Contents/Resources',
                      ext / 'Contents/MacOS', helper / 'Contents/MacOS']:
        directory.mkdir(parents=True, exist_ok=True)
    common = {'CFBundleVersion': '10', 'CFBundleShortVersionString': '0.10',
              'LSMinimumSystemVersion': '26.4'}
    plist(app / 'Contents/Info.plist', dict(common, **{
        'CFBundleIdentifier': 'local.codex.mailtranslationprobe', 'CFBundleName': 'MailTrans',
        'CFBundleDisplayName': 'MailTrans', 'CFBundleExecutable': 'MailTrans', 'CFBundlePackageType': 'APPL',
        'CFBundleIconFile': 'AppIcon', 'NSHighResolutionCapable': True, 'LSUIElement': True,
        'CFBundleURLTypes': [{'CFBundleURLName': 'MailTrans', 'CFBundleURLSchemes': ['mailtranslationprobe']}],
    }))
    plist(ext / 'Contents/Info.plist', dict(common, **{
        'CFBundleIdentifier': 'local.codex.mailtranslationprobe.extension', 'CFBundleName': 'MailTrans',
        'CFBundleDisplayName': 'MailTrans', 'CFBundleExecutable': 'MailTranslationProbeExtension',
        'CFBundlePackageType': 'XPC!', 'NSExtension': {
            'NSExtensionPointIdentifier': 'com.apple.email.extension',
            'NSExtensionPrincipalClass': 'MailTranslationProbeExtension',
            'NSExtensionAttributes': {'MEExtensionCapabilities': ['MEMessageSecurityHandler']},
        },
    }))
    plist(helper / 'Contents/Info.plist', dict(common, **{
        'CFBundleIdentifier': 'local.codex.mailtranslationprobe.languages', 'CFBundleName': 'MailTrans 语言包',
        'CFBundleExecutable': 'LanguageSetup', 'CFBundlePackageType': 'APPL', 'NSHighResolutionCapable': True,
    }))


def sign_app(app, ext, helper, work, env, run):
    entitlements = work / 'extension.entitlements'
    plist(entitlements, {'com.apple.security.app-sandbox': True})
    def clean_signing_metadata():
        attributes = subprocess.check_output(['/usr/bin/xattr', '-lr', str(app)], env=env, timeout=60)
        for attribute in ('com.apple.FinderInfo', 'com.apple.ResourceFork'):
            if attribute.encode() in attributes:
                run(['/usr/bin/xattr', '-dr', attribute, str(app)])
    for target, extra in [(ext, ['--entitlements', str(entitlements)]), (helper, []),
                          (app / 'Contents/MacOS/TranslationWorker', []),
                          (app / 'Contents/MacOS/MailTransLifecycle', []), (app, [])]:
        for attempt in range(3):
            clean_signing_metadata()
            result = subprocess.run(['/usr/bin/codesign', '--force', '--sign', '-'] + extra + [str(target)],
                                    env=env, timeout=60)
            if result.returncode == 0:
                break
        else:
            raise RuntimeError(f'Could not sign {target}')
    for attempt in range(5):
        clean_signing_metadata()
        verification = subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)],
                                      env=env, capture_output=True, text=True, timeout=60)
        if verification.returncode == 0:
            print(verification.stderr.strip())
            break
        if 'FinderInfo' not in verification.stderr and 'resource fork' not in verification.stderr:
            raise RuntimeError(verification.stderr)
    else:
        raise RuntimeError(verification.stderr)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--developer-dir', help='Xcode developer directory (otherwise DEVELOPER_DIR/xcode-select)')
    parser.add_argument('--native-tests-only', action='store_true',
                        help='Compile/run native regressions for this runner OS; no app, Swift, Mail data or models')
    args = parser.parse_args(argv)
    env = developer_environment(args.developer_dir)
    if sys.platform != 'darwin':
        parser.error('Native compilation requires macOS; run portable Python tests on this platform')
    def output(command):
        return subprocess.check_output(command, env=env, text=True, timeout=60).strip()
    def run(command, timeout=180):
        print('+ ' + ' '.join(map(str, command)), flush=True)
        subprocess.run(command, env=env, check=True, timeout=timeout)
    sdk = output(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-path'])
    sdk_version = output(['/usr/bin/xcrun', '--sdk', 'macosx', '--show-sdk-version'])
    os_version = platform.mac_ver()[0]
    native_minimum = '.'.join(os_version.split('.')[:2])
    if not native_minimum:
        raise ValueError('Cannot determine runner macOS version for native test deployment')
    if not args.native_tests_only:
        require_app_toolchain(sdk_version, platform.machine())
    WORK.mkdir(parents=True, exist_ok=True)
    (WORK / 'native-tests-verification.txt').unlink(missing_ok=True)
    if not args.native_tests_only:
        (WORK / 'build-verification.txt').unlink(missing_ok=True)
    toolchain = {'os': os_version, 'architecture': platform.machine(), 'sdk': sdk_version,
                 'sdk_path': sdk, 'xcode': output(['/usr/bin/xcodebuild', '-version']),
                 'developer_directory': env.get('DEVELOPER_DIR') or output(['/usr/bin/xcode-select', '-p']),
                 'native_test_deployment': native_minimum, 'app_deployment': '26.4'}
    print(json.dumps(toolchain, indent=2), flush=True)
    for command in native_test_commands(SOURCE, WORK, sdk, native_minimum):
        # Fail clearly if GUI/lifecycle regression hangs on a hosted login session.
        run(command, timeout=180 if command[0] == '/usr/bin/xcrun' else 90)
    (WORK / 'native-tests-verification.txt').write_text(
        json.dumps(toolchain, indent=2) + '\nNative regressions: passed\nLanguage models: not exercised\n')
    if args.native_tests_only:
        print('Native regressions passed; app/Swift/model verification not requested.')
        return
    app = OUT / 'MailTrans.app'
    if app.is_symlink():
        raise ValueError('Refusing to replace symlinked build app')
    if app.exists():
        shutil.rmtree(app)
    ext = app / 'Contents/PlugIns/MailTranslationProbe.appex'
    helper = app / 'Contents/Helpers/LanguageSetup.app'
    write_bundle_plists(app, ext, helper)
    prepare_resources(app, WORK, env, run)
    cc = compiler(sdk, '26.4')
    core, life = str(SOURCE / 'MIMECore.m'), str(SOURCE / 'MailLifecycle.m')
    host = [core, life, str(SOURCE / 'MTProcessRunner.m'), str(SOURCE / 'MTSetupController.m'),
            str(SOURCE / 'MTAppManagement.m')]
    run(cc + ['-fapplication-extension', '-Xlinker', '-e', '-Xlinker', '_NSExtensionMain', core,
              str(SOURCE / 'ProbeExtension.m'), '-o', str(ext / 'Contents/MacOS/MailTranslationProbeExtension')])
    run(cc + host + [str(SOURCE / 'ProbeApp.m'), '-o', str(app / 'Contents/MacOS/MailTrans')])
    run(cc + [life, str(SOURCE / 'LifecycleMain.m'), '-o', str(app / 'Contents/MacOS/MailTransLifecycle')])
    swift = ['/usr/bin/xcrun', 'swiftc', '-parse-as-library', '-sdk', sdk, '-target', 'arm64-apple-macos26.4']
    run(swift + [str(SOURCE / 'TranslationProvider.swift'), str(SOURCE / 'TranslationWorker.swift'),
                 '-o', str(app / 'Contents/MacOS/TranslationWorker')])
    run(swift + [str(SOURCE / 'LanguageSetup.swift'), '-o', str(helper / 'Contents/MacOS/LanguageSetup')])
    run([sys.executable, str(SOURCE / 'SetupModelTests.py'), str(app / 'Contents/MacOS/TranslationWorker')], timeout=90)
    sign_app(app, ext, helper, WORK, env, run)
    (WORK / 'build-verification.txt').write_text(
        json.dumps(toolchain, indent=2) + '\nCompilation: passed\nAd-hoc signature verification: passed\n'
        'Native regressions: passed\nMail rendering and live translation: require separate UI/model verification\n')
    print(f'Built: {app}')


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError) as error:
        print(f'Build failed: {error}', file=sys.stderr)
        sys.exit(1)
