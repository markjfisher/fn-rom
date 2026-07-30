from __future__ import annotations

import time

from beebium.client.screen import dump_screen, read_mode7_screen


def _has_prompt_after_echo(bbc, text: str) -> bool:
    rows = read_mode7_screen(bbc)
    marker_text = text.replace("#", "_")
    marker = ">" + marker_text[: min(len(marker_text), 24)]
    echo_row = None
    for index, row in enumerate(rows):
        if marker in row:
            echo_row = index
            break
    if echo_row is None:
        return False
    return any(row.startswith(">") for row in rows[echo_row + 1 :])


def _has_prompt(bbc) -> bool:
    return any(row.startswith(">") or row.rstrip().endswith(">") for row in read_mode7_screen(bbc))


def _clears_or_replaces_echo(text: str) -> bool:
    upper = text.strip().upper()
    return (
        upper == "CLS"
        or upper.startswith("MODE ")
        or upper.startswith("CHAIN ")
        or upper.startswith("CH.")
        or upper.startswith("*RUN ")
    )


def _awaits_confirmation(bbc) -> bool:
    rows = read_mode7_screen(bbc)
    screen = "\n".join(rows).upper()
    if "(Y/N)" in screen or "GO (Y/N)" in screen:
        return True
    return any(row.strip().startswith("$.") and row.rstrip().endswith(":") for row in rows)


def command(bbc, text: str) -> None:
    with bbc.keyboard.text_input():
        bbc.keyboard.type(text + "\r")
    ready = _has_prompt if _clears_or_replaces_echo(text) else lambda b: _has_prompt_after_echo(b, text)
    deadline = time.monotonic() + 5.0
    while time.monotonic() < deadline:
        if ready(bbc):
            screen = dump_screen(bbc)
            if "Bad program" in screen:
                raise AssertionError(
                    f"command {text!r} returned to BASIC via Bad program\n{screen}"
                )
            return
        if _awaits_confirmation(bbc):
            return
        time.sleep(0.01)
    else:
        raise TimeoutError(f"BASIC prompt did not return after {text!r}\n{dump_screen(bbc)}")


def run_basic_lines(bbc, lines: list[str], *, wait: float = 0.05) -> None:
    command(bbc, "NEW")
    for line in lines:
        command(bbc, line)
        time.sleep(wait)


def run_basic_program(bbc, lines: list[str], *, wait: float = 0.05) -> None:
    run_basic_lines(bbc, lines, wait=wait)
    command(bbc, "RUN")


def wait_for_screen_text(
    bbc,
    text: str,
    *,
    timeout: float = 8.0,
    case_sensitive: bool = True,
    evidence=None,
    label: str | None = None,
) -> str:
    if evidence is None:
        evidence = getattr(bbc, "_fn_screen_evidence", None)

    deadline = time.monotonic() + timeout
    wanted = text if case_sensitive else text.upper()
    last_screen = ""
    while time.monotonic() < deadline:
        screen = dump_screen(bbc)
        last_screen = screen
        haystack = screen if case_sensitive else screen.upper()
        if wanted in haystack:
            if evidence is not None:
                evidence.capture(bbc, label or f"contains {text}", screen=screen)
            return screen
        time.sleep(0.02)
    if evidence is not None:
        evidence.capture(bbc, label or f"timeout contains {text}", screen=last_screen)
    raise TimeoutError(f"Text {text!r} not found on screen within {timeout} seconds")
