from __future__ import annotations

import time

import pytest

from fujinet_tools import fujibus as fb
from fujinet_tools import netproto as netp

from fuji_device import (
    build_network_close_response,
    build_network_open_response,
    build_network_read_response,
    build_network_write_response,
    build_translate_configure_response,
)
from helpers import command, run_basic_program

# Every test here drives the network device (OPENIN "scheme://", *FJSON, OSWORD &78),
# which only exists in the DISK+NET build (FEATURE_NET). Skipped on --fn-profile disk.
pytestmark = pytest.mark.needs_net


def _decode_open_payload(payload: bytes):
    off = 0
    version = payload[off]
    off += 1
    method = payload[off]
    off += 1
    flags = payload[off]
    off += 1
    url_len = payload[off] | (payload[off + 1] << 8)
    off += 2
    url = payload[off:off + url_len].decode("utf-8")
    return version, method, flags, url


def _decode_read_payload(payload: bytes):
    pkt = fb.parse_fuji_packet(fb.slip_decode(payload))
    assert pkt is not None
    resp = netp.parse_read_resp(pkt.payload)
    return resp.handle, resp.offset, resp.data, resp.eof


def _decode_write_payload(payload: bytes):
    version = payload[0]
    handle = int.from_bytes(payload[1:3], "little")
    offset = int.from_bytes(payload[3:7], "little")
    data_len = int.from_bytes(payload[7:9], "little")
    data = payload[9:9 + data_len]
    return version, handle, offset, data


def test_openin_emits_network_open_request(beebium, fuji_device):
    handle = 0x1234

    def responder(pkt):
        if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        return None

    fuji_device.set_responder(responder)

    run_basic_program(beebium, ['10 A%=OPENIN("http://example.com/data.json")'])

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None
    assert open_pkt.checksum_ok
    version, method, flags, url = _decode_open_payload(open_pkt.payload)
    assert version == netp.NETPROTO_VERSION
    assert method == 1
    assert flags == 0x08
    assert url == "http://example.com/data.json"


def test_openin_bget_close_cycle_emits_open_read_close(beebium, fuji_device):
    handle = 0x1234
    body = b"OK"

    def responder(pkt):
        if pkt.device != netp.NETWORK_DEVICE_ID:
            return None
        if pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        if pkt.command == netp.CMD_READ:
            return build_network_read_response(handle=handle, offset=0, data=body, eof=True)
        if pkt.command == netp.CMD_CLOSE:
            return build_network_close_response()
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            '10 H%=OPENIN("http://example.com/data.txt")',
            '20 A%=BGET#H%',
            '30 B%=BGET#H%',
            '40 CLOSE#H%',
        ],
    )

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None and open_pkt.checksum_ok
    version, method, flags, url = _decode_open_payload(open_pkt.payload)
    assert version == netp.NETPROTO_VERSION
    assert method == 1
    assert flags == 0x08
    assert url == "http://example.com/data.txt"

    read_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_READ, timeout=8.0)
    assert read_pkt is not None and read_pkt.checksum_ok
    handle_seen, offset_seen, data_seen, _ = _decode_read_payload(
        build_network_read_response(handle=handle, offset=0, data=body, eof=True)
    )
    req_version = read_pkt.payload[0]
    req_handle = int.from_bytes(read_pkt.payload[1:3], "little")
    req_offset = int.from_bytes(read_pkt.payload[3:7], "little")
    req_max = int.from_bytes(read_pkt.payload[7:9], "little")
    assert req_version == netp.NETPROTO_VERSION
    assert req_handle == handle_seen == handle
    assert req_offset == offset_seen == 0
    assert req_max == 256
    assert data_seen == body

    close_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_CLOSE, timeout=8.0)
    assert close_pkt is not None and close_pkt.checksum_ok
    assert close_pkt.payload == netp.build_close_req(handle)


def test_openin_fjson_bget_close_cycle_emits_open_translate_read_close(beebium, fuji_device):
    handle = 0x1234
    translated = b"42"

    def responder(pkt):
        if pkt.device != netp.NETWORK_DEVICE_ID:
            return None
        if pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        if pkt.command == netp.CMD_TRANSLATE_CONFIGURE:
            return build_translate_configure_response(handle=handle, translated_size=len(translated))
        if pkt.command == netp.CMD_READ:
            return build_network_read_response(handle=handle, offset=0, data=translated, eof=True)
        if pkt.command == netp.CMD_CLOSE:
            return build_network_close_response()
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            '10 H%=OPENIN("http://example.com/data.json")',
            '20 OSCLI "FJSON "+STR$(H%)+" /value"',
            '30 A%=BGET#H%',
            '40 B%=BGET#H%',
            '50 CLOSE#H%',
        ],
    )

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None and open_pkt.checksum_ok

    xlat_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_TRANSLATE_CONFIGURE, timeout=8.0)
    assert xlat_pkt is not None and xlat_pkt.checksum_ok
    assert xlat_pkt.payload == netp.build_translate_configure_req(
        handle,
        translation_type=netp.TRANSLATION_JSON,
        translation_flags=0,
        translation_selector="/value",
    )

    read_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_READ, timeout=8.0)
    assert read_pkt is not None and read_pkt.checksum_ok

    close_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_CLOSE, timeout=8.0)
    assert close_pkt is not None and close_pkt.checksum_ok


def test_osword78_reason04_long_url_then_openin_uses_buffered_url(beebium, fuji_device):
    handle = 0x1234

    def responder(pkt):
        if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            '10 DIM B% 16,C% 512',
            '20 A$="http://example.com/"',
            '30 B$=STRING$(200,"a")',
            '40 C$=STRING$(80,"b")',
            '50 N%=LEN(A$)',
            '60 $(C%)=A$+CHR$(0)',
            '70 $(C%+N%)=B$',
            '80 $(C%+N%+LEN(B$))=C$',
            '90 L%=N%+LEN(B$)+LEN(C$)',
            '100 B%?0=4:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=L% MOD 256:B%?5=L% DIV 256',
            '110 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '120 H%=OPENIN("://")',
        ],
    )

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None and open_pkt.checksum_ok
    version, method, flags, url = _decode_open_payload(open_pkt.payload)
    assert version == netp.NETPROTO_VERSION
    assert method == 1
    assert flags == 0x08
    assert url.startswith("http://example.com/")
    assert len(url) > 255


def test_osword78_reason00_long_json_query_emits_translate_configure(beebium, fuji_device):
    handle = 0x1234
    translated = b"value"
    path = "/value" + ("x" * 100)

    def responder(pkt):
        if pkt.device != netp.NETWORK_DEVICE_ID:
            return None
        if pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle)
        if pkt.command == netp.CMD_TRANSLATE_CONFIGURE:
            return build_translate_configure_response(handle=handle, translated_size=len(translated))
        if pkt.command == netp.CMD_READ:
            return build_network_read_response(handle=handle, offset=0, data=translated, eof=True)
        if pkt.command == netp.CMD_CLOSE:
            return build_network_close_response()
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            '10 DIM B% 16,C% 512',
            '20 P$="/value"+STRING$(100,"x")',
            '30 $(C%)=P$+CHR$(0)',
            '40 H%=OPENIN("http://example.com/data.json")',
            '50 B%?0=0:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=LEN(P$) MOD 256:B%?5=LEN(P$) DIV 256:B%?6=H%',
            '60 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '70 A%=BGET#H%',
            '80 CLOSE#H%',
        ],
    )

    pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_TRANSLATE_CONFIGURE, timeout=8.0)
    assert pkt is not None and pkt.checksum_ok
    assert pkt.payload == netp.build_translate_configure_req(
        handle,
        translation_type=netp.TRANSLATION_JSON,
        translation_flags=0,
        translation_selector=path,
    )


def test_osword78_reason01_02_03_post_flow_emits_open_write_close(beebium, fuji_device):
    handle = 0x1234
    body = b'{"msg":"hello"}'

    def responder(pkt):
        if pkt.device != netp.NETWORK_DEVICE_ID:
            return None
        if pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle, proto_flags=netp.PROTO_FLAG_SEQUENTIAL_WRITE)
        if pkt.command == netp.CMD_WRITE:
            return build_network_write_response(handle=handle, offset=0, written=len(body))
        if pkt.command == netp.CMD_CLOSE:
            return build_network_close_response()
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            '10 DIM B% 16,C% 512',
            '20 BODY$="{"+CHR$(34)+"msg"+CHR$(34)+":"+CHR$(34)+"hello"+CHR$(34)+"}"',
            '30 B%?0=1:B%?2=LEN(BODY$):B%?3=0:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '40 B%?0=3:B%?2=1:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '50 H%=OPENUP("http://example.com/anything")',
            '60 $(C%)=BODY$+CHR$(0)',
            '70 B%?0=2:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=LEN(BODY$):B%?5=0:B%?6=H%',
            '80 A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '90 CLOSE#H%',
        ],
    )

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None and open_pkt.checksum_ok
    version, method, flags, url = _decode_open_payload(open_pkt.payload)
    assert version == netp.NETPROTO_VERSION
    assert method == 2
    assert flags == 0x08
    assert url == "http://example.com/anything"

    write_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_WRITE, timeout=8.0)
    assert write_pkt is not None and write_pkt.checksum_ok
    req_version, req_handle, req_offset, req_data = _decode_write_payload(write_pkt.payload)
    assert req_version == netp.NETPROTO_VERSION
    assert req_handle == handle
    assert req_offset == 0
    assert req_data == body

    close_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_CLOSE, timeout=8.0)
    assert close_pkt is not None and close_pkt.checksum_ok


def test_osword78_reason02_two_writes_advance_write_offset(beebium, fuji_device):
    handle = 0x1234
    body1 = b"abc"
    body2 = b"defg"

    def responder(pkt):
        if pkt.device != netp.NETWORK_DEVICE_ID:
            return None
        if pkt.command == netp.CMD_OPEN:
            return build_network_open_response(handle=handle, proto_flags=netp.PROTO_FLAG_SEQUENTIAL_WRITE)
        if pkt.command == netp.CMD_WRITE:
            req_version, req_handle, req_offset, req_data = _decode_write_payload(pkt.payload)
            assert req_version == netp.NETPROTO_VERSION
            assert req_handle == handle
            return build_network_write_response(handle=handle, offset=req_offset, written=len(req_data))
        if pkt.command == netp.CMD_CLOSE:
            return build_network_close_response()
        return None

    fuji_device.set_responder(responder)

    run_basic_program(
        beebium,
        [
            '10 DIM B% 16,C% 512,D% 512',
            '20 A$="abc":B$="defg"',
            '30 $(C%)=A$+CHR$(0)',
            '40 $(D%)=B$+CHR$(0)',
            '50 B%?0=1:B%?2=LEN(A$)+LEN(B$):B%?3=0:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '60 H%=OPENUP("http://example.com/chunked")',
            '70 B%?0=2:B%?2=C% MOD 256:B%?3=C% DIV 256:B%?4=LEN(A$):B%?5=0:B%?6=H%:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '80 B%?0=2:B%?2=D% MOD 256:B%?3=D% DIV 256:B%?4=LEN(B$):B%?5=0:B%?6=H%:A%=&78:X%=B% MOD 256:Y%=B% DIV 256:CALL &FFF1',
            '90 CLOSE#H%',
        ],
    )

    open_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_OPEN, timeout=8.0)
    assert open_pkt is not None and open_pkt.checksum_ok

    deadline = time.monotonic() + 8.0
    while time.monotonic() < deadline:
        write_pkts = [
            pkt for pkt in fuji_device.requests
            if pkt.device == netp.NETWORK_DEVICE_ID and pkt.command == netp.CMD_WRITE
        ]
        if len(write_pkts) >= 2:
            break
        time.sleep(0.02)

    assert len(write_pkts) >= 2

    write_pkt1 = write_pkts[0]
    assert write_pkt1.checksum_ok
    req_version1, req_handle1, req_offset1, req_data1 = _decode_write_payload(write_pkt1.payload)
    assert req_version1 == netp.NETPROTO_VERSION
    assert req_handle1 == handle
    assert req_offset1 == 0
    assert req_data1 == body1

    write_pkt2 = write_pkts[1]
    assert write_pkt2.checksum_ok
    req_version2, req_handle2, req_offset2, req_data2 = _decode_write_payload(write_pkt2.payload)
    assert req_version2 == netp.NETPROTO_VERSION
    assert req_handle2 == handle
    assert req_offset2 == len(body1)
    assert req_data2 == body2

    close_pkt = fuji_device.wait_for_command(netp.NETWORK_DEVICE_ID, netp.CMD_CLOSE, timeout=8.0)
    assert close_pkt is not None and close_pkt.checksum_ok
