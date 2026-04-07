BB_BASE_URL = "https://studentcentral.brighton.ac.uk"
LOCAL_ROOT = "/home/zo/University"
COOKIE_CACHE = "/home/zo/.cache/bb_sync/cookies.json"

# Maps Blackboard course name prefix → local subfolder name
# The script will auto-detect codes like FA565, FN585, FA583 from course titles.
# Add explicit overrides here if auto-detection misses one:
COURSE_OVERRIDES = {
    # "Some Long Course Name": "FA565",
}

# Regex to pull a module code from a BB course title, e.g. "FN585 - Corporate Finance"
import re
MODULE_CODE_RE = re.compile(r'\b([A-Z]{2,4}\d{3,4})\b')


def local_path_for_course(course_name: str) -> str:
    """Return the local folder name for a given Blackboard course name."""
    if course_name in COURSE_OVERRIDES:
        return COURSE_OVERRIDES[course_name]
    m = MODULE_CODE_RE.search(course_name)
    if m:
        return m.group(1)
    # Fallback: sanitise course name as folder
    return re.sub(r'[^\w\-]', '_', course_name).strip('_')
