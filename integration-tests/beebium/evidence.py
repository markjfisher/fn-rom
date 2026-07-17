from __future__ import annotations

import datetime as _dt
import re
import shutil
from pathlib import Path
from typing import Any


class ScreenEvidenceRecorder:
    def __init__(self, *, root: Path, profile: str, nodeid: str) -> None:
        self.root = root
        self.profile = profile
        self.nodeid = nodeid
        self.safe_nodeid = _safe_path_component(nodeid)
        self.path = root / profile / "running" / self.safe_nodeid
        self.path.mkdir(parents=True, exist_ok=True)
        self._capture_index = 0
        self._captures: list[dict[str, str]] = []
        self._notes: list[str] = []
        self._finished = False

    @property
    def finished(self) -> bool:
        return self._finished

    def capture(self, bbc: Any, label: str, *, screen: str | None = None) -> None:
        if self._finished:
            return

        index = self._capture_index
        self._capture_index += 1
        seq = f"{index:03d}"
        captured_at = _dt.datetime.now().isoformat(timespec="seconds")
        record: dict[str, str] = {
            "index": seq,
            "label": label,
            "captured_at": captured_at,
        }

        try:
            if screen is None:
                from beebium.client.screen import dump_screen

                screen = dump_screen(bbc)
            screen_name = f"screen_{seq}.txt"
            (self.path / screen_name).write_text(screen + "\n", encoding="utf-8")
            record["screen"] = screen_name
        except Exception as exc:  # pragma: no cover - diagnostic best effort
            record["screen"] = f"failed: {exc!r}"

        try:
            frame = bbc.video.capture_frame()
            record["frame_info"] = f"{frame.width}x{frame.height} frame={frame.frame_number}"
            png_name = f"frame_{seq}.png"
            try:
                frame.save_png(self.path / png_name)
                record["frame"] = png_name
            except Exception as exc:
                ppm_name = f"frame_{seq}.ppm"
                _save_frame_ppm(frame, self.path / ppm_name)
                record["frame"] = ppm_name
                record["frame_png"] = f"failed: {exc!r}"
        except Exception as exc:  # pragma: no cover - diagnostic best effort
            record["frame"] = f"failed: {exc!r}"

        self._captures.append(record)
        self._write_captures()

    def finish(self, *, status: str) -> None:
        if self._finished:
            return

        self._write_metadata(status=status)
        self._finished = True

        destination = _unique_path(self.root / self.profile / status / self.safe_nodeid)
        destination.parent.mkdir(parents=True, exist_ok=True)
        if self.path.exists():
            shutil.move(str(self.path), str(destination))
            self.path = destination

    def note(self, text: str) -> None:
        self._notes.append(text)

    def _write_captures(self) -> None:
        lines = ["index\tlabel\tcaptured_at\tscreen\tframe\tframe_info"]
        for capture in self._captures:
            lines.append(
                "\t".join(
                    capture.get(key, "")
                    for key in ("index", "label", "captured_at", "screen", "frame", "frame_info")
                )
            )
        (self.path / "captures.tsv").write_text("\n".join(lines) + "\n", encoding="utf-8")

    def _write_metadata(self, *, status: str) -> None:
        lines = [
            f"nodeid: {self.nodeid}",
            f"profile: {self.profile}",
            f"status: {status}",
            f"finished_at: {_dt.datetime.now().isoformat(timespec='seconds')}",
            f"captures: {len(self._captures)}",
        ]
        lines.extend(self._notes)
        (self.path / "metadata.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def _save_frame_ppm(frame: Any, path: Path) -> None:
    rgb = bytearray(frame.width * frame.height * 3)
    pixels = frame.pixels
    j = 0
    for i in range(0, min(len(pixels), frame.width * frame.height * 4), 4):
        rgb[j] = pixels[i + 2]
        rgb[j + 1] = pixels[i + 1]
        rgb[j + 2] = pixels[i]
        j += 3
    with path.open("wb") as fh:
        fh.write(f"P6\n{frame.width} {frame.height}\n255\n".encode("ascii"))
        fh.write(rgb)


def _safe_path_component(nodeid: str) -> str:
    safe = re.sub(r"[^A-Za-z0-9_.-]+", "_", nodeid)
    return safe.strip("._")[:180] or "test"


def _unique_path(path: Path) -> Path:
    if not path.exists():
        return path
    for i in range(2, 1000):
        candidate = path.with_name(f"{path.name}-{i}")
        if not candidate.exists():
            return candidate
    raise RuntimeError(f"could not choose a unique evidence directory for {path}")
