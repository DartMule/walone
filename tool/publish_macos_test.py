import base64
from pathlib import Path
import plistlib
import tempfile
import unittest
import xml.etree.ElementTree as ET

from tool import publish_macos as release


class PublicationTest(unittest.TestCase):
    def test_metadata_rejects_wrong_feed_key_and_build(self):
        with tempfile.TemporaryDirectory() as temporary:
            app = Path(temporary) / 'Walone.app'
            (app / 'Contents').mkdir(parents=True)
            metadata = {
                'CFBundleIdentifier': release.BUNDLE_ID,
                'CFBundleShortVersionString': '0.1.0',
                'CFBundleVersion': '1',
                'SUFeedURL': release.FEED_URL,
                'SUPublicEDKey': base64.b64encode(bytes(32)).decode(),
            }
            for changed in [{}, {'SUFeedURL': 'https://example.com/appcast.xml'},
                            {'SUPublicEDKey': 'placeholder'}, {'CFBundleVersion': '0'},
                            {'CFBundleShortVersionString': '../1'}]:
                with self.subTest(changed=changed):
                    (app / 'Contents/Info.plist').write_bytes(plistlib.dumps(metadata | changed))
                    if changed:
                        with self.assertRaises(RuntimeError):
                            release.read_metadata(app)
                    else:
                        self.assertEqual(release.read_metadata(app)[1:], ('0.1.0', 1))

    def test_appcast_requires_matching_build_url_length_and_signature(self):
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            archive = directory / 'Walone-0.1.0-1-macos.dmg'
            archive.write_bytes(b'archive')
            feed = directory / 'appcast.xml'
            root = ET.Element('rss')
            item = ET.SubElement(ET.SubElement(root, 'channel'), 'item')
            version = ET.SubElement(item, f'{{{release.SPARKLE_NAMESPACE}}}version')
            version.text = '1'
            attributes = {
                'url': f'https://github.com/{release.REPOSITORY}/releases/download/v0.1.0/{archive.name}',
                'length': str(archive.stat().st_size),
                f'{{{release.SPARKLE_NAMESPACE}}}edSignature': 'signature',
            }
            enclosure = ET.SubElement(item, 'enclosure', attributes)
            ET.ElementTree(root).write(feed)
            release.validate_feed(feed, '0.1.0', 1, archive)
            for key, value in [('url', 'https://example.com/app.dmg'), ('length', '0'),
                               (f'{{{release.SPARKLE_NAMESPACE}}}edSignature', '')]:
                enclosure.attrib = attributes | {key: value}
                ET.ElementTree(root).write(feed)
                with self.subTest(key=key), self.assertRaises(RuntimeError):
                    release.validate_feed(feed, '0.1.0', 1, archive)
            enclosure.attrib = attributes
            version.text = '2'
            ET.ElementTree(root).write(feed)
            with self.assertRaises(RuntimeError):
                release.validate_feed(feed, '0.1.0', 1, archive)


if __name__ == '__main__':
    unittest.main()
