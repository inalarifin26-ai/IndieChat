#!/usr/bin/env python3
"""
Adds the platform permissions Indie needs to the Flutter platform folders that
`flutter create .` generates. Safe to run more than once (it never duplicates).

  python3 tool/add_platform_permissions.py                      # voice + network
  python3 tool/add_platform_permissions.py --allow-cleartext    # + plain-http dev server (Android, DEV ONLY)

Android  (android/app/src/main/AndroidManifest.xml)
  RECORD_AUDIO ........ voice input in chats
  INTERNET ............ talking to the backend (the default template only grants it in debug builds)
  <queries> intent .... lets the app find the system speech recogniser on Android 11+
  usesCleartextTraffic  only with --allow-cleartext, for http://10.0.2.2:4000 during development

iOS      (ios/Runner/Info.plist)
  NSMicrophoneUsageDescription, NSSpeechRecognitionUsageDescription
"""
import argparse, os, re, sys

ANDROID = 'android/app/src/main/AndroidManifest.xml'
IOS = 'ios/Runner/Info.plist'
PERM = '<uses-permission android:name="android.permission.%s"/>'
SPEECH_INTENT = '<intent>\n            <action android:name="android.speech.RecognitionService"/>\n        </intent>'
MIC_TEXT = 'Indie uses the microphone only while you hold or tap the mic button to dictate a message.'
SPEECH_TEXT = 'Indie turns your speech into text for chat messages. Audio is handled by your device and is never stored by Indie.'


def patch_android(src, allow_cleartext):
    changed = []
    for perm in ('RECORD_AUDIO', 'INTERNET'):
        if f'android.permission.{perm}' not in src:
            src = re.sub(r'(<manifest[^>]*>)', lambda m: m.group(1) + '\n    ' + PERM % perm, src, count=1)
            changed.append(perm)
    if 'android.speech.RecognitionService' not in src:
        if '</queries>' in src:
            src = src.replace('</queries>', '    ' + SPEECH_INTENT + '\n    </queries>', 1)
        else:
            src = src.replace('</manifest>', '    <queries>\n        ' + SPEECH_INTENT + '\n    </queries>\n</manifest>', 1)
        changed.append('speech <queries>')
    if allow_cleartext and 'usesCleartextTraffic' not in src:
        src = re.sub(r'<application', '<application\n        android:usesCleartextTraffic="true"', src, count=1)
        changed.append('usesCleartextTraffic (dev only!)')
    return src, changed


def patch_ios(src):
    changed = []
    add = ''
    for key, text in (('NSMicrophoneUsageDescription', MIC_TEXT), ('NSSpeechRecognitionUsageDescription', SPEECH_TEXT)):
        if f'<key>{key}</key>' not in src:
            add += f'\t<key>{key}</key>\n\t<string>{text}</string>\n'
            changed.append(key)
    if add:
        i = src.rindex('</dict>')
        src = src[:i] + add + src[i:]
    return src, changed


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--allow-cleartext', action='store_true', help='Android: allow http:// (development only)')
    ap.add_argument('--root', default='.', help='Flutter project root (default: current directory)')
    a = ap.parse_args()
    done = False
    for rel, fn in ((ANDROID, lambda s: patch_android(s, a.allow_cleartext)), (IOS, patch_ios)):
        path = os.path.join(a.root, rel)
        if not os.path.exists(path):
            print(f'skip  {rel} (not found — run `flutter create .` first)')
            continue
        src = open(path, encoding='utf8').read()
        out, changed = fn(src)
        if changed:
            open(path, 'w', encoding='utf8').write(out)
            print(f'patched {rel}: ' + ', '.join(changed))
        else:
            print(f'ok    {rel} (already up to date)')
        done = True
    sys.exit(0 if done else 1)


if __name__ == '__main__':
    main()
