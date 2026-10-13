#!/usr/bin/env python3
"""Enable, disable, or inspect MailTrans's per-user Mail lifecycle watcher."""
import argparse
import os
from pathlib import Path
import plistlib
import subprocess

LABEL = "local.codex.mailtranslationprobe.lifecycle"
BUNDLE_ID = "local.codex.mailtranslationprobe"
LAUNCHCTL = "/bin/launchctl"


def loaded(service):
    return subprocess.run([LAUNCHCTL, "print", service], capture_output=True).returncode == 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("enable", "disable", "status"))
    parser.add_argument("--app", type=Path, default=Path("/Applications/MailTrans.app"))
    args = parser.parse_args()
    service = f"gui/{os.getuid()}/{LABEL}"
    destination = Path.home() / "Library/LaunchAgents" / f"{LABEL}.plist"
    if args.action == "status":
        active = loaded(service)
        print(f"MailTrans automatic lifecycle: {'enabled' if active else 'not running'}")
        print(f"LaunchAgent installed: {destination.is_file()}")
        return
    if args.action == "enable":
        app = args.app.resolve(strict=True)
        info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
        executable = app / "Contents/MacOS/MailTransLifecycle"
        if info.get("CFBundleIdentifier") != BUNDLE_ID or not os.access(executable, os.X_OK):
            raise SystemExit("This app is not a compatible MailTrans installation.")
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True)
        definition = {
            "Label": LABEL,
            "ProgramArguments": [str(executable)],
            "RunAtLoad": True,
            "KeepAlive": True,
            "ThrottleInterval": 10,
            "ProcessType": "Background",
            "LimitLoadToSessionType": "Aqua",
            "AssociatedBundleIdentifiers": [BUNDLE_ID],
        }
        if loaded(service):
            subprocess.run([LAUNCHCTL, "bootout", service], check=True)
        destination.parent.mkdir(parents=True, exist_ok=True)
        temporary = destination.with_suffix(".plist.tmp")
        temporary.write_bytes(plistlib.dumps(definition))
        temporary.chmod(0o644)
        temporary.replace(destination)
        subprocess.run([LAUNCHCTL, "enable", service], check=True)
        subprocess.run([LAUNCHCTL, "bootstrap", f"gui/{os.getuid()}", str(destination)], check=True)
        print("Enabled: MailTrans follows Mail; its invisible watcher stays ready for the next launch.")
    else:
        if loaded(service):
            subprocess.run([LAUNCHCTL, "bootout", service], check=True)
        destination.unlink(missing_ok=True)
        print("Disabled: removed the MailTrans lifecycle LaunchAgent.")


if __name__ == "__main__":
    main()
