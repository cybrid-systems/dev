#!/usr/bin/env python3
"""test_doom_lsp.py — unit tests for the doom-lsp Python port.

Covers pure-logic helpers (no subprocess, no daemon):
  - URI encode/decode roundtrip
  - Language ID detection across all supported extensions
  - Path resolution (resolve_path_star)
  - Header parsing (read_headers with bytes or str)
  - JSON message framing (write_json_message → read_json_message)
  - Pool state dataclass shape (just imports + signatures)

Smoke tests that DO spawn a daemon (`test_clangd_ping_roundtrip`) are
skipped automatically if `clangd` is not on PATH.

Run:
  python3 skills/doom-lsp/tests/test_doom_lsp.py
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import unittest
from io import BytesIO, StringIO

# Make sibling scripts/ importable
HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPTS = os.path.normpath(os.path.join(HERE, "..", "scripts"))
sys.path.insert(0, SCRIPTS)

from clangd import (  # noqa: E402
    uri_encode, uri_to_path, path_to_uri,
    language_id, resolve_path_star,
    read_headers, read_json_message, write_json_message,
    _strip_cr, parse_location,
)


# ─── URI helpers ─────────────────────────────────────────────────────────────

class UriHelpers(unittest.TestCase):
    def test_encode_unreserved_passthrough(self):
        # alnum + -_.~/:
        self.assertEqual(uri_encode("abcXYZ-_.~/:0123"),
                         "abcXYZ-_.~/:0123")

    def test_encode_percent_special(self):
        # spaces and non-ASCII must be percent-encoded
        out = uri_encode("hello world")
        self.assertIn("%20", out)
        # non-ASCII → UTF-8 bytes → percent encoded
        out = uri_encode("é")
        self.assertIn("%C3%A9", out)  # é = 0xC3 0xA9

    def test_path_to_uri_prefix(self):
        self.assertEqual(path_to_uri("/tmp/foo.c"), "file:///tmp/foo.c")

    def test_decode_roundtrip(self):
        original = "/tmp/a/b c/d-é.rkt"
        encoded = uri_encode(original)
        self.assertEqual(uri_to_path("file://" + encoded), original)
        # With file:// prefix stripped
        self.assertEqual(uri_to_path(encoded), original)

    def test_decode_handles_trailing_percent(self):
        # malformed % at end → leaves it as-is (defensive)
        self.assertEqual(uri_to_path("abc%"), "abc%")


# ─── Language ID detection ──────────────────────────────────────────────────

class LanguageId(unittest.TestCase):
    CASES = {
        "main.c": "c", "main.cpp": "cpp", "main.cc": "cpp",
        "main.cxx": "cpp", "main.c++": "cpp",
        "header.h": "c", "header.hpp": "cpp", "header.hxx": "cpp",
        "header.hh": "cpp", "header.h++": "cpp",
        "kernel.cu": "cuda", "kernel.cuh": "cuda",
        "objc.m": "objective-c", "objcpp.mm": "objective-c",
        "unknown": "c",  # default
        "code.py": "c",  # default (doom-lsp is C/C++ only)
        "code.rkt": "c",  # default — Racket LSP support removed; .rkt falls through to clangd
    }
    def test_each(self):
        for filename, expected in self.CASES.items():
            with self.subTest(filename=filename):
                self.assertEqual(language_id(filename), expected,
                                 f"{filename} should map to {expected}")


# ─── Path resolution ─────────────────────────────────────────────────────────

class PathResolution(unittest.TestCase):
    def test_absolute_unchanged(self):
        self.assertEqual(resolve_path_star("/abs/path.c", "/anywhere"), "/abs/path.c")

    def test_relative_resolved_against_base(self):
        out = resolve_path_star("src/main.c", "/tmp/proj")
        self.assertTrue(out.endswith(os.path.join("tmp", "proj", "src", "main.c")))

    def test_relative_resolves_symlinks(self):
        # /tmp is usually a symlink on macOS; resolve_path_star should realpath
        out = resolve_path_star("foo.c", "/tmp")
        self.assertEqual(out, os.path.realpath("/tmp/foo.c"))


# ─── LSP IPC ────────────────────────────────────────────────────────────────

class StripCr(unittest.TestCase):
    def test_str(self):
        # rstrip("\r") only strips \r, not \n — the LSP caller's
        # subsequent .strip() cleans up the trailing \n.
        self.assertEqual(_strip_cr("hello\r"), "hello")
        self.assertEqual(_strip_cr("hello"), "hello")
        self.assertEqual(_strip_cr("hello\r\n"), "hello\r\n")
        # Trailing multiple \r all get stripped.
        self.assertEqual(_strip_cr("hello\r\r"), "hello")

    def test_bytes(self):
        self.assertEqual(_strip_cr(b"hello\r"), "hello")
        self.assertEqual(_strip_cr(b"hello"), "hello")
        self.assertEqual(_strip_cr(b"hello\r\n"), "hello\r\n")


class ReadHeaders(unittest.TestCase):
    def test_basic(self):
        # LSP headers are CRLF terminated with a blank-line separator
        raw = b"Content-Length: 42\r\nContent-Type: application/json\r\n\r\n"
        hdrs = read_headers(BytesIO(raw))
        self.assertEqual(hdrs, {"Content-Length": "42",
                                "Content-Type": "application/json"})

    def test_no_blank_line_eof(self):
        raw = b"Content-Length: 42\r\n"
        hdrs = read_headers(BytesIO(raw))
        # No blank line yet → returns whatever it got so far
        self.assertEqual(hdrs, {"Content-Length": "42"})

    def test_str_input(self):
        # text-mode is also supported (decode happens in _strip_cr)
        raw = "Content-Length: 42\r\n\r\n"
        hdrs = read_headers(StringIO(raw))
        self.assertEqual(hdrs, {"Content-Length": "42"})


class JsonMessageRoundtrip(unittest.TestCase):
    def test_write_then_read(self):
        out = BytesIO()
        payload = {"jsonrpc": "2.0", "id": 1, "result": {"file": "/tmp/x.c", "line": 42}}
        write_json_message(out, payload)

        # Parse what we wrote
        out.seek(0)
        hdrs = read_headers(out)
        cl = int(hdrs["Content-Length"])
        body = out.read(cl).decode("utf-8")
        parsed = json.loads(body)
        self.assertEqual(parsed, payload)

    def test_crlf_in_header(self):
        # Verify CRLF framing is preserved exactly
        out = BytesIO()
        write_json_message(out, {"jsonrpc": "2.0", "id": 1, "result": None})
        out.seek(0)
        first_bytes = out.read(50)
        # Header separator is \r\n\r\n
        self.assertIn(b"\r\n\r\n", first_bytes)


# ─── LSP parse_location ─────────────────────────────────────────────────────

class ParseLocation(unittest.TestCase):
    def test_full(self):
        loc = {
            "uri": "file:///tmp/proj/main.c",
            "range": {"start": {"line": 10, "character": 4},
                      "end": {"line": 10, "character": 8}},
        }
        self.assertEqual(parse_location(loc),
                         {"file": "/tmp/proj/main.c", "line": 11})

    def test_missing_range(self):
        self.assertIsNone(parse_location({"uri": "file:///x"}))

    def test_missing_start(self):
        self.assertIsNone(parse_location({"uri": "file:///x", "range": {}}))

    def test_zero_based_line_increment(self):
        # LSP is 0-based, we convert to 1-based
        loc = {"uri": "file:///x.c", "range": {"start": {"line": 0, "character": 0}}}
        self.assertEqual(parse_location(loc), {"file": "/x.c", "line": 1})


# ─── clangd ping smoke (skipped if clangd not installed) ────────────────────

@unittest.skipUnless(shutil.which("clangd"), "clangd not on PATH")
class ClangdPingSmoke(unittest.TestCase):
    def test_ping_returns_pong(self):
        # Create a tiny C project
        proj = "/tmp/doom-lsp-smoke"
        os.makedirs(proj, exist_ok=True)
        with open(os.path.join(proj, "main.c"), "w") as f:
            f.write("int main(void) { return 0; }\n")
        with open(os.path.join(proj, "compile_commands.json"), "w") as f:
            f.write("[]\n")

        proc = subprocess.run(
            [sys.executable, os.path.join(SCRIPTS, "clangd.py"),
             "-d", proj, "ping"],
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(proc.stdout.strip(), "pong",
                         f"stderr: {proc.stderr}")


# ─── Pool imports ────────────────────────────────────────────────────────────

class PoolImports(unittest.TestCase):
    def test_pool_imports(self):
        import pool
        # Public surface exists
        for name in (
            "pool_ping", "pool_goto", "pool_refs", "pool_sym", "pool_doc",
            "pool_ping_async", "pool_goto_async", "pool_refs_async",
            "pool_sym_async", "pool_doc_async",
            "pool_stop", "pool_stop_all", "pool_list", "pool_status",
            "pool_health", "pool_set_rate_limit",
        ):
            self.assertTrue(hasattr(pool, name),
                            f"pool.{name} missing")
        # Sanity-check HEAVY_TIMEOUT is the documented value
        self.assertEqual(pool.HEAVY_TIMEOUT, 20)


if __name__ == "__main__":
    unittest.main(verbosity=2)