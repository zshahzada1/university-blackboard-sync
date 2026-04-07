# scripts/bb_sync/test_main_filter.py
import sys
import importlib
import unittest
from unittest.mock import MagicMock, patch

sys.path.insert(0, '.')


class TestMainFilter(unittest.TestCase):
    def setUp(self):
        sys.modules.pop('bb_sync_main', None)

    def tearDown(self):
        sys.modules.pop('bb_sync_main', None)

    def test_unlisted_course_is_not_synced(self):
        """Courses outside SYNC_MODULES must not be passed to syncer.sync_course."""
        mock_client = MagicMock()
        mock_client.get_current_user.return_value = {"id": "u1", "userName": "testuser"}
        mock_client.get_courses.return_value = [
            {"id": "_1_1", "name": "BY150 - Introduction to Business"},
            {"id": "_2_1", "name": "FN585 - Corporate Finance"},
        ]
        mock_syncer = MagicMock()

        # Load the module fresh so patches bind into its namespace
        import importlib.util, pathlib
        spec = importlib.util.spec_from_file_location(
            'bb_sync_main',
            pathlib.Path(__file__).parent / '__main__.py'
        )
        main_mod = importlib.util.module_from_spec(spec)
        sys.modules['bb_sync_main'] = main_mod
        spec.loader.exec_module(main_mod)

        with patch('bb_sync_main.extract_bb_cookies', return_value={}), \
             patch('bb_sync_main.BlackboardClient', return_value=mock_client), \
             patch('bb_sync_main.Syncer', return_value=mock_syncer):
            main_mod.main()

        synced_names = [
            call.args[1] for call in mock_syncer.sync_course.call_args_list
        ]
        self.assertNotIn("BY150 - Introduction to Business", synced_names)
        self.assertIn("FN585 - Corporate Finance", synced_names)


if __name__ == '__main__':
    unittest.main()
