"""Command handlers for the Styx bridge daemon.

Each handler receives an iterm2.Connection and an args dict,
and returns a JSON-serializable data dict.
"""

from __future__ import annotations

import os
from typing import Any, Callable, Coroutine, Dict

import iterm2

Handler = Callable[[iterm2.Connection, Dict[str, Any]], Coroutine[Any, Any, Any]]
COMMAND_HANDLERS: Dict[str, Handler] = {}


def command(name: str):
    """Decorator to register a command handler."""
    def decorator(func: Handler) -> Handler:
        COMMAND_HANDLERS[name] = func
        return func
    return decorator


# --- Phase 0: Foundation ---

@command("ping")
async def cmd_ping(connection: iterm2.Connection, args: dict) -> dict:
    app = await iterm2.async_get_app(connection)
    return {"pong": True, "iterm2_version": app.version if hasattr(app, "version") else "unknown"}


@command("list_windows")
async def cmd_list_windows(connection: iterm2.Connection, args: dict) -> list:
    app = await iterm2.async_get_app(connection)
    windows = []
    for window in app.windows:
        tabs = []
        for tab in window.tabs:
            sessions = []
            for session in tab.sessions:
                sessions.append({
                    "session_id": session.session_id,
                    "name": session.name,
                })
            tabs.append({
                "tab_id": tab.tab_id,
                "sessions": sessions,
            })
        windows.append({
            "window_id": window.window_id,
            "tabs": tabs,
        })
    return windows


@command("activate_window")
async def cmd_activate_window(connection: iterm2.Connection, args: dict) -> dict:
    window_id = args["window_id"]
    app = await iterm2.async_get_app(connection)
    for window in app.windows:
        if window.window_id == window_id:
            await window.async_activate()
            return {"activated": True, "window_id": window_id}
    raise ValueError(f"Window not found: {window_id}")


# --- Phase 2: Workspace Lifecycle ---

@command("create_window")
async def cmd_create_window(connection: iterm2.Connection, args: dict) -> dict:
    """Create a new iTerm2 window, optionally with multiple tabs.

    args:
        tabs: list of {name, dir, cmd} dicts (optional)
        profile: profile name to use (optional)
    """
    app = await iterm2.async_get_app(connection)
    tabs_config = args.get("tabs", [{}])
    profile = args.get("profile")

    # Create the window with the first tab
    first = tabs_config[0] if tabs_config else {}
    command_str = _build_command(first)
    window = await iterm2.Window.async_create(
        connection,
        profile=profile,
        command=command_str,
    )
    if window is None:
        raise RuntimeError("Failed to create window")

    created_tabs = []

    # Set first tab's directory and name
    first_session = window.current_tab.sessions[0]
    if first.get("dir"):
        await first_session.async_send_text(f"cd {_expand(first['dir'])}\n")
    if first.get("name"):
        await window.current_tab.async_set_title(first["name"])
    created_tabs.append({"tab_id": window.current_tab.tab_id})

    # Create additional tabs
    for tab_cfg in tabs_config[1:]:
        command_str = _build_command(tab_cfg)
        tab = await window.async_create_tab(
            profile=profile,
            command=command_str,
        )
        if tab_cfg.get("dir"):
            await tab.sessions[0].async_send_text(f"cd {_expand(tab_cfg['dir'])}\n")
        if tab_cfg.get("name"):
            await tab.async_set_title(tab_cfg["name"])
        created_tabs.append({"tab_id": tab.tab_id})

    return {
        "window_id": window.window_id,
        "tabs": created_tabs,
    }


@command("create_tab")
async def cmd_create_tab(connection: iterm2.Connection, args: dict) -> dict:
    """Create a new tab in an existing window.

    args:
        window_id: target window
        name: tab name (optional)
        dir: working directory (optional)
        cmd: command to run (optional)
    """
    window_id = args["window_id"]
    app = await iterm2.async_get_app(connection)
    window = _find_window(app, window_id)

    tab = await window.async_create_tab(command=_build_command(args))
    if args.get("dir"):
        await tab.sessions[0].async_send_text(f"cd {_expand(args['dir'])}\n")
    if args.get("name"):
        await tab.async_set_title(args["name"])

    return {"tab_id": tab.tab_id, "window_id": window_id}


@command("close_window")
async def cmd_close_window(connection: iterm2.Connection, args: dict) -> dict:
    window_id = args["window_id"]
    app = await iterm2.async_get_app(connection)
    window = _find_window(app, window_id)
    await window.async_close(force=True)
    return {"closed": True, "window_id": window_id}


@command("activate_tab")
async def cmd_activate_tab(connection: iterm2.Connection, args: dict) -> dict:
    tab_id = args["tab_id"]
    app = await iterm2.async_get_app(connection)
    for window in app.windows:
        for tab in window.tabs:
            if tab.tab_id == tab_id:
                await tab.async_select()
                return {"activated": True, "tab_id": tab_id}
    raise ValueError(f"Tab not found: {tab_id}")


@command("list_tabs")
async def cmd_list_tabs(connection: iterm2.Connection, args: dict) -> list:
    window_id = args["window_id"]
    app = await iterm2.async_get_app(connection)
    window = _find_window(app, window_id)
    tabs = []
    for tab in window.tabs:
        sessions = []
        for session in tab.sessions:
            sessions.append({
                "session_id": session.session_id,
                "name": session.name,
            })
        tabs.append({
            "tab_id": tab.tab_id,
            "sessions": sessions,
        })
    return tabs


# --- Helpers ---

def _find_window(app, window_id: str):
    for window in app.windows:
        if window.window_id == window_id:
            return window
    raise ValueError(f"Window not found: {window_id}")


def _expand(path: str) -> str:
    return os.path.expanduser(path)


def _build_command(cfg: dict) -> str | None:
    cmd = cfg.get("cmd")
    if cmd:
        return cmd
    return None
