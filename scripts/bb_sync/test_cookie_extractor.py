import json
import sys
import unittest
from unittest.mock import patch, MagicMock
sys.path.insert(0, '.')
from cookie_extractor import extract_bb_cookies

class TestCookieExtractor(unittest.TestCase):
    def test_returns_dict_of_cookies(self):
        fake_cookies = json.dumps({"BbRouter": "abc123", "JSESSIONID": "xyz"})
        with patch('cookie_extractor.subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(
                returncode=0,
                stdout=fake_cookies,
                stderr=""
            )
            result = extract_bb_cookies()
        self.assertIsInstance(result, dict)
        self.assertIn("BbRouter", result)
        self.assertEqual(result["BbRouter"], "abc123")

    def test_raises_on_subprocess_failure(self):
        with patch('cookie_extractor.subprocess.run') as mock_run:
            mock_run.return_value = MagicMock(
                returncode=1,
                stdout="",
                stderr="ModuleNotFoundError: No module named 'browser_cookie3'"
            )
            with self.assertRaises(RuntimeError):
                extract_bb_cookies(force_refresh=True)

if __name__ == '__main__':
    unittest.main()
