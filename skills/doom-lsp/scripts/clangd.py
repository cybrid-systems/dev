#!/usr/bin/env python3
"""clangd.py — C/C++ LSP client (clangd), daemon + CLI mode.

Daemon protocol (matches the legacy Racket implementation):
  - stdout line 1: "READY" once initialization + warmup finishes
  - subsequent stdin lines: commands, one per line
  - subsequent stdout lines: JSON responses, one per line
  - stderr: log / errors

Single-shot CLI:
  python3 clangd.py -d <dir> ping
  python3 clangd.py -d <dir> def <file> <line> <col>
  python3 clangd.py -d <dir> refs <file> <line> <col>
  python3 clangd.py -d <dir> sym <query> [file]
  python3 clangd.py -d <dir> doc <file>
  python3 clangd.py -d <dir> summary <file>
  python3 clangd.py -d <dir> close
  python3 clangd.py -d <dir> doc-limit <n>
  python3 clangd.py -d <dir> doc-delay <secs>

Daemon mode (reads commands from stdin, writes JSON to stdout):
  python3 clangd.py -d <dir> DAEMONMODE
"""
from __future__ import annotations

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Any, Optional

# ─── URI helpers ──────────────────────────────────────────────────────────────

_UNRESERVED = set(
    b"ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    b"abcdefghijklmnopqrstuvwxyz"
    b"0123456789"
    b"-_.~/:"
)


def uri_encode(s: str) -> str:
    """Percent-encode per RFC 3986 for file URIs (unreserved chars pass through)."""
    out = bytearray()
    for b in s.encode("utf-8"):
        if b in _UNRESERVED:
            out.append(b)
        else:
            out.extend(f"%{b:02X}".encode("ascii"))
    return out.decode("ascii")


def path_to_uri(path: str | os.PathLike) -> str:
    return "file://" + uri_encode(str(path))


def _hex_val(c: str) -> int:
    if "0" <= c <= "9":
        return ord(c) - ord("0")
    if "a" <= c <= "f":
        return ord(c) - ord("a") + 10
    if "A" <= c <= "F":
        return ord(c) - ord("A") + 10
    return 0


def uri_to_path(uri: str) -> str:
    """Percent-decode a file URI path back to a filesystem path."""
    if uri.startswith("file://"):
        uri = uri[7:]
    out = bytearray()
    i = 0
    bs = uri.encode("utf-8")
    while i < len(bs):
        c = chr(bs[i])
        if c == "%" and i + 2 < len(bs):
            hi = _hex_val(chr(bs[i + 1]))
            lo = _hex_val(chr(bs[i + 2]))
            out.append((hi << 4) | lo)
            i += 3
        else:
            out.append(bs[i])
            i += 1
    return out.decode("utf-8")


# ─── Language ID detection ───────────────────────────────────────────────────

_CPP_EXTS = {"cpp", "cc", "cxx", "c++", "hpp", "hxx", "hh", "h++"}


def language_id(file_path: str) -> str:
    ext = Path(file_path).suffix.lstrip(".").lower()
    if ext == "c" or ext == "h":
        return "c"
    if ext in _CPP_EXTS:
        return "cpp"
    if ext == "cu" or ext == "cuh":
        return "cuda"
    if ext == "m" or ext == "mm":
        return "objective-c"
    return "c"


# ─── Header / JSON IPC ───────────────────────────────────────────────────────

def _strip_cr(s) -> str:
    """Match Racket's read-line behavior: keeps \\r, so strip it.

    Accepts bytes or str; always returns str (bytes are decoded as utf-8).
    """
    if isinstance(s, bytes):
        s = s.decode("utf-8", errors="replace")
    return s.rstrip("\r")


def read_headers(in_file) -> dict[str, str]:
    """Read LSP headers (terminated by blank line)."""
    headers: dict[str, str] = {}
    while True:
        line = in_file.readline()
        if not line:
            return headers
        line = _strip_cr(line)
        if line.strip() == "":
            return headers
        if ":" in line:
            key, _, val = line.partition(":")
            headers[key.strip()] = val.strip()


def read_json_message(in_file) -> Optional[dict]:
    headers = read_headers(in_file)
    cl = int(headers.get("Content-Length", "0"))
    if cl <= 0:
        return None
    body = in_file.read(cl)
    if not body:
        return None
    try:
        return json.loads(body)
    except json.JSONDecodeError:
        return None


def write_json_message(out_file, payload: dict) -> None:
    body = json.dumps(payload, ensure_ascii=False)
    enc = body.encode("utf-8")
    header = f"Content-Length: {len(enc)}\r\n\r\n"
    out_file.write(header.encode("ascii") + enc)
    out_file.flush()


def write_json_notification(out_file, method: str, params: dict) -> None:
    write_json_message(out_file, {"jsonrpc": "2.0", "method": method, "params": params})


# ─── LSP connection (reader thread + pending responses) ──────────────────────

REQUEST_TIMEOUT_SEC = 120


class LspConnection:
    """Wraps a clangd subprocess with a reader thread that dispatches by id."""

    def __init__(self, stdout, stdin, ctrl):
        self.stdout = stdout
        self.stdin = stdin
        self.ctrl = ctrl
        self._pending: dict[int, "queue.Queue[Optional[dict]]"] = {}
        self._lock = threading.Lock()
        self._stop = threading.Event()
        self._reader = threading.Thread(target=self._reader_loop, daemon=True)
        self._reader.start()

    # ── reader ────────────────────────────────────────────────────────────

    def _reader_loop(self) -> None:
        while not self._stop.is_set():
            try:
                msg = read_json_message(self.stdout)
            except (ValueError, OSError):
                # EOF or broken pipe — release all pending with None
                self._release_all()
                return
            if msg is None:
                # EOF or empty — release pending and exit
                self._release_all()
                return
            msg_id = msg.get("id")
            if msg_id is not None:
                with self._lock:
                    ch = self._pending.pop(msg_id, None)
                if ch is not None:
                    ch.put(msg)
        # Stop event: release all pending
        self._release_all()

    def _release_all(self) -> None:
        with self._lock:
            channels = list(self._pending.values())
            self._pending.clear()
        for ch in channels:
            ch.put(None)

    def stop_reader(self) -> None:
        self._stop.set()

    # ── request / notify ──────────────────────────────────────────────────

    def send_request(self, msg_id: int, method: str, params: dict, timeout: float = REQUEST_TIMEOUT_SEC) -> Any:
        resp_chan: "queue.Queue[Optional[dict]]" = queue.Queue(maxsize=1)
        with self._lock:
            self._pending[msg_id] = resp_chan
        try:
            write_json_message(self.stdin, {"jsonrpc": "2.0", "id": msg_id, "method": method, "params": params})
        except (OSError, ValueError):
            with self._lock:
                self._pending.pop(msg_id, None)
            raise RuntimeError(f"failed to write request id={msg_id}")
        try:
            resp = resp_chan.get(timeout=timeout)
        except queue.Empty:
            with self._lock:
                self._pending.pop(msg_id, None)
            raise TimeoutError(f"timeout id={msg_id} after {timeout}s")
        if resp is None:
            raise RuntimeError(f"connection closed id={msg_id}")
        if "error" in resp:
            raise RuntimeError(f"{method}: {resp['error']}")
        return resp.get("result")

    def send_notification(self, method: str, params: dict) -> None:
        try:
            write_json_notification(self.stdin, method, params)
        except (OSError, ValueError):
            pass


# ─── Connection lifecycle ───────────────────────────────────────────────────

def connect(root_path: str) -> LspConnection:
    clangd = shutil.which("clangd")
    if not clangd:
        raise RuntimeError("clangd not found in PATH")
    proc = subprocess.Popen(
        [clangd,
         "--compile-commands-dir", root_path,
         "--background-index",
         "--header-insertion=never",
         "--clang-tidy=false"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        bufsize=0,
    )
    # Drain stderr in a thread so it doesn't block.
    def _stderr_drain():
        try:
            for _ in iter(proc.stderr.readline, b""):
                pass
        except Exception:
            pass

    threading.Thread(target=_stderr_drain, daemon=True).start()
    return LspConnection(proc.stdout, proc.stdin, proc)


def disconnect(conn: LspConnection) -> None:
    conn.stop_reader()
    try:
        conn.ctrl.kill()
    except Exception:
        pass
    for f in (conn.stdout, conn.stdin):
        try:
            f.close()
        except Exception:
            pass


# ─── Initialize ──────────────────────────────────────────────────────────────

def initialize(conn: LspConnection, root_path: str) -> None:
    conn.send_request(
        1, "initialize",
        {"processId": None,
         "rootUri": path_to_uri(root_path),
         "capabilities": {}},
    )
    conn.send_notification("initialized", {})


# ─── Document management (LRU eviction) ─────────────────────────────────────

# uri → True (we treat as open)
_opened_documents: dict[str, bool] = {}
# Most-recently-used first
_opened_order: list[str] = []

OPEN_DOCUMENT_DELAY = 0.1
MAX_OPEN_DOCUMENTS = 500


def resolve_path_star(file: str, base_dir: str) -> str:
    if os.path.isabs(file):
        return file
    return os.path.realpath(os.path.join(base_dir, file))


def document_close(conn: LspConnection, uri: str) -> None:
    conn.send_notification("textDocument/didClose", {"textDocument": {"uri": uri}})
    _opened_documents.pop(uri, None)
    try:
        _opened_order.remove(uri)
    except ValueError:
        pass


def document_touch(uri: str) -> None:
    if uri in _opened_order:
        _opened_order.remove(uri)
    _opened_order.insert(0, uri)


def enforce_document_limit(conn: LspConnection) -> None:
    limit = MAX_OPEN_DOCUMENTS
    if limit <= 0:
        return
    while len(_opened_documents) > limit and _opened_order:
        lru = _opened_order.pop()
        document_close(conn, lru)


def ensure_document(conn: LspConnection, file: str, base_dir: str) -> None:
    abs_file = resolve_path_star(file, base_dir)
    uri = path_to_uri(abs_file)
    if uri not in _opened_documents:
        try:
            with open(abs_file, "r", encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            text = ""
        conn.send_notification(
            "textDocument/didOpen",
            {"textDocument": {"uri": uri, "languageId": language_id(abs_file), "text": text}},
        )
        _opened_documents[uri] = True
        document_touch(uri)
        enforce_document_limit(conn)
        # TODO: ideally wait for textDocument/publishDiagnostics instead of a fixed sleep
        time.sleep(OPEN_DOCUMENT_DELAY)
    else:
        document_touch(uri)


# ─── LSP operations ──────────────────────────────────────────────────────────

def parse_location(loc: Any) -> Optional[dict]:
    """Extract {file, line} from an LSP Location. line is 1-based."""
    if not isinstance(loc, dict):
        return None
    rng = loc.get("range")
    if not isinstance(rng, dict):
        return None
    start = rng.get("start")
    if not isinstance(start, dict):
        return None
    file_uri = loc.get("uri", "")
    if file_uri.startswith("file://"):
        path = uri_to_path(file_uri)
    else:
        path = file_uri
    return {"file": path, "line": start.get("line", 0) + 1}


def goto_definition(conn: LspConnection, file: str, line: int, col: int, base_dir: str) -> dict:
    abs_file = resolve_path_star(file, base_dir)
    uri = path_to_uri(abs_file)
    lsp_line = max(0, line - 1)
    lsp_col = max(0, col)
    result = conn.send_request(
        2, "textDocument/definition",
        {"textDocument": {"uri": uri}, "position": {"line": lsp_line, "character": lsp_col}},
    )
    if isinstance(result, list) and result:
        loc = parse_location(result[0])
        return loc if loc is not None else {"file": "", "line": 0}
    if isinstance(result, dict):
        loc = parse_location(result)
        return loc if loc is not None else {"file": "", "line": 0}
    return {"file": "", "line": 0}


def find_references(conn: LspConnection, file: str, line: int, col: int, base_dir: str) -> list:
    abs_file = resolve_path_star(file, base_dir)
    uri = path_to_uri(abs_file)
    lsp_line = max(0, line - 1)
    lsp_col = max(0, col)
    result = conn.send_request(
        3, "textDocument/references",
        {"textDocument": {"uri": uri},
         "position": {"line": lsp_line, "character": lsp_col},
         "context": {"includeDeclaration": True}},
    )
    if not result:
        return []
    out = []
    for r in result:
        loc = parse_location(r)
        if loc is not None:
            out.append(loc)
    return out


def workspace_symbol(conn: LspConnection, query: str) -> list:
    items = conn.send_request(4, "workspace/symbol", {"query": query}) or []
    out = []
    for item in items:
        loc = item.get("location")
        if not isinstance(loc, dict):
            continue
        rng = loc.get("range", {})
        start = rng.get("start", {})
        uri = loc.get("uri", "")
        if uri.startswith("file://"):
            path = uri_to_path(uri)
        else:
            path = uri
        out.append({
            "name": item.get("name", ""),
            "file": path,
            "line": start.get("line", 0) + 1,
        })
    return out


def document_symbols(conn: LspConnection, file: str, base_dir: str) -> list:
    abs_file = resolve_path_star(file, base_dir)
    uri = path_to_uri(abs_file)
    items = conn.send_request(5, "textDocument/documentSymbol", {"textDocument": {"uri": uri}}) or []

    def parse_item(item: dict) -> dict:
        if "selectionRange" in item:
            sel = item["selectionRange"]
            start = sel.get("start", {})
            rng = item.get("range", {})
            rng_start = rng.get("start", {})
            return {
                "name": item.get("name", ""),
                "kind": item.get("kind", 0),
                "file": abs_file,
                "line": start.get("line", 0) + 1,
                "detail": item.get("detail"),
                "containerLine": rng_start.get("line", 0) + 1,
            }
        if "location" in item:
            loc = item["location"]
            rng = loc.get("range", {})
            start = rng.get("start", {})
            uri_ = loc.get("uri", "")
            if uri_.startswith("file://"):
                path = uri_to_path(uri_)
            else:
                path = uri_
            return {
                "name": item.get("name", ""),
                "kind": item.get("kind", 0),
                "file": path,
                "line": start.get("line", 0) + 1,
                "detail": item.get("detail"),
                "containerName": item.get("containerName"),
            }
        return {"name": "?", "kind": 0, "file": abs_file, "line": 0}

    return [parse_item(it) for it in items]


# ─── Command dispatch (shared by CLI and daemon) ────────────────────────────

def _parse_def_args(args: list[str]):
    file = args[0] if len(args) > 0 else ""
    line = int(args[1]) if len(args) > 1 else 0
    col = int(args[2]) if len(args) > 2 else 0
    return file, line, col


def dispatch_command(conn: LspConnection, cmd: str, args: list[str], base_dir: str) -> str:
    if cmd == "def":
        file, line, col = _parse_def_args(args)
        if file:
            ensure_document(conn, file, base_dir)
        return json.dumps(goto_definition(conn, file, line, col, base_dir), ensure_ascii=False)
    if cmd == "refs":
        file, line, col = _parse_def_args(args)
        if file:
            ensure_document(conn, file, base_dir)
        return json.dumps(find_references(conn, file, line, col, base_dir), ensure_ascii=False)
    if cmd == "sym":
        query = args[0] if len(args) > 0 else ""
        src_file = args[1] if len(args) > 1 else ""
        if src_file:
            ensure_document(conn, src_file, base_dir)
            results = workspace_symbol(conn, query)
            if not results:
                results = document_symbols(conn, src_file, base_dir)
            return json.dumps(results, ensure_ascii=False)
        results = workspace_symbol(conn, query)
        if results:
            return json.dumps(results, ensure_ascii=False)
        # Fallback: search all opened documents for matching symbols
        import re
        rx = re.compile(re.escape(query), re.IGNORECASE)
        all_results = []
        for uri in list(_opened_documents.keys()):
            abs_path = uri_to_path(uri)
            try:
                entries = document_symbols(conn, abs_path, base_dir)
            except Exception:
                entries = []
            for sym in entries:
                if isinstance(sym, dict):
                    name = sym.get("name", "")
                    if rx.search(name):
                        all_results.append(sym)
        return json.dumps(all_results, ensure_ascii=False)
    if cmd == "doc":
        file = args[0] if len(args) > 0 else ""
        if file:
            ensure_document(conn, file, base_dir)
        return json.dumps(document_symbols(conn, file, base_dir), ensure_ascii=False)
    if cmd == "close":
        # Close all open documents (useful before quitting or to reset state)
        for uri in list(_opened_documents.keys()):
            document_close(conn, uri)
        return "ok"
    if cmd == "doc-limit":
        global MAX_OPEN_DOCUMENTS
        if args:
            MAX_OPEN_DOCUMENTS = int(args[0])
        return str(MAX_OPEN_DOCUMENTS)
    if cmd == "doc-delay":
        global OPEN_DOCUMENT_DELAY
        if args:
            OPEN_DOCUMENT_DELAY = float(args[0])
        return str(OPEN_DOCUMENT_DELAY)
    if cmd == "ping":
        return "pong"
    if cmd == "help":
        return "Commands: def|refs|sym|doc|close|doc-limit|doc-delay|ping|quit"
    return f"unknown: {cmd}"


# ─── Daemon mode ─────────────────────────────────────────────────────────────

def handle_command(conn: LspConnection, args: list[str], base_dir: str) -> bool:
    """Returns True if the daemon should exit (quit)."""
    cmd_str = args[0] if args else "help"
    cmd_args = args[1:] if len(args) > 1 else []
    result = dispatch_command(conn, cmd_str, cmd_args, base_dir)
    sys.stdout.write(result + "\n")
    sys.stdout.flush()
    return cmd_str == "quit"


def warmup_index(conn: LspConnection, dir: str) -> None:
    """Open a few project files to kick-start clangd's background indexing."""
    candidates = [
        "src/server.c", "src/main.c", "src/sds.c",
        "src/ae.c", "src/networking.c", "src/db.c",
        "redis.c", "main.c", "server.c",
        "include/rocksdb/status.h", "cache/cache.cc", "db/db_impl/db_impl.cc",
        "src/backend/access/heap/heapam.c",
        "app.js", "app.py",
    ]
    for f in candidates:
        p = os.path.join(dir, f)
        if os.path.exists(p):
            ensure_document(conn, f, dir)
            print(f"[warmup] opened {f}", file=sys.stderr, flush=True)

    # Auto-discover up to 3 .c/.h/.cpp/.hpp files under src/, app/, lib/, or root
    roots = [dir, os.path.join(dir, "src"), os.path.join(dir, "app"), os.path.join(dir, "lib")]
    count = 0
    for root in roots:
        if count >= 3 or not os.path.isdir(root):
            continue
        try:
            entries = os.listdir(root)
        except OSError:
            continue
        for name in entries:
            if count >= 3:
                break
            if not (name.endswith(".c") or name.endswith(".h")
                    or name.endswith(".cpp") or name.endswith(".hpp")):
                continue
            if root == dir:
                rel = name
            else:
                rel = os.path.join(os.path.basename(root), name)
            abs_path = resolve_path_star(rel, dir)
            if path_to_uri(abs_path) in _opened_documents:
                continue
            ensure_document(conn, rel, dir)
            print(f"[warmup] opened {rel}", file=sys.stderr, flush=True)
            count += 1


def run_daemon(dir: str) -> None:
    conn = connect(dir)
    try:
        initialize(conn, dir)
        warmup_index(conn, dir)
        print(f"[daemon] ready at {dir}", file=sys.stderr, flush=True)
        sys.stdout.write("READY\n")
        sys.stdout.flush()
        # Reader thread for stdin
        import threading as _t
        lines: "queue.Queue[Optional[str]]" = queue.Queue()
        def _stdin_reader():
            try:
                for line in sys.stdin:
                    lines.put(line)
            except (OSError, ValueError):
                pass
            finally:
                lines.put(None)
        _t.Thread(target=_stdin_reader, daemon=True).start()
        while True:
            line = lines.get()
            if line is None:
                print("[daemon] EOF", file=sys.stderr)
                break
            line = line.rstrip("\r\n")
            if not line.strip():
                continue
            try:
                args = line.split()
                should_exit = handle_command(conn, args, dir)
            except Exception as e:
                print(f"[error] {e}", file=sys.stderr, flush=True)
                sys.stdout.write(f"ERR: {e}\n")
                sys.stdout.flush()
                continue
            if should_exit:
                break
    finally:
        disconnect(conn)


# ─── CLI (single-shot) ───────────────────────────────────────────────────────

def main() -> None:
    raw_args = sys.argv[1:]
    daemon_mode = "DAEMONMODE" in raw_args
    args_to_parse = [a for a in raw_args if a != "DAEMONMODE"]

    opts: dict[str, Any] = {}
    positional: list[str] = []
    i = 0
    while i < len(args_to_parse):
        a = args_to_parse[i]
        if a == "-d":
            if i + 1 >= len(args_to_parse):
                print("Error: -d needs an argument", file=sys.stderr)
                sys.exit(1)
            opts["dir"] = args_to_parse[i + 1]
            i += 2
        elif a.startswith("-"):
            opts[a] = True
            i += 1
        else:
            positional.append(a)
            i += 1

    dir = os.path.realpath(opts.get("dir") or os.getcwd())
    cmd = positional[0] if positional else "help"
    cmd_args = positional[1:] if len(positional) > 1 else []

    if daemon_mode:
        run_daemon(dir)
        sys.exit(0)

    conn = connect(dir)
    try:
        initialize(conn, dir)
        result = dispatch_command(conn, cmd, cmd_args, dir)
        sys.stdout.write(result + "\n")
    finally:
        disconnect(conn)


if __name__ == "__main__":
    main()