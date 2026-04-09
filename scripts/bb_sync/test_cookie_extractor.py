import json
import sys
import unittest
from unittest.mock import patch, MagicMock
sys.path.insert(0, '.')
from cookie_extractor import extract_bb_cookies

class TestCookieExtractor(unittest.TestCase):
    def test_returns_dict_via_cdp_when_available(self):
        """extract_bb_cookies returns cookies from CDP when it succeeds."""
        cdp_cookies = {"BbRouter": "abc123", "JSESSIONID": "xyz"}
        with patch("cookie_extractor._extract_via_cdp", return_value=cdp_cookies):
            result = extract_bb_cookies(force_refresh=True)
        self.assertIsInstance(result, dict)
        self.assertIn("BbRouter", result)
        self.assertEqual(result["BbRouter"], "abc123")

    def test_falls_back_to_browser_cookie3_when_cdp_fails(self):
        """extract_bb_cookies falls back to browser_cookie3 when CDP raises."""
        fake_cookies = json.dumps({"BbRouter": "abc123", "JSESSIONID": "xyz"})
        with patch("cookie_extractor._extract_via_cdp", side_effect=RuntimeError("CDP unavailable")), \
             patch("cookie_extractor.Path.exists", return_value=False), \
             patch("cookie_extractor.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(returncode=0, stdout=fake_cookies, stderr="")
            result = extract_bb_cookies(force_refresh=True)
        self.assertIsInstance(result, dict)
        self.assertIn("BbRouter", result)

    def test_raises_when_all_methods_fail(self):
        """extract_bb_cookies raises RuntimeError when CDP and browser_cookie3 both fail."""
        with patch("cookie_extractor._extract_via_cdp", side_effect=RuntimeError("CDP unavailable")), \
             patch("cookie_extractor.subprocess.run") as mock_run:
            mock_run.return_value = MagicMock(
                returncode=1, stdout="", stderr="ModuleNotFoundError: No module named 'browser_cookie3'"
            )
            with self.assertRaises(RuntimeError):
                extract_bb_cookies(force_refresh=True)

class TestExtractViaCdp(unittest.TestCase):
    """Tests for the CDP-based cookie extraction path."""

    def _make_mock_get(self):
        """Return a side_effect function for requests.get that handles CDP URLs."""
        def side_effect(url, **kwargs):
            if "version" in url:
                m = MagicMock()
                m.status_code = 200
                return m
            if url.endswith("/json"):
                m = MagicMock()
                m.json.return_value = [
                    {
                        "type": "page",
                        "webSocketDebuggerUrl": "ws://localhost:9222/devtools/page/1",
                    }
                ]
                return m
            raise ValueError(f"Unexpected URL in mock: {url}")
        return side_effect

    def _make_mock_run(self, edge_pid="9999"):
        """Return a side_effect function for subprocess.run that handles all expected calls."""
        def side_effect(cmd, **kwargs):
            cmd_str = " ".join(str(c) for c in cmd)
            if "sudo" in cmd_str:
                return MagicMock(returncode=0, stdout="", stderr="")
            if "Start-Process" in cmd_str:
                return MagicMock(returncode=0, stdout=f"{edge_pid}\n", stderr="")
            # Stop-Process and other powershell calls return empty stdout
            return MagicMock(returncode=0, stdout="", stderr="")
        return side_effect

    def test_cdp_returns_bb_cookies_only(self):
        """_extract_via_cdp returns cookies filtered to the BB domain."""
        all_cookies_payload = json.dumps({
            "result": {
                "cookies": [
                    {"name": "BbRouter", "value": "tok123", "domain": "studentcentral.brighton.ac.uk"},
                    {"name": "JSESSIONID", "value": "sid456", "domain": "studentcentral.brighton.ac.uk"},
                    {"name": "unrelated", "value": "xyz", "domain": "google.com"},
                ]
            }
        })
        mock_ws = MagicMock()
        mock_ws.recv.return_value = all_cookies_payload

        from cookie_extractor import _extract_via_cdp
        with patch("cookie_extractor.subprocess.run", side_effect=self._make_mock_run()), \
             patch("cookie_extractor.requests.get", side_effect=self._make_mock_get()), \
             patch("cookie_extractor.websocket.WebSocket", return_value=mock_ws):
            result = _extract_via_cdp("studentcentral.brighton.ac.uk")

        self.assertEqual(result["BbRouter"], "tok123")
        self.assertEqual(result["JSESSIONID"], "sid456")
        self.assertNotIn("unrelated", result)

    def test_cdp_sudo_failure_raises(self):
        """_extract_via_cdp raises RuntimeError when sudo -v auth fails."""
        def sudo_fails(cmd, **kwargs):
            cmd_str = " ".join(str(c) for c in cmd)
            if "sudo" in cmd_str and "-v" in cmd_str:
                return MagicMock(returncode=1)
            return MagicMock(returncode=0)

        from cookie_extractor import _extract_via_cdp
        with patch("cookie_extractor.subprocess.run", side_effect=sudo_fails):
            with self.assertRaises(RuntimeError) as ctx:
                _extract_via_cdp("studentcentral.brighton.ac.uk")
        self.assertIn("sudo", str(ctx.exception).lower())

    def test_cdp_kills_edge_on_ws_error(self):
        """_extract_via_cdp kills Edge even when WebSocket raises."""
        mock_ws = MagicMock()
        mock_ws.connect.side_effect = OSError("connection refused")

        kill_calls = []

        def run_side_effect(cmd, **kwargs):
            cmd_str = " ".join(str(c) for c in cmd)
            if "Stop-Process" in cmd_str:
                kill_calls.append(cmd_str)
            if "Start-Process" in cmd_str:
                return MagicMock(returncode=0, stdout="8888\n", stderr="")
            return MagicMock(returncode=0, stdout="", stderr="")

        from cookie_extractor import _extract_via_cdp
        with patch("cookie_extractor.subprocess.run", side_effect=run_side_effect), \
             patch("cookie_extractor.requests.get", side_effect=self._make_mock_get()), \
             patch("cookie_extractor.websocket.WebSocket", return_value=mock_ws):
            with self.assertRaises(Exception):
                _extract_via_cdp("studentcentral.brighton.ac.uk")

        self.assertTrue(any("8888" in c for c in kill_calls), "Edge PID not killed on error")

    def test_cdp_kills_edge_on_poll_timeout(self):
        """_extract_via_cdp kills Edge and raises when CDP port never opens."""
        kill_calls = []

        def run_side_effect(cmd, **kwargs):
            cmd_str = " ".join(str(c) for c in cmd)
            if "Stop-Process" in cmd_str:
                kill_calls.append(cmd_str)
            if "Start-Process" in cmd_str:
                return MagicMock(returncode=0, stdout="7777\n", stderr="")
            return MagicMock(returncode=0, stdout="", stderr="")

        import requests as req_module

        from cookie_extractor import _extract_via_cdp
        with patch("cookie_extractor.subprocess.run", side_effect=run_side_effect), \
             patch("cookie_extractor.requests.get", side_effect=req_module.RequestException("refused")), \
             patch("cookie_extractor.time.sleep"):  # skip actual sleeping
            with self.assertRaises(RuntimeError) as ctx:
                _extract_via_cdp("studentcentral.brighton.ac.uk")

        self.assertIn("15 seconds", str(ctx.exception))
        self.assertTrue(any("7777" in c for c in kill_calls), "Edge PID not killed on timeout")


if __name__ == '__main__':
    unittest.main()
