#!/usr/bin/env python3
"""Package the exact signed MailTrans development app; never signs or uploads it."""
import argparse
import hashlib
import os
from pathlib import Path
import plistlib
import stat
import struct
import subprocess
import sys
import tempfile
import zipfile

ARCHIVE_NAME = 'MailTrans-0.11.0-macos-arm64-development.zip'
BUNDLES = {
    '': ('local.codex.mailtranslationprobe', 'MailTrans', 'APPL'),
    'Contents/PlugIns/MailTranslationProbe.appex': (
        'local.codex.mailtranslationprobe.extension', 'MailTranslationProbeExtension', 'XPC!'),
    'Contents/Helpers/LanguageSetup.app': (
        'local.codex.mailtranslationprobe.languages', 'LanguageSetup', 'APPL'),
}


def verify_signature(app):
    if sys.platform != 'darwin':
        raise ValueError('Real signature verification requires macOS and /usr/bin/codesign')
    subprocess.run(['/usr/bin/codesign', '--verify', '--deep', '--strict', '--verbose=2', str(app)],
                   check=True, timeout=60)


def validate_macho(path):
    """Require a thin arm64 macOS binary whose deployment target supports 26.4."""
    if not path.is_file() or not (path.stat().st_mode & 0o111):
        raise ValueError(f'Missing executable: {path}')
    data = path.read_bytes()
    if len(data) < 32 or struct.unpack_from('<I', data)[0] != 0xFEEDFACF:
        raise ValueError(f'Expected 64-bit Mach-O executable: {path}')
    _, cpu, _, _, commands, command_size, _, _ = struct.unpack_from('<8I', data)
    if cpu != 0x0100000C:
        raise ValueError(f'Expected arm64 executable: {path}')
    end = 32 + command_size
    if end > len(data):
        raise ValueError(f'Truncated Mach-O commands: {path}')
    offset = 32
    found = False
    for _ in range(commands):
        if offset + 8 > end:
            raise ValueError(f'Truncated Mach-O command: {path}')
        command, size = struct.unpack_from('<2I', data, offset)
        if size < 8 or offset + size > end:
            raise ValueError(f'Invalid Mach-O command: {path}')
        if command == 0x32:  # LC_BUILD_VERSION
            if size < 24:
                raise ValueError(f'Invalid Mach-O build version: {path}')
            platform, minimum = struct.unpack_from('<2I', data, offset + 8)
            if platform != 1:
                raise ValueError(f'Expected macOS platform: {path}')
            if minimum > 0x001A0400:
                raise ValueError(f'Incompatible deployment target: {path}')
            found = True
        offset += size
    if not found:
        raise ValueError(f'Missing macOS deployment target in Mach-O: {path}')


def validate_app(app):
    if app.name != 'MailTrans.app' or not app.is_dir() or app.is_symlink():
        raise ValueError('Expected an existing, real MailTrans.app directory')
    expected = {'Contents/Resources/AppIcon.icns', 'Contents/Resources/layout-sample.eml',
                'Contents/MacOS/TranslationWorker', 'Contents/MacOS/MailTransLifecycle'}
    for relative, (identifier, executable, kind) in BUNDLES.items():
        prefix = f'{relative}/' if relative else ''
        info_path = app / prefix / 'Contents/Info.plist'
        try:
            info = plistlib.loads(info_path.read_bytes())
        except (OSError, plistlib.InvalidFileException) as error:
            raise ValueError(f'Missing or invalid Info.plist: {info_path}') from error
        for key, value in {'CFBundleIdentifier': identifier, 'CFBundleExecutable': executable,
                           'CFBundlePackageType': kind, 'CFBundleShortVersionString': '0.11',
                           'CFBundleVersion': '11', 'LSMinimumSystemVersion': '26.4'}.items():
            if info.get(key) != value:
                raise ValueError(f'{info_path}: {key} must be {value!r}')
        expected.update({prefix + 'Contents/Info.plist', prefix + 'Contents/MacOS/' + executable,
                         prefix + 'Contents/_CodeSignature/CodeResources'})
    allowed_dirs = set()
    for relative in expected:
        allowed_dirs.update(str(parent) for parent in Path(relative).parents if str(parent) != '.')
    for path in app.rglob('*'):
        relative = path.relative_to(app).as_posix()
        if path.is_symlink():
            target = os.readlink(path)
            try:
                resolved = path.resolve(strict=True)
            except (OSError, RuntimeError) as error:
                raise ValueError(f'Invalid symlink: {path}') from error
            if os.path.isabs(target) or not resolved.is_relative_to(app.resolve()) or not resolved.is_file():
                raise ValueError(f'Unsafe symlink: {path}')
        elif path.is_dir():
            if relative not in allowed_dirs:
                raise ValueError(f'Unexpected directory in app: {relative}')
            continue
        elif not path.is_file():
            raise ValueError(f'Unexpected special file: {relative}')
        if relative not in expected:
            raise ValueError(f'Unexpected file in app: {relative}')
    for relative in sorted(expected):
        if not (app / relative).is_file():
            raise ValueError(f'Missing required app file: {relative}')
    for path in app.rglob('*'):
        if path.parent.name == 'MacOS':
            validate_macho(path)


def write_archive(app, archive):
    with zipfile.ZipFile(archive, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zipped:
        for path in [app] + sorted(app.rglob('*')):
            name = path.relative_to(app.parent).as_posix()
            mode = path.lstat().st_mode
            if stat.S_ISDIR(mode):
                name += '/'
                data = b''
                archive_mode = stat.S_IFDIR | 0o755
            elif stat.S_ISLNK(mode):
                data = os.readlink(path).encode('utf-8')
                archive_mode = stat.S_IFLNK | 0o777
            else:
                data = path.read_bytes()
                archive_mode = stat.S_IFREG | stat.S_IMODE(mode)
            # Stable metadata; xattrs, Finder state and resource forks are not copied.
            info = zipfile.ZipInfo(name, date_time=(2026, 10, 15, 0, 0, 0))
            info.create_system = 3
            info.external_attr = archive_mode << 16
            if stat.S_ISDIR(mode):
                info.external_attr |= 0x10
            info.compress_type = zipfile.ZIP_DEFLATED
            zipped.writestr(info, data)


def extract_archive(archive, destination):
    """Restore Unix modes and relative symlinks from our just-created ZIP."""
    with zipfile.ZipFile(archive) as zipped:
        for entry in zipped.infolist():
            relative = Path(entry.filename)
            if relative.is_absolute() or '..' in relative.parts:
                raise ValueError(f'Unsafe archive entry: {entry.filename}')
            path = destination / relative
            mode = entry.external_attr >> 16
            if entry.is_dir():
                path.mkdir(parents=True, exist_ok=True)
                path.chmod(stat.S_IMODE(mode))
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            data = zipped.read(entry)
            if stat.S_ISLNK(mode):
                target = data.decode('utf-8')
                if os.path.isabs(target) or not (path.parent / target).resolve().is_relative_to(destination.resolve()):
                    raise ValueError(f'Unsafe archive symlink: {entry.filename}')
                path.symlink_to(target)
            else:
                path.write_bytes(data)
                path.chmod(stat.S_IMODE(mode))


def package_app(app, output_dir, *, signature_verifier=verify_signature):
    app = Path(app).absolute()
    output_dir = Path(output_dir).resolve()
    if output_dir.is_relative_to(app.resolve()):
        raise ValueError('Release output must be outside the app')
    validate_app(app)
    signature_verifier(app)
    # Verify the exact bytes to be published, including executable modes and links.
    with tempfile.TemporaryDirectory(prefix='mailtrans-package-') as temporary:
        temporary = Path(temporary)
        staged = temporary / ARCHIVE_NAME
        write_archive(app, staged)
        extracted = temporary / 'extracted'
        extracted.mkdir()
        extract_archive(staged, extracted)
        extracted_app = extracted / 'MailTrans.app'
        validate_app(extracted_app)
        signature_verifier(extracted_app)
        digest = hashlib.sha256(staged.read_bytes()).hexdigest()
        output_dir.mkdir(parents=True, exist_ok=True)
        archive = output_dir / ARCHIVE_NAME
        checksum = output_dir / (ARCHIVE_NAME + '.sha256')
        # Same-directory temporary names avoid publishing a partially written ZIP.
        with tempfile.NamedTemporaryFile(dir=output_dir, delete=False) as output:
            temporary_output = Path(output.name)
            try:
                output.write(staged.read_bytes())
            except BaseException:
                temporary_output.unlink(missing_ok=True)
                raise
        try:
            os.replace(temporary_output, archive)
        finally:
            temporary_output.unlink(missing_ok=True)
        checksum.write_text(f'{digest}  {ARCHIVE_NAME}\n')
    return archive, checksum


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--app', type=Path, default=Path(__file__).resolve().parent.parent / 'MailTrans.app')
    parser.add_argument('--output-dir', type=Path, default=Path('work/release'))
    args = parser.parse_args()
    try:
        archive, checksum = package_app(args.app, args.output_dir)
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        parser.exit(1, f'Packaging failed: {error}\n')
    print(f'Development build (ad-hoc, not notarized): {archive}\nSHA256: {checksum}')


if __name__ == '__main__':
    main()
