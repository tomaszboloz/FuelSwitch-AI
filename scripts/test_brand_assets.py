"""Keep shipped brand assets tied to the approved design source."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BrandAssetTests(unittest.TestCase):
    def test_app_icon_matches_approved_design(self):
        self.assertEqual((ROOT / "Resources/AppIcon.icns").read_bytes(),
                         (ROOT / "design/macos-native-v2/FuelSwitch.icns").read_bytes())

    def test_favicon_matches_approved_design(self):
        self.assertEqual((ROOT / "Resources/favicon.png").read_bytes(),
                         (ROOT / "design/macos-native-v2/png/icon_32x32.png").read_bytes())

    def test_build_packages_shared_favicon(self):
        makefile = (ROOT / "Makefile").read_text()
        self.assertIn("cp Resources/favicon.png $(APP)/Contents/Resources/favicon.png", makefile)
        self.assertNotIn("swift Tools/make-icon.swift", makefile)


if __name__ == "__main__":
    unittest.main()
