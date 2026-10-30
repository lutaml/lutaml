"""Probe the exact vendor homepage without treating arbitrary 403s as success."""
import sys
import urllib.error
import urllib.request

VENDOR_URL = "https://sparxsystems.com/"


def classify(url, status, headers):
    if url != VENDOR_URL:
        raise ValueError("Unexpected vendor URL or redirect target")
    if 200 <= status < 300:
        return "reachable"
    normalized = {key.lower(): value.strip().lower() for key, value in headers.items()}
    if status == 403 and normalized.get("cf-mitigated") == "challenge":
        return "automated access blocked; availability unverified"
    raise ValueError(f"Vendor link returned unaccepted HTTP {status}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, message, headers, new_url):
        return None


def self_test():
    assert classify(VENDOR_URL, 200, {}) == "reachable"
    assert "unverified" in classify(VENDOR_URL, 403, {"CF-Mitigated": "challenge"})
    for url, status, headers in [
        (VENDOR_URL, 403, {}),
        (VENDOR_URL, 403, {"cf-mitigated": "other"}),
        (VENDOR_URL, 404, {"cf-mitigated": "challenge"}),
        ("https://unrelated.example/", 403, {"cf-mitigated": "challenge"}),
        ("https://sparxsystems.com/missing", 200, {}),
        (VENDOR_URL, 302, {}),
    ]:
        try:
            classify(url, status, headers)
        except ValueError:
            continue
        raise AssertionError((url, status, headers))
    print("Vendor policy controls passed: 2 positive, 6 negative")


def probe():
    opener = urllib.request.build_opener(NoRedirect())
    request = urllib.request.Request(VENDOR_URL, headers={"User-Agent": "Lutaml-docs-link-check"})
    try:
        response = opener.open(request, timeout=30)
    except urllib.error.HTTPError as response:
        result = classify(response.geturl(), response.code, response.headers)
    else:
        with response:
            result = classify(response.geturl(), response.status, response.headers)
    if "unverified" in result:
        print(f"::notice title=Vendor link availability::{VENDOR_URL}: {result}")
    else:
        print(f"Verified vendor homepage: {VENDOR_URL}")


if __name__ == "__main__":
    try:
        self_test() if sys.argv[1:] == ["--self-test"] else probe()
    except (ValueError, OSError, urllib.error.URLError) as error:
        sys.exit(str(error))
