#!/usr/bin/env python3
import argparse
import hashlib
import json
import os
import sys
from pathlib import Path
from typing import Optional
from urllib.parse import quote

import requests


def compute_sha256(path: Path, chunk_size: int = 1024 * 1024) -> str:
    hasher = hashlib.sha256()
    with path.open("rb") as fh:
        while True:
            chunk = fh.read(chunk_size)
            if not chunk:
                break
            hasher.update(chunk)
    return hasher.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload one or more files to the THREDDS upload service."
    )
    parser.add_argument(
        "--url",
        default=os.getenv("UPLOAD_URL", "http://localhost:8080"),
        help="Service base URL or multipart upload URL (default: %(default)s or UPLOAD_URL)",
    )
    parser.add_argument(
        "--token",
        default=os.getenv("UPLOAD_TOKEN"),
        help="Bearer token (default: UPLOAD_TOKEN)",
    )
    parser.add_argument(
        "--destination",
        required=True,
        help="Destination name configured on server",
    )
    parser.add_argument(
        "--file",
        nargs="+",
        required=True,
        help="One or more paths to files to upload.",
    )
    parser.add_argument(
        "--checksum",
        choices=("none", "auto"),
        default="none",
        help="Set X-Content-SHA256 header (default: %(default)s)",
    )
    parser.add_argument(
        "--connect-timeout",
        type=int,
        default=10,
        help="Connection timeout in seconds (default: %(default)s)",
    )
    parser.add_argument(
        "--read-timeout",
        type=int,
        default=7200,
        help="Read timeout in seconds for large uploads (default: %(default)s)",
    )
    parser.add_argument(
        "--expect-status",
        type=int,
        default=None,
        help="Expected HTTP status code. Fails if response status differs.",
    )
    parser.add_argument(
        "--multipart",
        action="store_true",
        help="Use legacy multipart POST /upload instead of raw streaming PUT.",
    )
    return parser.parse_args()


def build_headers(token: str, checksum: Optional[str]) -> dict:
    headers = {"Authorization": f"Bearer {token}"}
    if checksum:
        headers["X-Content-SHA256"] = checksum
    return headers


def resolve_uploads(args: argparse.Namespace) -> list[tuple[Path, str]]:
    file_paths = [Path(file_name).expanduser().resolve() for file_name in args.file]
    for file_path in file_paths:
        if not file_path.is_file():
            raise ValueError(f"file not found: {file_path}")

    return [(file_path, file_path.name) for file_path in file_paths]


def build_raw_upload_url(base_url: str, destination: str, remote_filename: str) -> str:
    trimmed = base_url.rstrip("/")
    return (
        f"{trimmed}/upload/"
        f"{quote(destination, safe='')}/"
        f"{quote(remote_filename, safe='')}"
    )


def upload_one(args: argparse.Namespace, file_path: Path, remote_filename: str) -> int:
    if not file_path.is_file():
        print(f"error: file not found: {file_path}", file=sys.stderr)
        return 2

    checksum = compute_sha256(file_path) if args.checksum == "auto" else None
    headers = build_headers(args.token, checksum)
    try:
        with file_path.open("rb") as file_handle:
            if args.multipart:
                files = {"file": (remote_filename, file_handle, "application/octet-stream")}
                data = {"filename": remote_filename, "destination": args.destination}
                response = requests.post(
                    f"{args.url.rstrip('/')}/upload",
                    headers=headers,
                    data=data,
                    files=files,
                    timeout=(args.connect_timeout, args.read_timeout),
                )
            else:
                raw_headers = {
                    **headers,
                    "Content-Type": "application/octet-stream",
                }
                response = requests.put(
                    build_raw_upload_url(args.url, args.destination, remote_filename),
                    headers=raw_headers,
                    data=file_handle,
                    timeout=(args.connect_timeout, args.read_timeout),
                )
    except requests.RequestException as exc:
        print(f"error: upload request failed: {exc}", file=sys.stderr)
        return 1

    content_type = response.headers.get("content-type", "")
    if "application/json" in content_type.lower():
        try:
            payload = response.json()
            print(json.dumps(payload, indent=2, sort_keys=True))
        except ValueError:
            print(response.text)
    else:
        print(response.text)

    if args.expect_status is not None:
        if response.status_code != args.expect_status:
            print(
                f"error: expected status {args.expect_status}, got {response.status_code}",
                file=sys.stderr,
            )
            return 1
        return 0

    return 0 if response.ok else 1


def main() -> int:
    args = parse_args()

    if not args.token:
        print("error: missing token. Provide --token or set UPLOAD_TOKEN.", file=sys.stderr)
        return 2

    try:
        uploads = resolve_uploads(args)
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    exit_code = 0
    multiple_uploads = len(uploads) > 1
    for file_path, remote_filename in uploads:
        if multiple_uploads:
            print(
                f"Uploading {file_path} as {remote_filename} to destination {args.destination}...",
                file=sys.stderr,
            )
        result = upload_one(args, file_path, remote_filename)
        if result != 0:
            exit_code = result

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
