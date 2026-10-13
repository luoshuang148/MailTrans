#!/usr/bin/env python3
"""Build a local, ad-hoc signed MailKit translator and embedded local-language helper."""
from pathlib import Path
import base64
from email import policy
from email.parser import BytesParser
from html.parser import HTMLParser
import os
import plistlib
import shutil
import struct
import subprocess
import zlib

source = Path(__file__).resolve().parent
out = source.parent
work = out.parent.parent / "work" / "mail-real"
work.mkdir(parents=True, exist_ok=True)
app = out / "Mail Translation Probe.app"
ext = app / "Contents" / "PlugIns" / "MailTranslationProbe.appex"
for directory in [app / "Contents/MacOS", app / "Contents/Resources", ext / "Contents/MacOS"]:
    directory.mkdir(parents=True, exist_ok=True)

def plist(path, value):
    path.write_bytes(plistlib.dumps(value, sort_keys=False))

plist(app / "Contents/Info.plist", {
    "CFBundleIdentifier": "local.codex.mailtranslationprobe",
    "CFBundleName": "邮件本地翻译",
    "CFBundleDisplayName": "邮件本地翻译",
    "CFBundleExecutable": "MailTranslationProbe",
    "CFBundlePackageType": "APPL",
    "CFBundleVersion": "7", "CFBundleShortVersionString": "0.7",
    "CFBundleIconFile": "AppIcon",
    "LSMinimumSystemVersion": "26.4", "NSHighResolutionCapable": True, "LSUIElement": True,
    "CFBundleURLTypes": [{"CFBundleURLName": "Mail Translation", "CFBundleURLSchemes": ["mailtranslationprobe"]}],
})
plist(ext / "Contents/Info.plist", {
    "CFBundleIdentifier": "local.codex.mailtranslationprobe.extension",
    "CFBundleName": "邮件本地翻译",
    "CFBundleDisplayName": "邮件本地翻译",
    "CFBundleExecutable": "MailTranslationProbeExtension",
    "CFBundlePackageType": "XPC!",
    "CFBundleVersion": "7", "CFBundleShortVersionString": "0.7",
    "NSExtension": {
        "NSExtensionPointIdentifier": "com.apple.email.extension",
        "NSExtensionPrincipalClass": "MailTranslationProbeExtension",
        "NSExtensionAttributes": {"MEExtensionCapabilities": ["MEMessageSecurityHandler"]},
    },
})
entitlements = work / "extension.entitlements"
plist(entitlements, {"com.apple.security.app-sandbox": True})

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
sample = out / "layout-sample.eml"
sample.write_bytes(fixture)
(app / "Contents/Resources/layout-sample.eml").write_bytes(fixture)

env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
def run(args):
    subprocess.run(args, env=env, check=True)

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
                       stdout=subprocess.DEVNULL)
icon_icns = work / "AppIcon.icns"
run(["/usr/bin/iconutil", "-c", "icns", str(iconset), "-o", str(icon_icns)])
shutil.copyfile(icon_icns, app / "Contents/Resources/AppIcon.icns")

sdk = subprocess.check_output(["/usr/bin/xcrun", "--sdk", "macosx", "--show-sdk-path"], env=env, text=True).strip()
compiler = ["/usr/bin/xcrun", "--sdk", "macosx", "clang", "-fobjc-arc", "-fblocks", "-Wall", "-Wextra",
    "-Wno-unused-parameter", "-Wno-incompatible-pointer-types", "-mmacosx-version-min=26.4", "-isysroot", sdk,
    "-I"+sdk+"/usr/include/libxml2", "-lxml2", "-framework", "Cocoa", "-framework", "MailKit", "-framework", "NaturalLanguage"]
core = str(source / "MIMECore.m")
run(compiler + [core, str(source / "CoreTests.m"), "-o", str(work / "core-tests")])
run([str(work / "core-tests")])
run(compiler + [core, str(source / "AppTests.m"), "-o", str(work / "app-tests")])
run([str(work / "app-tests")])
run(compiler + [core, str(source / "ExtensionTests.m"), "-o", str(work / "extension-tests")])
run([str(work / "extension-tests")])
run(compiler + ["-fapplication-extension", "-Xlinker", "-e", "-Xlinker", "_NSExtensionMain",
    core, str(source / "ProbeExtension.m"), "-o", str(ext / "Contents/MacOS/MailTranslationProbeExtension")])
run(compiler + [core, str(source / "ProbeApp.m"), "-o", str(app / "Contents/MacOS/MailTranslationProbe")])
swift = ["/usr/bin/xcrun", "swiftc", "-parse-as-library", "-target", "arm64-apple-macos26.4"]
run(swift + [str(source / "TranslationProvider.swift"), str(source / "TranslationWorker.swift"),
    "-o", str(app / "Contents/MacOS/TranslationWorker")])
helper = app / "Contents/Helpers/LanguageSetup.app"
(helper / "Contents/MacOS").mkdir(parents=True, exist_ok=True)
plist(helper / "Contents/Info.plist", {
    "CFBundleIdentifier": "local.codex.mailtranslationprobe.languages",
    "CFBundleName": "本地翻译语言包", "CFBundleExecutable": "LanguageSetup", "CFBundlePackageType": "APPL",
    "CFBundleVersion": "7", "CFBundleShortVersionString": "0.7", "LSMinimumSystemVersion": "26.4",
    "NSHighResolutionCapable": True,
})
run(swift + [str(source / "LanguageSetup.swift"), "-o", str(helper / "Contents/MacOS/LanguageSetup")])
# Documents may be managed by FileProvider, which adds FinderInfo to newly
# created .app/.appex directories. Code signing rejects that metadata. Remove
# only the two signing-incompatible attributes on this generated artifact;
# keep provenance, quarantine and all other security attributes untouched.
def clean_signing_metadata():
    attributes = subprocess.check_output(["/usr/bin/xattr", "-lr", str(app)])
    for attribute in ("com.apple.FinderInfo", "com.apple.ResourceFork"):
        if attribute.encode() in attributes:
            run(["/usr/bin/xattr", "-dr", attribute, str(app)])
for target, extra in [(ext, ["--entitlements", str(entitlements)]), (helper, []),
                      (app / "Contents/MacOS/TranslationWorker", []), (app, [])]:
    for attempt in range(3):
        clean_signing_metadata()
        result = subprocess.run(["/usr/bin/codesign", "--force", "--sign", "-"] + extra + [str(target)], env=env)
        if result.returncode == 0:
            break
    else:
        raise RuntimeError(f"Could not sign {target}")
for attempt in range(5):
    clean_signing_metadata()
    verification = subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", "--verbose=2", str(app)], env=env, capture_output=True, text=True)
    if verification.returncode == 0:
        print(verification.stderr.strip())
        break
    if "FinderInfo" not in verification.stderr and "resource fork" not in verification.stderr:
        raise RuntimeError(verification.stderr)
else:
    raise RuntimeError(verification.stderr)

(work / "build-verification.txt").write_text(
    "Compilation: passed\nAd-hoc signature verification: passed\nCore tests: passed\n"
    "Mail rendering and live local translation: require separate UI verification\n")
print(f"Built: {app}")
