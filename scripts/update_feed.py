"""Generate/promote the Sparkle feed only for a complete signed release ZIP."""
import argparse
import base64
from datetime import datetime, timezone
from email.utils import format_datetime
from pathlib import Path
import plistlib
import re
import stat
import xml.etree.ElementTree as ET
import zipfile

SPARKLE = "http://www.andymatuschak.org/xml-namespaces/sparkle"
RELEASES = "https://github.com/tomaszboloz/FuelSwitch-AI/releases/download/"
FEED = "https://raw.githubusercontent.com/tomaszboloz/FuelSwitch-AI/main/appcast.xml"
PUBLIC_KEY = "Y4RQVuLHDPbJtgIlQwu6ApQBtyQca87bETg3Y4do4sk="
APP = "FuelSwitch AI.app/Contents/"
ET.register_namespace("sparkle", SPARKLE)


def sparkle(name):
    return f"{{{SPARKLE}}}{name}"


def generate(archive, signature, tag):
    if len(base64.b64decode(signature, validate=True)) != 64:
        raise ValueError("Invalid EdDSA signature length")
    with zipfile.ZipFile(archive) as package:
        info = plistlib.loads(package.read(APP + "Info.plist"))
        # zip -r follows these symlinks, producing an invalid signed framework.
        for link in ["Sparkle", "Versions/Current", "Resources"]:
            entry = package.getinfo(APP + "Frameworks/Sparkle.framework/" + link)
            if not stat.S_ISLNK(entry.external_attr >> 16):
                raise ValueError("ZIP did not preserve Sparkle framework symlinks")
    version = info["CFBundleShortVersionString"]
    build = info["CFBundleVersion"]
    if not re.fullmatch(r"\d+\.\d+\.\d+", version) or tag != "v" + version:
        raise ValueError("Release tag must match the bundled application version")
    if not str(build).isdigit() or int(build) < 1:
        raise ValueError("Invalid bundle build number")
    if info.get("SUPublicEDKey") != PUBLIC_KEY or info.get("SUFeedURL") != FEED:
        raise ValueError("Update key/feed must remain compatible with installed apps")
    if info.get("CFBundleIdentifier") != "ai.fuelswitch.app":
        raise ValueError("Wrong application bundle")
    root = ET.Element("rss", version="2.0")
    channel = ET.SubElement(root, "channel")
    ET.SubElement(channel, "title").text = "FuelSwitch AI"
    ET.SubElement(channel, "link").text = FEED
    ET.SubElement(channel, "description").text = "FuelSwitch AI updates"
    ET.SubElement(channel, "language").text = "en"
    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = "Version " + version
    ET.SubElement(item, "pubDate").text = format_datetime(datetime.now(timezone.utc), usegmt=True)
    ET.SubElement(item, sparkle("version")).text = str(build)
    ET.SubElement(item, sparkle("shortVersionString")).text = version
    ET.SubElement(item, sparkle("minimumSystemVersion")).text = info["LSMinimumSystemVersion"]
    ET.SubElement(item, "enclosure", {
        "url": RELEASES + tag + "/FuelSwitch-AI.zip",
        "length": str(Path(archive).stat().st_size),
        "type": "application/octet-stream",
        sparkle("edSignature"): signature,
    })
    ET.indent(root, space="    ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"


def release_identity(data):
    item = ET.fromstring(data).find("channel/item")
    if item is None:
        raise ValueError("Feed has no release")
    enclosure = item.find("enclosure")
    if enclosure is None:
        raise ValueError("Release has no archive")
    return (int(item.findtext(sparkle("version"))),
            item.findtext(sparkle("shortVersionString")), dict(enclosure.attrib))


def promote(candidate, current):
    new = release_identity(candidate)
    old = release_identity(current)
    if new[0] < old[0]:
        return current  # An older workflow finishing late must never downgrade the feed.
    if new[0] == old[0]:
        if new != old:
            raise ValueError("Build number already published with different metadata")
        return current  # Idempotent workflow retry, including a different pubDate.
    return candidate


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    create = commands.add_parser("generate")
    for name in ["archive", "signature", "tag", "output"]:
        create.add_argument(name)
    publish = commands.add_parser("promote")
    publish.add_argument("candidate")
    publish.add_argument("current")
    args = parser.parse_args()
    if args.command == "generate":
        Path(args.output).write_bytes(generate(args.archive, args.signature, args.tag))
    else:
        target = Path(args.current)
        result = promote(Path(args.candidate).read_bytes(), target.read_bytes())
        target.write_bytes(result)
