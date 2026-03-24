#!/usr/bin/env python3
"""Styx bridge daemon — long-running process that proxies JSON commands to iTerm2's Python API.

Protocol: newline-delimited JSON on stdin/stdout.
Request:  {"id":"req-1","cmd":"list_windows","args":{}}
Response: {"id":"req-1","ok":true,"data":[...]}
Error:    {"id":"req-1","ok":false,"error":"message"}

Unsolicited events (focus changes) use id=null:
          {"id":null,"event":"focus_changed","data":{"type":"window","window_id":"..."}}
"""

import asyncio
import json
import sys
import traceback

import iterm2

from commands import COMMAND_HANDLERS


async def handle_stdin(connection: iterm2.Connection) -> None:
    """Read JSON commands from stdin and dispatch to handlers."""
    loop = asyncio.get_event_loop()
    reader = asyncio.StreamReader()
    protocol = asyncio.StreamReaderProtocol(reader)
    await loop.connect_read_pipe(lambda: protocol, sys.stdin)

    while True:
        line = await reader.readline()
        if not line:
            break
        line = line.decode("utf-8").strip()
        if not line:
            continue

        try:
            request = json.loads(line)
        except json.JSONDecodeError as exc:
            write_response({"id": None, "ok": False, "error": f"Invalid JSON: {exc}"})
            continue

        req_id = request.get("id")
        cmd = request.get("cmd", "")
        args = request.get("args", {})

        handler = COMMAND_HANDLERS.get(cmd)
        if handler is None:
            write_response({"id": req_id, "ok": False, "error": f"Unknown command: {cmd}"})
            continue

        try:
            data = await handler(connection, args)
            write_response({"id": req_id, "ok": True, "data": data})
        except Exception as exc:
            write_response({
                "id": req_id,
                "ok": False,
                "error": f"{type(exc).__name__}: {exc}",
                "traceback": traceback.format_exc(),
            })


async def monitor_focus(connection: iterm2.Connection) -> None:
    """Subscribe to iTerm2 focus changes and push events to stdout."""
    async with iterm2.FocusMonitor(connection) as monitor:
        while True:
            update = await monitor.async_get_next_update()
            event_data = None

            if update.window_changed is not None:
                wc = update.window_changed
                event_data = {
                    "type": "window",
                    "window_id": wc.window_id,
                    "event": wc.event.name,
                }
            elif update.selected_tab_changed is not None:
                tc = update.selected_tab_changed
                event_data = {
                    "type": "tab",
                    "tab_id": tc.tab_id,
                }
            elif update.active_session_changed is not None:
                sc = update.active_session_changed
                event_data = {
                    "type": "session",
                    "session_id": sc.session_id,
                }

            if event_data is not None:
                write_response({
                    "id": None,
                    "event": "focus_changed",
                    "data": event_data,
                })


def write_response(obj: dict) -> None:
    """Write a JSON response line to stdout and flush."""
    sys.stdout.write(json.dumps(obj) + "\n")
    sys.stdout.flush()


async def main(connection: iterm2.Connection) -> None:
    """Entry point: run stdin handler and focus monitor concurrently."""
    await asyncio.gather(
        handle_stdin(connection),
        monitor_focus(connection),
    )


if __name__ == "__main__":
    try:
        iterm2.run_forever(main)
    except Exception as exc:
        # Surface connection failures clearly on stderr and as a JSON error on stdout
        # so the Swift host can distinguish "iTerm2 not reachable" from a crash.
        msg = str(exc) or type(exc).__name__
        if "connect" in msg.lower() or "iterm2" in msg.lower() or isinstance(exc, ConnectionRefusedError):
            msg = (
                "Could not connect to iTerm2. "
                "Ensure iTerm2 is running and its Python API is enabled "
                "(Settings > General > Magic > Enable Python API)."
            )
        sys.stderr.write(f"StyxBridge: {msg}\n")
        sys.stderr.flush()
        error_response = json.dumps({"id": None, "ok": False, "error": msg})
        sys.stdout.write(error_response + "\n")
        sys.stdout.flush()
        sys.exit(1)
