from __future__ import annotations

import time


def command(bbc, text: str) -> None:
    with bbc.keyboard.text_input():
        bbc.keyboard.type(text)
        bbc.keyboard.press_return()


def run_basic_lines(bbc, lines: list[str], *, wait: float = 0.05) -> None:
    command(bbc, "NEW")
    for line in lines:
        command(bbc, line)
        time.sleep(wait)


def run_basic_program(bbc, lines: list[str], *, wait: float = 0.05) -> None:
    run_basic_lines(bbc, lines, wait=wait)
    command(bbc, "RUN")
