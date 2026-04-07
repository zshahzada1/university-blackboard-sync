import requests
from .config import BB_BASE_URL

FOLDER_TYPES = {
    "resource/x-bb-folder",
    "resource/x-bb-coursetoc",
    "resource/x-bb-lesson",
}

class BlackboardClient:
    def __init__(self, cookies: dict):
        self._cookies = cookies
        self._base = BB_BASE_URL.rstrip("/")

    def _get(self, path: str, params: dict = None) -> dict:
        url = f"{self._base}{path}"
        with requests.Session() as s:
            s.cookies.update(self._cookies)
            resp = s.get(url, params=params or {}, allow_redirects=True, timeout=30)
            resp.raise_for_status()
            return resp.json()

    def get_current_user(self) -> dict:
        return self._get("/learn/api/public/v1/users/me")

    def get_courses(self, user_id: str) -> list:
        data = self._get(
            f"/learn/api/public/v1/users/{user_id}/courses",
            params={"limit": 200, "fields": "id,courseId,name,availability"}
        )
        return [
            c for c in data.get("results", [])
            if (c.get("availability") or {}).get("available") == "Yes"
        ]

    def get_contents(self, course_id: str, parent_id: str = None) -> list:
        if parent_id:
            path = f"/learn/api/public/v1/courses/{course_id}/contents/{parent_id}/children"
        else:
            path = f"/learn/api/public/v1/courses/{course_id}/contents"
        data = self._get(path, params={"limit": 200})
        return data.get("results", [])

    def get_attachments(self, course_id: str, content_id: str) -> list:
        data = self._get(
            f"/learn/api/public/v1/courses/{course_id}/contents/{content_id}/attachments"
        )
        return data.get("results", [])

    def download_url(self, course_id: str, content_id: str, attachment_id: str) -> str:
        return (
            f"{self._base}/learn/api/public/v1/courses/{course_id}"
            f"/contents/{content_id}/attachments/{attachment_id}/download"
        )

    def is_folder(self, content_item: dict) -> bool:
        handler = content_item.get("contentHandler", {}).get("id", "")
        return handler in FOLDER_TYPES
