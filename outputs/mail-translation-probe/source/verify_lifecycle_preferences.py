#!/usr/bin/env python3
"""Check real preference sharing between CLI, app, and nested helper contexts."""
from pathlib import Path
import plistlib
import shutil
import subprocess
import sys
import tempfile
import uuid

binary = Path(sys.argv[1]).resolve()
domain = "local.mailtrans.tests.preferences." + uuid.uuid4().hex
key = "MTManualQuitMailSession"


def run(executable, action, value):
    subprocess.run([str(executable), domain, action, key, value], check=True)


with tempfile.TemporaryDirectory(prefix="mailtrans-preferences-") as folder:
    app = Path(folder) / "PreferencesFixture.app"
    mac = app / "Contents/MacOS"
    mac.mkdir(parents=True)
    main = mac / "PreferencesFixture"
    helper = mac / "HelperPreferences"
    for target in (main, helper):
        shutil.copyfile(binary, target)
        target.chmod(0o755)
    (app / "Contents/Info.plist").write_bytes(plistlib.dumps({
        "CFBundleIdentifier": domain, "CFBundleExecutable": main.name,
        "CFBundlePackageType": "APPL", "CFBundleVersion": "1", "LSUIElement": True,
    }))
    subprocess.run(["/usr/bin/codesign", "--sign", "-", str(helper)], check=True)
    subprocess.run(["/usr/bin/codesign", "--sign", "-", str(app)], check=True)
    try:
        run(binary, "write", "mail-session-one")
        run(main, "read", "mail-session-one")
        run(helper, "read", "mail-session-one")
        run(main, "write", "mail-session-two")
        run(binary, "read", "mail-session-two")
        run(helper, "write", "mail-session-three")
        run(binary, "read", "mail-session-three")
    finally:
        run(binary, "clean", "")
print("PASS: manual-quit preferences shared across CLI, app bundle and nested helper processes")
