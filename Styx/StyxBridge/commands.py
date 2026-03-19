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

def _get_as_window_ids() -> set:
    """Get current AppleScript window IDs for iTerm2."""
    import subprocess
    result = subprocess.run(
        ["osascript", "-e", 'tell application "iTerm2" to get id of every window'],
        capture_output=True, text=True, timeout=5
    )
    if result.returncode != 0:
        return set()
    return set(int(x.strip()) for x in result.stdout.strip().split(",") if x.strip().isdigit())


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

    # Snapshot AppleScript window IDs before creation
    before_ids = _get_as_window_ids()

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

    # Discover the new AppleScript window ID
    import asyncio
    await asyncio.sleep(0.3)  # Brief delay for AppleScript to register
    after_ids = _get_as_window_ids()
    new_ids = after_ids - before_ids
    as_window_id = new_ids.pop() if new_ids else None

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
        "as_window_id": as_window_id,
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


@command("set_window_title")
async def cmd_set_window_title(connection: iterm2.Connection, args: dict) -> dict:
    """Set the window title and all tab/session titles.

    Uses session profile overrides to prevent the shell from resetting the title.

    args:
        window_id: target window
        title: the title string
    """
    window_id = args["window_id"]
    title = args["title"]
    app = await iterm2.async_get_app(connection)
    window = _find_window(app, window_id)
    # Set the window-level title
    await window.async_set_title(title)
    for tab in window.tabs:
        await tab.async_set_title(title)
        for session in tab.sessions:
            # Override session name so the shell prompt doesn't reset it
            await session.async_set_name(title)
    return {"window_id": window_id, "title": title}


@command("set_tab_color")
async def cmd_set_tab_color(connection: iterm2.Connection, args: dict) -> dict:
    """Apply bubble visual identity to an iTerm2 window.

    Sets tab color (visible in Minimal/Compact theme), badge text
    (always visible as a watermark), and badge color to match.

    args:
        window_id: target window
        hex_color: color as hex string (e.g. "#4A90D9")
        badge_text: text to show as badge (optional, defaults to "")
    """
    window_id = args["window_id"]
    hex_color = args["hex_color"].lstrip("#")
    badge_text = args.get("badge_text", "")
    r = int(hex_color[0:2], 16)
    g = int(hex_color[2:4], 16)
    b = int(hex_color[4:6], 16)
    color = iterm2.Color(r, g, b)
    app = await iterm2.async_get_app(connection)
    window = _find_window(app, window_id)
    for tab in window.tabs:
        for session in tab.sessions:
            profile = await session.async_get_profile()
            # Tab color (visible when iTerm2 theme is Minimal/Compact)
            await profile.async_set_tab_color(color)
            await profile.async_set_use_tab_color(True)
            # Badge — always visible as a watermark on the terminal
            if badge_text:
                await profile.async_set_badge_text(badge_text)
                await profile.async_set_badge_color(iterm2.Color(r, g, b, 50))
    return {"window_id": window_id, "color": f"#{hex_color}", "badge": badge_text}


@command("minimize_window")
async def cmd_minimize_window(connection: iterm2.Connection, args: dict) -> dict:
    """Minimize (or restore) an iTerm2 window by AppleScript numeric ID.

    args:
        as_window_id: AppleScript numeric window ID (from create_window)
        minimize: bool (true to minimize, false to restore)
    """
    import subprocess

    as_id = args["as_window_id"]
    minimize = args.get("minimize", True)
    action = "true" if minimize else "false"

    script = f'''
        tell application "iTerm2"
            repeat with w in windows
                if id of w is {as_id} then
                    set miniaturized of w to {action}
                    return "ok"
                end if
            end repeat
            error "No window with AppleScript ID {as_id}"
        end tell
    '''

    result = subprocess.run(
        ["osascript", "-e", script],
        capture_output=True, text=True, timeout=5
    )
    if result.returncode != 0:
        raise RuntimeError(f"AppleScript failed: {result.stderr.strip()}")

    return {"as_window_id": as_id, "minimized": minimize}


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


@command("get_active_window")
async def cmd_get_active_window(connection: iterm2.Connection, args: dict) -> dict:
    """Return the currently focused iTerm2 window with its tabs."""
    app = await iterm2.async_get_app(connection)
    window = app.current_terminal_window
    if window is None:
        raise ValueError("No active iTerm2 window")

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

    return {
        "window_id": window.window_id,
        "tabs": tabs,
    }


@command("set_bubble_env")
async def cmd_set_bubble_env(connection: iterm2.Connection, args: dict) -> dict:
    """Set the STYX_BUBBLE environment variable in all sessions of a window.

    Sends an export command to each session so the shell picks it up.
    Uses a control sequence to minimize visual noise.

    args:
        window_id: target window
        bubble_name: the bubble name to export
    """
    window_id = args["window_id"]
    bubble_name = args["bubble_name"]
    hex_color = args.get("hex_color", "")
    # Escape single quotes in the name for shell safety
    safe_name = bubble_name.replace("'", "'\\''")
    safe_color = hex_color.replace("'", "")
    app = await iterm2.async_get_app(connection)
    window = _find_window(app, window_id)
    for tab in window.tabs:
        for session in tab.sessions:
            # Use iTerm2's variable system to inject without echoing
            await session.async_set_variable("user.styx_bubble", safe_name)
            await session.async_set_variable("user.styx_bubble_color", safe_color)
            # Inject env vars silently: export, then clear the line and redraw prompt
            await session.async_send_text(
                f" export STYX_BUBBLE='{safe_name}' STYX_BUBBLE_COLOR='{safe_color}' && clear\n"
            )
    return {"window_id": window_id, "bubble_name": bubble_name, "hex_color": hex_color}


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
