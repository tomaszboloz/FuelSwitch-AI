import base64
from pathlib import Path
import plistlib
import stat
import tempfile
import unittest
import zipfile

from update_feed import APP, FEED, PUBLIC_KEY, generate, promote, release_identity


class UpdateFeedTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.archive = Path(self.directory.name) / "FuelSwitch-AI.zip"
        self.signature = base64.b64encode(bytes(64)).decode()

    def bundle(self, build="8", version="1.1.1", symlinks=True, key=PUBLIC_KEY):
        info = {
            "CFBundleVersion": build, "CFBundleShortVersionString": version,
            "CFBundleIdentifier": "ai.fuelswitch.app", "SUPublicEDKey": key,
            "SUFeedURL": FEED, "LSMinimumSystemVersion": "13.0",
        }
        with zipfile.ZipFile(self.archive, "w") as package:
            package.writestr(APP + "Info.plist", plistlib.dumps(info))
            for link in ["Sparkle", "Versions/Current", "Resources"]:
                entry = zipfile.ZipInfo(APP + "Frameworks/Sparkle.framework/" + link)
                entry.create_system = 3
                entry.external_attr = ((stat.S_IFLNK if symlinks else stat.S_IFREG) | 0o755) << 16
                package.writestr(entry, "B" if link == "Versions/Current" else "Versions/Current/" + link)
        return generate(self.archive, self.signature, "v" + version)

    def test_feed_matches_exact_archive_and_bundle(self):
        build, version, enclosure = release_identity(self.bundle())
        self.assertEqual((build, version), (8, "1.1.1"))
        self.assertEqual(int(enclosure["length"]), self.archive.stat().st_size)
        self.assertTrue(enclosure["url"].endswith("/v1.1.1/FuelSwitch-AI.zip"))

    def test_old_zip_packaging_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "symlinks"):
            self.bundle(symlinks=False)

    def test_tag_mismatch_is_rejected(self):
        self.bundle()
        with self.assertRaisesRegex(ValueError, "tag"):
            generate(self.archive, self.signature, "v1.1.0")

    def test_missing_signature_is_rejected(self):
        self.bundle()
        with self.assertRaisesRegex(ValueError, "signature"):
            generate(self.archive, "", "v1.1.1")

    def test_different_key_cannot_break_old_installations(self):
        with self.assertRaisesRegex(ValueError, "compatible"):
            self.bundle(key="different-key")

    def test_missing_build_number_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "build"):
            self.bundle(build="")

    def test_new_feed_replaces_old_feed(self):
        old = self.bundle(build="6", version="1.0.5")
        new = self.bundle()
        self.assertEqual(promote(new, old), new)

    def test_out_of_order_release_cannot_roll_back_feed(self):
        old = self.bundle(build="6", version="1.0.5")
        new = self.bundle()
        self.assertEqual(promote(old, new), new)

    def test_retry_is_idempotent(self):
        feed = self.bundle()
        self.assertEqual(promote(feed, feed), feed)

    def test_reused_build_with_changed_release_is_rejected(self):
        old = self.bundle()
        new = self.bundle(version="1.1.2")
        with self.assertRaisesRegex(ValueError, "already published"):
            promote(new, old)


if __name__ == "__main__":
    unittest.main()
