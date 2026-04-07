# ~/University/scripts/bb_sync/test_syncer.py
import sys
import unittest
import tempfile
from pathlib import Path
from unittest.mock import MagicMock, patch
sys.path.insert(0, '.')
from syncer import Syncer

class TestSyncer(unittest.TestCase):
    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.client = MagicMock()

    def test_skips_existing_file(self):
        dest = Path(self.tmpdir) / "week1.pdf"
        dest.write_bytes(b"existing")
        syncer = Syncer(self.client, self.tmpdir)
        syncer._download_attachment(
            course_id="_1_1",
            content_id="_10_1",
            attachment={"id": "_99_1", "fileName": "week1.pdf"},
            dest_dir=self.tmpdir
        )
        self.client.download_url.assert_not_called()

    def test_downloads_missing_file(self):
        dest = Path(self.tmpdir) / "new.pdf"
        self.assertFalse(dest.exists())

        fake_response = MagicMock()
        fake_response.iter_content = MagicMock(return_value=[b"data"])
        fake_response.raise_for_status = MagicMock()
        fake_response.__enter__ = MagicMock(return_value=fake_response)
        fake_response.__exit__ = MagicMock(return_value=False)

        self.client.download_url.return_value = "https://fake/download"
        self.client._cookies = {}
        syncer = Syncer(self.client, self.tmpdir)

        with patch('syncer.requests.Session') as mock_session:
            mock_session.return_value.__enter__ = MagicMock(return_value=mock_session.return_value)
            mock_session.return_value.__exit__ = MagicMock(return_value=False)
            mock_session.return_value.get.return_value = fake_response
            syncer._download_attachment(
                course_id="_1_1",
                content_id="_10_1",
                attachment={"id": "_99_1", "fileName": "new.pdf"},
                dest_dir=self.tmpdir
            )

        self.assertTrue(dest.exists())

    def test_sync_course_creates_folder(self):
        """sync_course creates the local folder if it doesn't exist."""
        import os
        new_folder = os.path.join(self.tmpdir, "FN585")
        self.client.get_contents.return_value = []
        syncer = Syncer(self.client, self.tmpdir)
        syncer.sync_course("_1_1", "FN585 - Corporate Finance", new_folder)
        self.assertTrue(os.path.isdir(new_folder))

if __name__ == '__main__':
    unittest.main()
