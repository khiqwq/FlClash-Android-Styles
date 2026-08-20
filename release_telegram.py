import os
import json
import mimetypes
import uuid
from urllib import request

TELEGRAM_BOT_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
TAG = os.getenv("TAG")
RUN_ID = os.getenv("RUN_ID")

IS_STABLE = "-" not in TAG

CHAT_ID = "@FlClash"
API_URL = f"http://localhost:8081/bot{TELEGRAM_BOT_TOKEN}/sendMediaGroup"

DIST_DIR = os.path.join(os.getcwd(), "dist")
release = os.path.join(os.getcwd(), "release.md")

text = ""

media = []
files = {}

i = 1

releaseKeywords = [
    "windows-amd64-setup",
    "android-arm64",
    "macos-arm64",
    "macos-amd64"
]

for file in os.listdir(DIST_DIR):
    file_path = os.path.join(DIST_DIR, file)
    if os.path.isfile(file_path):
        file_lower = file.lower()
        if any(kw in file_lower for kw in releaseKeywords):
            file_key = f"file{i}"
            media.append({
                "type": "document",
                "media": f"attach://{file_key}"
            })
            files[file_key] = open(file_path, 'rb')
            i += 1

if TAG:
    text += f"\n**{TAG}**\n"

if IS_STABLE:
    text += f"\nhttps://github.com/chen08209/FlClash/releases/tag/{TAG}\n"
else:
    text += f"\nhttps://github.com/chen08209/FlClash/actions/runs/{RUN_ID}\n"

if os.path.exists(release):
    text += "\n"
    with open(release, 'r') as f:
        text += f.read()
    text += "\n"

if media:
    media[-1]["caption"] = text
    media[-1]["parse_mode"] = "Markdown"

boundary = uuid.uuid4().hex
body = bytearray()


def add_field(name, value):
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
    body.extend(str(value).encode())
    body.extend(b"\r\n")


add_field("chat_id", CHAT_ID)
add_field("media", json.dumps(media))

for name, file_handle in files.items():
    file_name = os.path.basename(file_handle.name)
    content_type = mimetypes.guess_type(file_name)[0] or "application/octet-stream"
    body.extend(f"--{boundary}\r\n".encode())
    body.extend(
        f'Content-Disposition: form-data; name="{name}"; filename="{file_name}"\r\n'.encode()
    )
    body.extend(f"Content-Type: {content_type}\r\n\r\n".encode())
    body.extend(file_handle.read())
    body.extend(b"\r\n")

body.extend(f"--{boundary}--\r\n".encode())
http_request = request.Request(
    API_URL,
    data=bytes(body),
    headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    method="POST",
)

try:
    with request.urlopen(http_request) as response:
        print("Response JSON:", json.loads(response.read().decode()))
finally:
    for file_handle in files.values():
        file_handle.close()
