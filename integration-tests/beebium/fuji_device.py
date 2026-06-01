"""A minimal FujiBus 'device' endpoint for the Beebium serial/PTY tests.

The fn-rom is the FujiBus *host*: it sends SLIP-framed FujiBus requests out the
BBC serial port. In a real deployment a FujiNet device sits on the other end of
the wire. For these tests we attach to the emulator's pseudo-terminal slave and
play that device role: we read the request frames the ROM emits (so tests can
assert them) and send back responses (so multi-step ROM flows can proceed).

All SLIP framing and FujiBus parsing/building is reused from
``fujinet_tools.fujibus`` -- this module only adds the device-side plumbing
(open the pty, run a reader thread, record requests, reply).
"""

from __future__ import annotations

import os
import select
import struct
import threading
import time
import tty
from typing import Callable, List, Optional

from fujinet_tools import fujibus as fb

try:  # protocol constants/helpers (optional -- only needed by some helpers)
    from fujinet_tools import fileproto as fp
except Exception:  # pragma: no cover - defensive
    fp = None

FujiPacket = fb.FujiPacket
Responder = Callable[[FujiPacket], Optional[bytes]]


def default_success_responder(pkt: FujiPacket) -> bytes:
    """Reply to any request with a generic FujiBus success (status = 0)."""
    return fb.build_fuji_response_wire(pkt.device, pkt.command, 0, b"")


class FujiDevice:
    """Device end of the serial link, attached to a pty slave path."""

    def __init__(self, pty_path: str, *, responder: Optional[Responder] = None):
        self.pty_path = pty_path
        self._fd = -1
        self._rx = bytearray()
        self._requests: List[FujiPacket] = []
        self._lock = threading.Lock()
        self._stop = False
        self._thread: Optional[threading.Thread] = None
        self._responder: Responder = responder or default_success_responder

    # --- lifecycle -----------------------------------------------------------

    def start(self, open_timeout: float = 5.0) -> "FujiDevice":
        deadline = time.monotonic() + open_timeout
        last_err: Optional[OSError] = None
        while time.monotonic() < deadline:
            try:
                self._fd = os.open(self.pty_path, os.O_RDWR | os.O_NOCTTY)
                break
            except OSError as exc:
                last_err = exc
                time.sleep(0.1)
        if self._fd < 0:
            raise RuntimeError(f"could not open pty {self.pty_path!r}: {last_err}")
        tty.setraw(self._fd)  # raw: no echo / CR-LF cooking on the slave
        self._stop = False
        self._thread = threading.Thread(target=self._loop, daemon=True)
        self._thread.start()
        return self

    def close(self) -> None:
        self._stop = True
        if self._thread is not None:
            self._thread.join(timeout=1.0)
            self._thread = None
        if self._fd >= 0:
            try:
                os.close(self._fd)
            except OSError:
                pass
            self._fd = -1

    # --- reader thread -------------------------------------------------------

    def _loop(self) -> None:
        while not self._stop:
            readable, _, _ = select.select([self._fd], [], [], 0.1)
            if not readable:
                continue
            try:
                chunk = os.read(self._fd, 512)
            except OSError:
                break
            if not chunk:
                continue
            self._rx.extend(chunk)
            while True:
                frame = fb._extract_frame_from_rx(self._rx)
                if frame is None:
                    break
                pkt = fb.parse_fuji_packet(fb.slip_decode(frame))
                if pkt is None:
                    continue
                with self._lock:
                    self._requests.append(pkt)
                try:
                    reply = self._responder(pkt)
                except Exception:
                    reply = None
                if reply:
                    try:
                        os.write(self._fd, reply)
                    except OSError:
                        pass

    # --- API for tests -------------------------------------------------------

    def set_responder(self, fn: Responder) -> None:
        """Install a custom responder ``fn(pkt) -> Optional[bytes]``."""
        self._responder = fn

    @property
    def requests(self) -> List[FujiPacket]:
        with self._lock:
            return list(self._requests)

    def clear(self) -> None:
        with self._lock:
            self._requests.clear()

    def wait_for(self, predicate: Callable[[FujiPacket], bool], timeout: float = 5.0):
        """Return the first recorded request matching ``predicate`` (or None)."""
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            for pkt in self.requests:
                if predicate(pkt):
                    return pkt
            time.sleep(0.02)
        return None

    def wait_for_command(self, device: int, command: int, timeout: float = 5.0):
        return self.wait_for(
            lambda p: p.device == device and p.command == command, timeout
        )

    def send_response(self, device: int, command: int, status: int = 0, payload: bytes = b"") -> None:
        """Manually push a FujiBus response frame to the ROM."""
        os.write(self._fd, fb.build_fuji_response_wire(device, command, status, payload))


# --- Device-side response builders (mirror the host-side parsers) ------------

def build_resolve_path_response(resolved_uri: str, display_path: str, status: int = 0) -> bytes:
    """A FileService RESOLVE_PATH (0x05) reply.

    Wire format mirrors ``fujinet_tools.fileproto.parse_resolve_path_resp``:
    version(1) flags(1) reserved(2) uri_len(2) uri path_len(2) path.
    """
    if fp is None:
        raise RuntimeError("fujinet_tools.fileproto is unavailable")
    rb = resolved_uri.encode("utf-8")
    db = display_path.encode("utf-8")
    body = (
        bytes([fp.FILEPROTO_VERSION, 0])
        + struct.pack("<H", 0)
        + struct.pack("<H", len(rb)) + rb
        + struct.pack("<H", len(db)) + db
    )
    return fb.build_fuji_response_wire(fp.FILE_DEVICE_ID, fp.CMD_RESOLVE_PATH, status, body)


def resolving_responder(resolved_uri: str, display_path: str) -> Responder:
    """A responder that answers RESOLVE_PATH properly and others generically."""
    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        if fp is not None and pkt.device == fp.FILE_DEVICE_ID and pkt.command == fp.CMD_RESOLVE_PATH:
            return build_resolve_path_response(resolved_uri, display_path)
        return default_success_responder(pkt)
    return _resp
