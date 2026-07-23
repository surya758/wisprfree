#!/bin/zsh
# Cut a WisprFree release: build, zip, sign for Sparkle, update the appcast,
# tag, and publish to GitHub.
#
#   ./release.sh "Release notes go here (markdown)."
#
# Reads the version from project.yml (bump it there first). Requires gh and
# the Sparkle sign_update tool (from the resolved SwiftPM artifacts).
set -e
cd "$(dirname "$0")"

NOTES="${1:-}"
VERSION=$(grep -m1 CFBundleShortVersionString project.yml | sed 's/.*"\(.*\)".*/\1/')
BUILD=$(grep -m1 CFBundleVersion project.yml | sed 's/.*"\(.*\)".*/\1/')
TAG="v$VERSION"
ZIP="WisprFree-$VERSION.zip"
REPO="surya758/wisprfree"
FEED_BASE="https://github.com/$REPO/releases/download/$TAG"

echo "▸ Building $VERSION ($BUILD)…"
xcodegen >/dev/null
xcodebuild -project WisprFree.xcodeproj -scheme WisprFree -configuration Release build | grep -E "error:|BUILD" || true

APP=$(ls -d ~/Library/Developer/Xcode/DerivedData/WisprFree-*/Build/Products/Release/WisprFree.app | head -1)
DIST=$(mktemp -d)
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/$ZIP"

echo "▸ Signing update…"
SIGN=$(ls ~/Library/Developer/Xcode/DerivedData/WisprFree-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update | head -1)
SIGINFO=$("$SIGN" "$DIST/$ZIP")   # -> sparkle:edSignature="..." length="..."
echo "  $SIGINFO"

PUBDATE=$(date -u "+%a, %d %b %Y %H:%M:%S +0000")

echo "▸ Prepending appcast item…"
ITEM="        <item>
            <title>$VERSION</title>
            <pubDate>$PUBDATE</pubDate>
            <sparkle:version>$BUILD</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <description><![CDATA[$NOTES]]></description>
            <enclosure url=\"$FEED_BASE/$ZIP\" $SIGINFO type=\"application/octet-stream\" />
        </item>"

python3 - "$ITEM" <<'PY'
import sys, os
item = sys.argv[1]
path = "appcast.xml"
header = '''<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>WisprFree</title>
'''
footer = '''    </channel>
</rss>
'''
existing = ""
if os.path.exists(path):
    body = open(path).read()
    start = body.find("<channel>")
    if start != -1:
        after = body[start+len("<channel>"):]
        # keep only <item>...</item> blocks
        import re
        existing = "".join(re.findall(r"[ ]*<item>.*?</item>\n", after, re.S))
open(path, "w").write(header + item + "\n" + existing + footer)
print("appcast.xml written")
PY

echo "▸ Tagging & publishing $TAG…"
git add appcast.xml project.yml
git commit -q -m "chore: release $VERSION" || true
git push origin main
git tag "$TAG" 2>/dev/null || true
git push origin "$TAG"
gh release create "$TAG" "$DIST/$ZIP" --title "WisprFree $VERSION" --notes "$NOTES"

echo "✓ Released $VERSION"
