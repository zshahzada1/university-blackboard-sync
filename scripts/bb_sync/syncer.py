import re
import requests
from pathlib import Path
from .bb_client import BlackboardClient


def _safe_name(name: str) -> str:
    """Sanitise a Blackboard title for use as a folder/file name."""
    return re.sub(r'[<>:"/\\|?*]', '_', name).strip().rstrip('.')


class Syncer:
    def __init__(self, client: BlackboardClient, local_root: str):
        self._client = client
        self._root = Path(local_root)

    def sync_course(self, course_id: str, course_name: str, local_folder: str):
        """Sync all content for one course into local_folder (absolute path)."""
        dest = Path(local_folder)
        dest.mkdir(parents=True, exist_ok=True)
        print(f"  Syncing course: {course_name} → {dest}")
        contents = self._client.get_contents(course_id)
        self._walk_contents(course_id, contents, dest)

    def _walk_contents(self, course_id: str, contents: list, dest: Path):
        for item in contents:
            title = _safe_name(item.get("title", "Untitled"))
            if self._client.is_folder(item):
                folder_dest = dest / title
                folder_dest.mkdir(parents=True, exist_ok=True)
                children = self._client.get_contents(course_id, item["id"])
                self._walk_contents(course_id, children, folder_dest)
            else:
                attachments = self._client.get_attachments(course_id, item["id"])
                for att in attachments:
                    self._download_attachment(course_id, item["id"], att, str(dest))

    def _download_attachment(self, course_id: str, content_id: str,
                              attachment: dict, dest_dir: str):
        filename = _safe_name(attachment.get("fileName", attachment["id"]))
        dest_path = Path(dest_dir) / filename
        if dest_path.exists():
            print(f"    [skip] {filename}")
            return
        url = self._client.download_url(course_id, content_id, attachment["id"])
        print(f"    [download] {filename}")
        tmp_path = dest_path.with_suffix(dest_path.suffix + ".tmp")
        try:
            with requests.Session() as s:
                s.cookies.update(self._client._cookies)
                with s.get(url, stream=True, allow_redirects=True, timeout=60) as resp:
                    resp.raise_for_status()
                    with open(tmp_path, "wb") as f:
                        for chunk in resp.iter_content(chunk_size=8192):
                            f.write(chunk)
            tmp_path.rename(dest_path)
        except Exception:
            tmp_path.unlink(missing_ok=True)
            raise
