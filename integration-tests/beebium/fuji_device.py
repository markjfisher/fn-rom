"""A minimal FujiBus 'device' endpoint for the Beebium serial tests.

The fn-rom is the FujiBus *host*: it sends SLIP-framed FujiBus requests out the
BBC serial port. In a real deployment a FujiNet device sits on the other end of
the wire. For these tests we use Beebium's rpc-serial extension when available,
or attach to the emulator's pseudo-terminal slave, and play that device role:
we read the request frames the ROM emits (so tests can assert them) and send
back responses (so multi-step ROM flows can proceed).

All SLIP framing and FujiBus parsing/building is reused from
``fujinet_tools.fujibus`` -- this module only adds the device-side plumbing
(open the transport, run a reader thread, record requests, reply).
"""

from __future__ import annotations

import os
import select
import struct
import threading
import time
import tty
from dataclasses import dataclass, field
from typing import Callable, Iterable, List, Optional

from fujinet_tools import fujibus as fb

try:  # protocol constants/helpers (optional -- only needed by some helpers)
    from fujinet_tools import diskproto as dp
    from fujinet_tools import fileproto as fp
    from fujinet_tools import fujiproto as fuji
    from fujinet_tools import netproto as netp
except Exception:  # pragma: no cover - defensive
    dp = None
    fp = None
    fuji = None
    netp = None

FujiPacket = fb.FujiPacket
Responder = Callable[[FujiPacket], Optional[bytes]]
SERIAL_REPLY_CHUNK_SIZE = 32
SERIAL_REPLY_CHUNK_DELAY = 0.002

HOST_SERVICE_ID = 0xF0
HOST_VERSION = 0x01
HOST_CMD_GET_CURRENT = 0x01
HOST_CMD_SET_CURRENT = 0x02
HOST_CMD_LIST_HISTORY = 0x03
HOST_CMD_SELECT_HISTORY = 0x04
HOST_CMD_DELETE_HISTORY = 0x05
DISK_CMD_BEGIN_HOST_SESSION = 0x0B
FILE_CMD_RESOLVE_PATH = 0x05
FILE_CMD_APPSTORE_READ = 0x21
FILE_CMD_APPSTORE_WRITE = 0x22
FILE_CMD_APPSTORE_DELETE = 0x23


def _appstore_prefix(payload: bytes) -> tuple[str, str, int]:
    if len(payload) < 5 or payload[0] != 1:
        return "", "", 0
    ns_len = int.from_bytes(payload[1:3], "little")
    pos = 3
    namespace = payload[pos : pos + ns_len].decode("utf-8")
    pos += ns_len
    key_len = int.from_bytes(payload[pos : pos + 2], "little")
    pos += 2
    key = payload[pos : pos + key_len].decode("utf-8")
    return namespace, key, pos + key_len


def build_appstore_read_response(
    data: bytes | None, *, offset: int = 0, command: int = FILE_CMD_APPSTORE_READ
) -> bytes:
    exists = data is not None
    chunk = (data or b"")[offset:]
    flags = (0x02 if exists else 0) | 0x01
    body = bytes([1, flags]) + b"\0\0" + struct.pack("<I", offset)
    body += struct.pack("<H", len(chunk)) + chunk
    return fb.build_fuji_response_wire(0xFE, command, 0, body)


def appstore_slot_read_response(pkt: FujiPacket, slot: int, uri: str, mode: str) -> Optional[bytes]:
    if pkt.device != 0xFE or pkt.command != FILE_CMD_APPSTORE_READ:
        return None
    namespace, key, pos = _appstore_prefix(pkt.payload)
    if namespace != "config-nio" or key != f"slot-{slot:03d}":
        return build_appstore_read_response(None)
    offset = int.from_bytes(pkt.payload[pos : pos + 4], "little")
    flags = 0x01 if mode.lower() in ("r", "ro") else 0
    return build_appstore_read_response(bytes([1, flags]) + uri.encode(), offset=offset)


def default_success_responder(pkt: FujiPacket) -> bytes:
    """Reply to any request with a generic FujiBus success (status = 0)."""
    return fb.build_fuji_response_wire(pkt.device, pkt.command, 0, b"")


class FujiDevice:
    """Device end of the serial link, attached through rpc-serial or a pty."""

    def __init__(
        self,
        pty_path: str = "",
        *,
        rpc_serial=None,
        responder: Optional[Responder] = None,
    ):
        self.pty_path = pty_path
        self._rpc_serial = rpc_serial
        self._fd = -1
        self._rx = bytearray()
        self._requests: List[FujiPacket] = []
        self._lock = threading.Lock()
        self._stop = False
        self._thread: Optional[threading.Thread] = None
        self._responder: Responder = responder or default_success_responder

    # --- lifecycle -----------------------------------------------------------

    def start(self, open_timeout: float = 5.0) -> "FujiDevice":
        if self._rpc_serial is None:
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
            chunk = self._read_transport()
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
                    self._write_transport(reply)

    def _read_transport(self) -> bytes:
        if self._rpc_serial is not None:
            chunk = self._rpc_serial.receive(512)
            if not chunk:
                time.sleep(0.005)
            return chunk
        readable, _, _ = select.select([self._fd], [], [], 0.1)
        if not readable:
            return b""
        try:
            return os.read(self._fd, 512)
        except OSError:
            self._stop = True
            return b""

    def _write_transport(self, data: bytes) -> None:
        if self._rpc_serial is not None:
            remaining = memoryview(data)
            while remaining and not self._stop:
                chunk = remaining[:SERIAL_REPLY_CHUNK_SIZE]
                accepted = self._rpc_serial.send(bytes(chunk))
                if accepted <= 0:
                    time.sleep(0.005)
                    continue
                remaining = remaining[accepted:]
                if remaining:
                    time.sleep(SERIAL_REPLY_CHUNK_DELAY)
            return
        try:
            for offset in range(0, len(data), SERIAL_REPLY_CHUNK_SIZE):
                os.write(self._fd, data[offset : offset + SERIAL_REPLY_CHUNK_SIZE])
                if offset + SERIAL_REPLY_CHUNK_SIZE < len(data):
                    time.sleep(SERIAL_REPLY_CHUNK_DELAY)
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
        self._write_transport(fb.build_fuji_response_wire(device, command, status, payload))


# --- Device-side response builders (mirror the host-side parsers) ------------

def build_resolve_path_response(
    resolved_uri: str,
    display_path: str,
    status: int = 0,
    *,
    device: int | None = None,
) -> bytes:
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
    return fb.build_fuji_response_wire(device or fp.FILE_DEVICE_ID, FILE_CMD_RESOLVE_PATH, status, body)


def build_list_response(
    entries: Iterable[tuple[bool, str, int, int]] = (),
    *,
    start_index: int = 0,
    more: bool = False,
    compact: bool = False,
    formatted_text: str = "",
    status: int = 0,
    device: int | None = None,
) -> bytes:
    """A FileService LIST (0x02) reply.

    Wire format mirrors ``fujinet_tools.fileproto.parse_list_resp``.
    ``entries`` items are ``(is_dir, name, size_bytes, mtime_unix)``.
    """
    if fp is None:
        raise RuntimeError("fujinet_tools.fileproto is unavailable")

    flags = 0
    blob = bytearray()
    entry_count = 0

    if formatted_text:
        flags |= fp.LIST_RESP_FLAG_FORMATTED
        if more:
            flags |= 0x01
        text_bytes = formatted_text.encode("utf-8")
        entry_count = formatted_text.count("\n") + (1 if formatted_text and not formatted_text.endswith("\n") else 0)
        body = (
            bytes([fp.FILEPROTO_VERSION, flags])
            + struct.pack("<H", 0)
            + struct.pack("<H", start_index)
            + struct.pack("<H", entry_count)
            + struct.pack("<H", len(text_bytes))
            + text_bytes
        )
        return fb.build_fuji_response_wire(device or fp.FILE_DEVICE_ID, fp.CMD_LIST, status, body)

    if compact:
        flags |= 0x02
    if more:
        flags |= 0x01

    for is_dir, name, size_bytes, mtime_unix in entries:
        name_b = name.encode("utf-8")
        blob.append(0x01 if is_dir else 0x00)
        blob.append(len(name_b) & 0xFF)
        blob.extend(name_b)
        if not compact:
            blob.extend(struct.pack("<Q", size_bytes))
            blob.extend(struct.pack("<Q", mtime_unix))
        entry_count += 1

    body = (
        bytes([fp.FILEPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + struct.pack("<H", start_index)
        + struct.pack("<H", entry_count)
        + struct.pack("<H", len(blob))
        + bytes(blob)
    )
    return fb.build_fuji_response_wire(device or fp.FILE_DEVICE_ID, fp.CMD_LIST, status, body)


def build_get_mounts_response(
    text: str,
    *,
    first_slot: int = 0,
    start_index: int = 0,
    more: bool = False,
    status: int = 0,
) -> bytes:
    """A Fuji GET_MOUNTS (0xFD) formatted response."""
    if fuji is None:
        raise RuntimeError("fujinet_tools.fujiproto is unavailable")
    flags = fuji.GET_MOUNTS_RESP_FLAG_FORMATTED
    if more:
        flags |= fuji.GET_MOUNTS_RESP_FLAG_MORE
    text_b = text.encode("utf-8")
    entry_count = text.count("\n") + (1 if text and not text.endswith("\n") else 0)
    body = (
        bytes([fuji.GET_MOUNTS_VERSION, flags])
        + struct.pack("<H", first_slot)
        + struct.pack("<H", start_index)
        + struct.pack("<H", entry_count)
        + struct.pack("<H", len(text_b))
        + text_b
    )
    return fb.build_fuji_response_wire(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNTS, status, body)


def build_get_mount_response(
    *,
    slot: int,
    enabled: bool,
    uri: str,
    mode: str = "auto",
    status: int = 0,
) -> bytes:
    """A Fuji GET_MOUNT (0xFB) reply matching the ROM's expected compact format."""
    if fuji is None:
        raise RuntimeError("fujinet_tools.fujiproto is unavailable")
    uri_b = uri.encode("utf-8")
    mode_b = mode.encode("utf-8")
    body = bytes([
        slot & 0xFF,
        0x01 if enabled else 0x00,
        len(uri_b) & 0xFF,
    ]) + uri_b + bytes([len(mode_b) & 0xFF]) + mode_b
    return fb.build_fuji_response_wire(fuji.FUJI_DEVICE_ID, fuji.CMD_GET_MOUNT, status, body)


def build_set_mount_response(status: int = 0) -> bytes:
    if fuji is None:
        raise RuntimeError("fujinet_tools.fujiproto is unavailable")
    return fb.build_fuji_response_wire(fuji.FUJI_DEVICE_ID, fuji.CMD_SET_MOUNT, status, b"")


def _display_path_for_host(uri: str) -> str:
    scheme = uri.find("://")
    if scheme >= 0:
        slash = uri.find("/", scheme + 3)
        return "/" if slash < 0 else uri[slash:]
    colon = uri.find(":")
    path = uri[colon + 1:] if colon >= 0 else uri
    if not path:
        path = "/"
    if not path.startswith("/"):
        path = "/" + path
    return path


def build_host_get_current_response(
    host: str,
    display_path: str | None = None,
    *,
    status: int = 0,
) -> bytes:
    if status != 0:
        return fb.build_fuji_response_wire(HOST_SERVICE_ID, HOST_CMD_GET_CURRENT, status, b"")
    host_b = host.encode("utf-8")
    path_b = (display_path if display_path is not None else _display_path_for_host(host)).encode("utf-8")
    body = bytes([HOST_VERSION]) + struct.pack("<HH", len(host_b), len(path_b)) + host_b + path_b
    return fb.build_fuji_response_wire(HOST_SERVICE_ID, HOST_CMD_GET_CURRENT, status, body)


def build_host_simple_response(command: int, *, status: int = 0) -> bytes:
    body = bytes([HOST_VERSION]) if status == 0 else b""
    return fb.build_fuji_response_wire(HOST_SERVICE_ID, command, status, body)


def build_host_list_history_response(
    text: str,
    *,
    offset: int = 0,
    more: bool = False,
    status: int = 0,
) -> bytes:
    text_b = text.encode("utf-8")
    flags = 0x01 if more else 0x00
    body = bytes([HOST_VERSION, flags]) + struct.pack("<HH", offset, len(text_b)) + text_b
    return fb.build_fuji_response_wire(HOST_SERVICE_ID, HOST_CMD_LIST_HISTORY, status, body)


def host_service_responder(initial_hosts: Iterable[str] = ()) -> Responder:
    """Stateful HostService responder for BBC command/screen tests."""
    history: list[str] = []
    current = ""

    def promote(uri: str) -> None:
        nonlocal current
        current = uri
        if uri in history:
            history.remove(uri)
        history.insert(0, uri)
        del history[32:]

    for host in initial_hosts:
        promote(host)

    def resolve(spec: str) -> str:
        if "://" in spec or ":" in spec:
            return spec
        base = current.rstrip("/")
        return f"{base}/{spec}" if base else spec

    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        if pkt.device != HOST_SERVICE_ID:
            return None
        if not pkt.payload or pkt.payload[0] != HOST_VERSION:
            return fb.build_fuji_response_wire(pkt.device, pkt.command, 2, b"")
        if pkt.command == HOST_CMD_GET_CURRENT:
            if not current:
                return build_host_get_current_response("", status=1)
            return build_host_get_current_response(current)
        if pkt.command == HOST_CMD_SET_CURRENT:
            if len(pkt.payload) < 3:
                return build_host_simple_response(pkt.command, status=2)
            spec_len = pkt.payload[1] | (pkt.payload[2] << 8)
            spec = pkt.payload[3:3 + spec_len].decode("utf-8")
            promote(resolve(spec))
            return build_host_simple_response(pkt.command)
        if pkt.command == HOST_CMD_LIST_HISTORY:
            text = "".join(f"{i} {uri}\n" for i, uri in enumerate(history))
            return build_host_list_history_response(text)
        if pkt.command == HOST_CMD_SELECT_HISTORY:
            if len(pkt.payload) != 2 or pkt.payload[1] >= len(history):
                return build_host_simple_response(pkt.command, status=5)
            promote(history[pkt.payload[1]])
            return build_host_simple_response(pkt.command)
        if pkt.command == HOST_CMD_DELETE_HISTORY:
            if len(pkt.payload) != 2 or pkt.payload[1] >= len(history):
                return build_host_simple_response(pkt.command, status=5)
            del history[pkt.payload[1]]
            return build_host_simple_response(pkt.command)
        return fb.build_fuji_response_wire(pkt.device, pkt.command, 8, b"")

    return _resp


def build_disk_mount_response(
    *,
    slot: int,
    mounted: bool = True,
    readonly: bool = False,
    img_type: int = 2,
    sector_size: int = 256,
    sector_count: int = 800,
    status: int = 0,
) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    flags = 0
    if mounted:
        flags |= 0x01
    if readonly:
        flags |= 0x02
    body = (
        bytes([dp.DISKPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + bytes([slot & 0xFF, img_type & 0xFF])
        + struct.pack("<H", sector_size)
        + struct.pack("<I", sector_count)
    )
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, dp.CMD_MOUNT, status, body)


def build_disk_create_response(
    *,
    img_type: int = 2,
    sector_size: int = 256,
    sector_count: int = 800,
    status: int = 0,
) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    body = (
        bytes([dp.DISKPROTO_VERSION, 0])
        + struct.pack("<H", 0)
        + bytes([img_type & 0xFF])
        + struct.pack("<H", sector_size)
        + struct.pack("<I", sector_count)
    )
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, dp.CMD_CREATE, status, body)

def build_disk_reinitialize_response(
    *,
    slot: int,
    sector_count: int,
    sector_size: int = 256,
    img_type: int = 2,
    status: int = 0,
) -> bytes:
    return build_disk_mount_like_response(
        command=dp.CMD_REINITIALIZE,
        slot=slot,
        sector_count=sector_count,
        sector_size=sector_size,
        img_type=img_type,
        status=status,
    )


def build_disk_unmount_response(status: int = 0) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, dp.CMD_UNMOUNT, status, b"")


def build_translate_configure_response(
    *,
    handle: int,
    ready: bool = True,
    translated_size: int = 0,
    status: int = 0,
) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    flags = 0x01 if ready else 0x00
    body = (
        bytes([netp.NETPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + struct.pack("<H", handle)
        + struct.pack("<I", translated_size)
    )
    return fb.build_fuji_response_wire(
        netp.NETWORK_DEVICE_ID, netp.CMD_TRANSLATE_CONFIGURE, status, body
    )


def build_network_open_response(
    *,
    handle: int,
    accepted: bool = True,
    needs_body_write: bool = False,
    proto_flags: int = 0x01,
    status: int = 0,
) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    flags = 0
    if accepted:
        flags |= 0x01
    if needs_body_write:
        flags |= 0x02
    body = (
        bytes([netp.NETPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + struct.pack("<H", handle)
        + bytes([proto_flags & 0xFF])
    )
    return fb.build_fuji_response_wire(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, status, body)


def build_network_read_response(
    *,
    handle: int,
    offset: int,
    data: bytes,
    eof: bool = False,
    truncated: bool = False,
    more_available: bool = False,
    status: int = 0,
) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    flags = 0
    if eof:
        flags |= 0x01
    if truncated:
        flags |= 0x02
    if more_available:
        flags |= 0x04
    body = (
        bytes([netp.NETPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + struct.pack("<H", handle)
        + struct.pack("<I", offset)
        + struct.pack("<H", len(data))
        + data
    )
    return fb.build_fuji_response_wire(netp.NETWORK_DEVICE_ID, netp.CMD_READ, status, body)


def build_network_write_response(
    *,
    handle: int,
    offset: int,
    written: int,
    status: int = 0,
) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    body = (
        bytes([netp.NETPROTO_VERSION, 0])
        + struct.pack("<H", 0)
        + struct.pack("<H", handle)
        + struct.pack("<I", offset)
        + struct.pack("<H", written)
    )
    return fb.build_fuji_response_wire(netp.NETWORK_DEVICE_ID, netp.CMD_WRITE, status, body)


def build_network_close_response(status: int = 0) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    body = bytes([netp.NETPROTO_VERSION, 0]) + struct.pack("<H", 0)
    return fb.build_fuji_response_wire(netp.NETWORK_DEVICE_ID, netp.CMD_CLOSE, status, body)


def build_network_info_response(
    *,
    handle: int,
    content_length: int,
    http_status: int = 200,
    status: int = 0,
) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    flags = 0x02 | 0x04
    body = (
        bytes([netp.NETPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + struct.pack("<H", handle)
        + struct.pack("<H", http_status)
        + struct.pack("<Q", content_length)
        + struct.pack("<I", 0)
    )
    return fb.build_fuji_response_wire(netp.NETWORK_DEVICE_ID, netp.CMD_INFO, status, body)


def build_network_info_read_response(
    *,
    handle: int,
    offset: int,
    data: bytes,
    eof: bool = False,
    truncated: bool = False,
    more_available: bool = False,
    status: int = 0,
) -> bytes:
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")
    flags = 0
    if eof:
        flags |= 0x01
    if truncated:
        flags |= 0x02
    if more_available:
        flags |= 0x04
    body = (
        bytes([netp.NETPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + struct.pack("<H", handle)
        + struct.pack("<I", offset)
        + struct.pack("<H", len(data))
        + data
    )
    return fb.build_fuji_response_wire(
        netp.NETWORK_DEVICE_ID, netp.CMD_INFO_READ, status, body
    )


@dataclass
class _NetworkHandle:
    url: str
    method: int
    data: bytes = b""
    translated_data: bytes | None = None
    written: bytearray = field(default_factory=bytearray)


def legacy_openbas_network_responder(
    *,
    http_fs_base_url: str,
    httpbin_base_url: str,
    tcp_echo_url: str,
) -> Responder:
    """Serve the old openbas BASIC integration tests through NetworkDevice.

    This models the tiny parts of http-fs, httpbin, and the TCP echo service
    that those BASIC programs consume, without requiring external services.
    """
    if netp is None:
        raise RuntimeError("fujinet_tools.netproto is unavailable")

    next_handle = 0x1200
    handles: dict[int, _NetworkHandle] = {}
    httpbin_get_url = f"{httpbin_base_url}/get"
    httpbin_netloc = httpbin_base_url.split("://", 1)[-1]

    def _read_lp_u16(payload: bytes, off: int) -> tuple[str, int]:
        n = int.from_bytes(payload[off:off + 2], "little")
        off += 2
        text = payload[off:off + n].decode("utf-8", errors="replace")
        return text, off + n

    def _parse_open(payload: bytes) -> tuple[int, str]:
        method = payload[1]
        url, _ = _read_lp_u16(payload, 3)
        return method, url

    def _parse_handle_offset_len(payload: bytes) -> tuple[int, int, int]:
        handle = int.from_bytes(payload[1:3], "little")
        offset = int.from_bytes(payload[3:7], "little")
        max_len = int.from_bytes(payload[7:9], "little")
        return handle, offset, max_len

    def _parse_write(payload: bytes) -> tuple[int, int, bytes]:
        handle, offset, data_len = _parse_handle_offset_len(payload)
        return handle, offset, payload[9:9 + data_len]

    def _parse_translate(payload: bytes) -> tuple[int, str]:
        handle = int.from_bytes(payload[1:3], "little")
        selector_len = int.from_bytes(payload[5:7], "little")
        selector = payload[7:7 + selector_len].decode("utf-8", errors="replace")
        return handle, selector

    def _initial_data_for_url(url: str) -> bytes:
        base_url = url.split("?", 1)[0]
        if base_url == f"{http_fs_base_url}/bbc/tests/hello_print_hash.txt":
            return b"\x00\x05OLLEH"
        if base_url == f"{http_fs_base_url}/bbc/tests/simple.txt":
            return b"FujiNet OPENIN BGET Test"
        if base_url == httpbin_get_url:
            body = (
                '{"url":"%s","headers":{"Host":"%s"},"method":"GET"}'
                % (httpbin_get_url, httpbin_netloc)
            )
            return body.encode("utf-8")
        return b""

    def _translated_data(state: _NetworkHandle, selector: str) -> bytes:
        if selector == "/url":
            return httpbin_get_url.encode("utf-8")
        if selector == "/headers/Host":
            return httpbin_netloc.encode("utf-8")
        if selector == "/method":
            return (b"POST" if state.method != 1 else b"GET")
        return b""

    def _read_data(state: _NetworkHandle, offset: int, max_len: int) -> tuple[bytes, bool]:
        if state.translated_data is not None:
            source = state.translated_data
        elif state.url == tcp_echo_url:
            source = bytes(state.written)
        else:
            source = state.data
        chunk = source[offset:offset + max_len]
        return chunk, offset + len(chunk) >= len(source)

    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        nonlocal next_handle
        if pkt.device != netp.NETWORK_DEVICE_ID:
            return None
        if pkt.command == netp.CMD_OPEN:
            method, url = _parse_open(pkt.payload)
            handle = next_handle
            next_handle += 1
            handles[handle] = _NetworkHandle(
                url=url,
                method=method,
                data=_initial_data_for_url(url),
            )
            proto_flags = netp.PROTO_FLAG_SEQUENTIAL_READ
            if method != 1 or url == tcp_echo_url:
                proto_flags |= netp.PROTO_FLAG_SEQUENTIAL_WRITE
            return build_network_open_response(handle=handle, proto_flags=proto_flags)
        if pkt.command == netp.CMD_READ:
            handle, offset, max_len = _parse_handle_offset_len(pkt.payload)
            state = handles.get(handle)
            if state is None:
                return build_network_read_response(handle=handle, offset=offset, data=b"", eof=True)
            data, eof = _read_data(state, offset, max_len)
            return build_network_read_response(handle=handle, offset=offset, data=data, eof=eof)
        if pkt.command == netp.CMD_INFO_READ:
            handle, offset, max_len = _parse_handle_offset_len(pkt.payload)
            state = handles.get(handle)
            if state is None:
                return build_network_info_read_response(handle=handle, offset=offset, data=b"", eof=True)
            data, eof = _read_data(state, offset, max_len)
            return build_network_info_read_response(
                handle=handle, offset=offset, data=data, eof=eof
            )
        if pkt.command == netp.CMD_WRITE:
            handle, offset, data = _parse_write(pkt.payload)
            state = handles.get(handle)
            if state is None:
                return build_network_write_response(handle=handle, offset=offset, written=0, status=1)
            end = offset + len(data)
            if end > len(state.written):
                state.written.extend(bytes(end - len(state.written)))
            state.written[offset:end] = data
            return build_network_write_response(handle=handle, offset=offset, written=len(data))
        if pkt.command == netp.CMD_INFO:
            handle = int.from_bytes(pkt.payload[1:3], "little")
            state = handles.get(handle)
            if state is None:
                return build_network_info_response(handle=handle, content_length=0, status=1)
            source = state.translated_data if state.translated_data is not None else state.data
            if state.url == tcp_echo_url:
                source = bytes(state.written)
            return build_network_info_response(handle=handle, content_length=len(source))
        if pkt.command == netp.CMD_TRANSLATE_CONFIGURE:
            handle, selector = _parse_translate(pkt.payload)
            state = handles.get(handle)
            if state is None:
                return build_translate_configure_response(handle=handle, translated_size=0, status=1)
            state.translated_data = _translated_data(state, selector)
            return build_translate_configure_response(
                handle=handle,
                translated_size=len(state.translated_data),
            )
        if pkt.command == netp.CMD_CLOSE:
            handle = int.from_bytes(pkt.payload[1:3], "little")
            handles.pop(handle, None)
            return build_network_close_response()
        return None

    return _resp


def resolving_responder(resolved_uri: str, display_path: str) -> Responder:
    """A responder that answers RESOLVE_PATH properly and others generically."""
    host_resp = host_service_responder([resolved_uri])

    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        host_reply = host_resp(pkt)
        if host_reply is not None:
            return host_reply
        if fp is not None and pkt.device == fp.FILE_DEVICE_ID and pkt.command == FILE_CMD_RESOLVE_PATH:
            return build_resolve_path_response(resolved_uri, display_path)
        return default_success_responder(pkt)
    return _resp


def file_listing_responder(
    *,
    resolved_uri: str,
    display_path: str,
    formatted_text: str,
) -> Responder:
    """Resolve a host/path then answer LIST with formatted directory text."""
    host_resp = host_service_responder([resolved_uri])

    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        host_reply = host_resp(pkt)
        if host_reply is not None:
            return host_reply
        if fp is None:
            return default_success_responder(pkt)
        if pkt.device == fp.FILE_DEVICE_ID and pkt.command == FILE_CMD_RESOLVE_PATH:
            return build_resolve_path_response(resolved_uri, display_path)
        if pkt.device == fp.FILE_DEVICE_ID and pkt.command == fp.CMD_LIST:
            return build_list_response(formatted_text=formatted_text)
        return default_success_responder(pkt)

    return _resp


def mounted_disk_responder(
    *,
    slot: int,
    uri: str,
    mode: str = "auto",
    readonly: bool = False,
) -> Responder:
    """Answer Fuji slot lookup plus subsequent Disk mount/unmount requests."""
    mount_enabled = True

    def _mounts_text() -> str:
        if not mount_enabled:
            return ""
        return f"{slot}: {mode.upper()} {uri}\n"

    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        nonlocal mount_enabled
        slot_reply = appstore_slot_read_response(pkt, slot, uri, mode)
        if slot_reply is not None:
            return slot_reply
        if fuji is not None and pkt.device == fuji.FUJI_DEVICE_ID:
            if pkt.command == fuji.CMD_GET_MOUNTS:
                return build_get_mounts_response(_mounts_text())
            if pkt.command == fuji.CMD_GET_MOUNT:
                return build_get_mount_response(slot=slot, enabled=mount_enabled, uri=uri, mode=mode)
            if pkt.command == fuji.CMD_SET_MOUNT:
                if len(pkt.payload) >= 2 and pkt.payload[0] == slot:
                    mount_enabled = bool(pkt.payload[1])
                return build_set_mount_response()
        if dp is not None and pkt.device == dp.DISK_DEVICE_ID:
            if pkt.command == dp.CMD_MOUNT:
                return build_disk_mount_response(slot=slot + 1, readonly=readonly)
            if pkt.command == dp.CMD_UNMOUNT:
                return build_disk_unmount_response()
        return default_success_responder(pkt)

    return _resp


def full_stack_responder(
    *,
    resolved_uri: str,
    display_path: str,
    mount_slot: int,
    mount_uri: Optional[str] = None,
    formatted_mounts: str = "0: AUTO\n",
    translated_handle: int = 1,
    translated_size: int = 0,
) -> Responder:
    """Handle the common File/Fuji/Disk/Network flows used by fn-rom tests."""

    effective_mount_uri = mount_uri or resolved_uri
    host_resp = host_service_responder([resolved_uri])

    def _resp(pkt: FujiPacket) -> Optional[bytes]:
        host_reply = host_resp(pkt)
        if host_reply is not None:
            return host_reply
        if fp is not None and pkt.device == fp.FILE_DEVICE_ID:
            if pkt.command == FILE_CMD_RESOLVE_PATH:
                return build_resolve_path_response(resolved_uri, display_path)
            if pkt.command == fp.CMD_LIST:
                return build_list_response(formatted_text="FILE\n")
        if fuji is not None and pkt.device == fuji.FUJI_DEVICE_ID:
            if pkt.command == fuji.CMD_GET_MOUNTS:
                return build_get_mounts_response(formatted_mounts)
            if pkt.command == fuji.CMD_GET_MOUNT:
                return build_get_mount_response(
                    slot=mount_slot,
                    enabled=True,
                    uri=effective_mount_uri,
                )
            if pkt.command == fuji.CMD_SET_MOUNT:
                return build_set_mount_response()
        if dp is not None and pkt.device == dp.DISK_DEVICE_ID:
            if pkt.command == dp.CMD_MOUNT:
                return build_disk_mount_response(slot=mount_slot + 1)
            if pkt.command == dp.CMD_CREATE:
                return build_disk_create_response()
            if pkt.command == dp.CMD_UNMOUNT:
                return build_disk_unmount_response()
        if netp is not None and pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_TRANSLATE_CONFIGURE:
            return build_translate_configure_response(
                handle=translated_handle,
                ready=True,
                translated_size=translated_size,
            )
        if netp is not None and pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=translated_handle)
        return default_success_responder(pkt)

    return _resp


# --- Disk-image-backed responder: *RUN a transient utility from the boot disk ---

def build_disk_info_response(
    *, slot: int, sector_count: int, sector_size: int = 256,
    img_type: int = 2, mounted: bool = True, status: int = 0,
) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    flags = 0x01 if mounted else 0x00
    body = (
        bytes([dp.DISKPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + bytes([slot & 0xFF, img_type & 0xFF])
        + struct.pack("<H", sector_size)
        + struct.pack("<I", sector_count)
        + bytes([0])  # last_error
    )
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, dp.CMD_INFO, status, body)


def build_disk_read_sector_response(
    *, slot: int, lba: int, data: bytes, truncated: bool = False, status: int = 0,
) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    flags = 0x01 if truncated else 0x00
    body = (
        bytes([dp.DISKPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + bytes([slot & 0xFF])
        + struct.pack("<I", lba)
        + struct.pack("<H", len(data))
        + data
    )
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, dp.CMD_READ_SECTOR, status, body)


def build_disk_write_sector_response(
    *,
    slot: int,
    lba: int,
    written_len: int,
    status: int = 0,
) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    body = (
        bytes([dp.DISKPROTO_VERSION, 0])
        + struct.pack("<H", 0)
        + bytes([slot & 0xFF])
        + struct.pack("<I", lba)
        + struct.pack("<H", written_len)
    )
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, dp.CMD_WRITE_SECTOR, status, body)


def build_disk_mount_like_response(
    *,
    command: int,
    slot: int,
    mounted: bool = True,
    readonly: bool = False,
    sector_count: int = 800,
    sector_size: int = 256,
    img_type: int = 2,
    status: int = 0,
) -> bytes:
    if dp is None:
        raise RuntimeError("fujinet_tools.diskproto is unavailable")
    flags = 0
    if mounted:
        flags |= 0x01
    if readonly:
        flags |= 0x02
    body = (
        bytes([dp.DISKPROTO_VERSION, flags])
        + struct.pack("<H", 0)
        + bytes([slot & 0xFF, img_type & 0xFF])
        + struct.pack("<H", sector_size)
        + struct.pack("<I", sector_count)
    )
    return fb.build_fuji_response_wire(dp.DISK_DEVICE_ID, command, status, body)


def disk_image_responder(
    *, image_path, fuji_slot: int, drive_slot: int, uri: str,
    formatted_mounts: str | None = None, inner: "Responder | None" = None,
):
    """Serve a real DFS .ssd image so fn-rom can *RUN a file from it: Fuji slot
    lookup + Disk mount/info + Disk READ_SECTOR/WRITE_SECTOR.
    `inner` (if given) answers anything else first (e.g. the command's own
    FujiBus traffic once it runs)."""
    with open(image_path, "rb") as fh:
        image = bytearray(fh.read())
    nsec = max(1, len(image) // 256)
    host_resp = host_service_responder([uri])
    appstore: dict[tuple[str, str], bytes] = {}
    runtime_mounts: dict[int, tuple[str, str]] = {}
    available_images: dict[str, bytearray] = {
        uri: image,
        uri.rsplit("/", 1)[-1]: image,
    }
    mounted_images: dict[int, bytearray] = {}

    def _read_sector(lba: int, maxb: int) -> bytes:
        start = lba * 256
        data = bytes(image[start:start + min(maxb, 256)])
        if len(data) < 256:
            data = data + bytes(256 - len(data))
        return data

    def _write_sector(lba: int, data: bytes) -> int:
        start = lba * 256
        end = start + len(data)
        if end > len(image):
            image.extend(bytes(end - len(image)))
        image[start:end] = data
        return len(data)

    def _resp(pkt: "FujiPacket"):
        if pkt.device == 0xFE and pkt.command in (
            FILE_CMD_APPSTORE_READ,
            FILE_CMD_APPSTORE_WRITE,
            FILE_CMD_APPSTORE_DELETE,
        ):
            namespace, key, pos = _appstore_prefix(pkt.payload)
            store_key = (namespace, key)
            if pkt.command == FILE_CMD_APPSTORE_DELETE:
                appstore.pop(store_key, None)
                return default_success_responder(pkt)
            offset = int.from_bytes(pkt.payload[pos : pos + 4], "little")
            if pkt.command == FILE_CMD_APPSTORE_WRITE:
                data_len = int.from_bytes(pkt.payload[pos + 4 : pos + 6], "little")
                data = pkt.payload[pos + 6 : pos + 6 + data_len]
                old = appstore.get(store_key, b"")
                appstore[store_key] = old[:offset] + data + old[offset + len(data) :]
                return default_success_responder(pkt)
            return build_appstore_read_response(appstore.get(store_key), offset=offset)
        if inner is not None:
            r = inner(pkt)
            if r is not None:
                return r
        host_reply = host_resp(pkt)
        if host_reply is not None:
            return host_reply
        if fp is not None and pkt.device in (fp.FILE_DEVICE_ID, 0xFE):
            if pkt.command == FILE_CMD_RESOLVE_PATH:
                return build_resolve_path_response(uri, uri, device=pkt.device)
            if pkt.command == fp.CMD_LIST:
                return build_list_response(formatted_text="FN-BOOT\n", device=pkt.device)
        if fuji is not None and pkt.device == fuji.FUJI_DEVICE_ID:
            if pkt.command == fuji.CMD_GET_MOUNT:
                return build_get_mount_response(slot=fuji_slot, enabled=True, uri=uri)
            if pkt.command == fuji.CMD_SET_MOUNT:
                return build_set_mount_response()
            if pkt.command == fuji.CMD_GET_MOUNTS:
                text = formatted_mounts
                if text is None:
                    text = "".join(
                        f"{drive}: {mode} {mount_uri}\n"
                        for drive, (mode, mount_uri) in sorted(runtime_mounts.items())
                    )
                return build_get_mounts_response(text)
        if dp is not None and pkt.device == dp.DISK_DEVICE_ID:
            if pkt.command == dp.CMD_CREATE:
                uri_len = int.from_bytes(pkt.payload[9:11], "little")
                create_uri = pkt.payload[11:11 + uri_len].decode("utf-8")
                sector_count = int.from_bytes(pkt.payload[5:9], "little")
                available_images[create_uri] = bytearray(max(1, sector_count) * 256)
                return build_disk_create_response()
            if pkt.command == dp.CMD_MOUNT:
                drive = max(0, pkt.payload[1] - 1)
                flags = pkt.payload[2]
                uri_len = pkt.payload[6]
                mount_uri = pkt.payload[8:8 + uri_len].decode("utf-8")
                mount_image = available_images.get(mount_uri)
                if mount_image is None:
                    return build_disk_mount_response(
                        slot=pkt.payload[1], status=5
                    )
                mode = "RO" if flags & 0x01 else "AUTO"
                runtime_mounts[drive] = (mode, mount_uri)
                mounted_images[pkt.payload[1]] = mount_image
                return build_disk_mount_response(
                    slot=pkt.payload[1],
                    sector_count=max(1, len(mount_image) // 256),
                )
            if pkt.command == dp.CMD_UNMOUNT:
                drive = max(0, pkt.payload[1] - 1)
                runtime_mounts.pop(drive, None)
                mounted_images.pop(pkt.payload[1], None)
                return build_disk_unmount_response()
            if pkt.command == dp.CMD_REINITIALIZE:
                slot = pkt.payload[1]
                sector_size = int.from_bytes(pkt.payload[2:4], "little")
                sector_count = int.from_bytes(pkt.payload[4:8], "little")
                mount_image = mounted_images.get(slot)
                if mount_image is None:
                    return build_disk_reinitialize_response(
                        slot=slot, sector_count=sector_count, status=5
                    )
                if sector_size != 256 or sector_count not in (400, 800):
                    return build_disk_reinitialize_response(
                        slot=slot, sector_count=sector_count, status=5
                    )
                mount_image.clear()
                mount_image.extend(bytes(sector_count * sector_size))
                mount_image[0:5] = b"BLANK"
                mount_image[0x106] = (sector_count >> 8) & 0x03
                mount_image[0x107] = sector_count & 0xFF
                return build_disk_reinitialize_response(
                    slot=slot, sector_count=sector_count
                )
            if pkt.command == dp.CMD_INFO:
                mount_image = mounted_images.get(pkt.payload[1])
                return build_disk_info_response(
                    slot=pkt.payload[1],
                    mounted=mount_image is not None,
                    sector_count=max(1, len(mount_image or b"") // 256),
                )
            if pkt.command == dp.CMD_READ_SECTOR:
                mount_image = mounted_images.get(pkt.payload[1], bytearray())
                lba = int.from_bytes(pkt.payload[2:6], "little")
                maxb = int.from_bytes(pkt.payload[6:8], "little") or 256
                start = lba * 256
                data = bytes(mount_image[start:start + min(maxb, 256)])
                if len(data) < 256:
                    data += bytes(256 - len(data))
                return build_disk_read_sector_response(
                    slot=pkt.payload[1], lba=lba, data=data)
            if pkt.command == dp.CMD_WRITE_SECTOR:
                lba = int.from_bytes(pkt.payload[2:6], "little")
                data_len = int.from_bytes(pkt.payload[6:8], "little")
                data = pkt.payload[8:8 + data_len]
                written = _write_sector(lba, data)
                return build_disk_write_sector_response(
                    slot=pkt.payload[1], lba=lba, written_len=written
                )
        return default_success_responder(pkt)

    return _resp
