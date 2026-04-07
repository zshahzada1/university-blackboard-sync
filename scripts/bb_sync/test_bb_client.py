# ~/University/scripts/bb_sync/test_bb_client.py
import sys
import unittest
from unittest.mock import patch, MagicMock
sys.path.insert(0, '.')
from bb_client import BlackboardClient

MOCK_ME = {"id": "_123_1", "userName": "student1"}
MOCK_COURSES = {"results": [
    {"id": "_1_1", "courseId": "FN585", "name": "FN585 - Corporate Finance", "availability": {"available": "Yes"}},
    {"id": "_2_1", "courseId": "FA565", "name": "FA565 - Financial Accounting", "availability": {"available": "Yes"}},
]}
MOCK_CONTENTS = {"results": [
    {"id": "_10_1", "title": "Week 1 Slides", "contentHandler": {"id": "resource/x-bb-folder"}},
    {"id": "_11_1", "title": "Assignment Brief", "contentHandler": {"id": "resource/x-bb-document"}},
]}
MOCK_ATTACHMENTS = {"results": [
    {"id": "_99_1", "fileName": "week1.pdf", "mimeType": "application/pdf"}
]}

class TestBlackboardClient(unittest.TestCase):
    def _make_client(self):
        return BlackboardClient({"BbRouter": "fake", "JSESSIONID": "fake"})

    def test_get_current_user(self):
        client = self._make_client()
        with patch('bb_client.requests.Session') as mock_session:
            mock_resp = MagicMock()
            mock_resp.json.return_value = MOCK_ME
            mock_resp.raise_for_status = MagicMock()
            mock_session.return_value.__enter__ = MagicMock(return_value=mock_session.return_value)
            mock_session.return_value.__exit__ = MagicMock(return_value=False)
            mock_session.return_value.get.return_value = mock_resp
            user = client.get_current_user()
        self.assertEqual(user["id"], "_123_1")

    def test_get_courses(self):
        client = self._make_client()
        with patch('bb_client.requests.Session') as mock_session:
            mock_resp = MagicMock()
            mock_resp.json.return_value = MOCK_COURSES
            mock_resp.raise_for_status = MagicMock()
            mock_session.return_value.__enter__ = MagicMock(return_value=mock_session.return_value)
            mock_session.return_value.__exit__ = MagicMock(return_value=False)
            mock_session.return_value.get.return_value = mock_resp
            courses = client.get_courses("_123_1")
        self.assertEqual(len(courses), 2)
        self.assertEqual(courses[0]["courseId"], "FN585")

    def test_get_contents(self):
        client = self._make_client()
        with patch('bb_client.requests.Session') as mock_session:
            mock_resp = MagicMock()
            mock_resp.json.return_value = MOCK_CONTENTS
            mock_resp.raise_for_status = MagicMock()
            mock_session.return_value.__enter__ = MagicMock(return_value=mock_session.return_value)
            mock_session.return_value.__exit__ = MagicMock(return_value=False)
            mock_session.return_value.get.return_value = mock_resp
            contents = client.get_contents("_1_1")
        self.assertEqual(len(contents), 2)

    def test_get_attachments(self):
        client = self._make_client()
        with patch('bb_client.requests.Session') as mock_session:
            mock_resp = MagicMock()
            mock_resp.json.return_value = MOCK_ATTACHMENTS
            mock_resp.raise_for_status = MagicMock()
            mock_session.return_value.__enter__ = MagicMock(return_value=mock_session.return_value)
            mock_session.return_value.__exit__ = MagicMock(return_value=False)
            mock_session.return_value.get.return_value = mock_resp
            attachments = client.get_attachments("_1_1", "_10_1")
        self.assertEqual(attachments[0]["fileName"], "week1.pdf")

    def test_is_folder(self):
        client = self._make_client()
        folder_item = {"contentHandler": {"id": "resource/x-bb-folder"}}
        doc_item = {"contentHandler": {"id": "resource/x-bb-document"}}
        self.assertTrue(client.is_folder(folder_item))
        self.assertFalse(client.is_folder(doc_item))

    def test_download_url_format(self):
        client = self._make_client()
        url = client.download_url("_1_1", "_10_1", "_99_1")
        self.assertIn("studentcentral.brighton.ac.uk", url)
        self.assertIn("_1_1", url)
        self.assertIn("_99_1", url)

if __name__ == '__main__':
    unittest.main()
