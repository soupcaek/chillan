"""Read Chillan's stealth code line from a screenshot of the top of the WoW window.

Layout (see Discord.lua): one row of cells, CELL_W x CELL_H physical pixels, starting at the
window's top-left. Each cell's R, G, B is one of four dark shades (2 bits each, 6 bits a cell).
Cells 0-3: marker (bright, dark, bright, dark). Cells 4-7: calibration (shade 0, 1, 2, 3).
Then the bit stream of [length hi, length lo, payload..., crc hi, crc lo], 6 bits per cell in
R(2) G(2) B(2) order, most significant bit first. CRC-16/CCITT-FALSE over the payload.
"""
import numpy as np

CELL_W, CELL_H = 2, 3
HEADER = 8
MIN_GAP = 30  # bright vs dark marker must differ by at least this much (0-255)


def crc16(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def _decode_row(px, cw):
    """px: (W, 3) RGB samples of one pixel row. cw: cell width in pixels (may be fractional)."""
    W = px.shape[0]

    def cell(i):
        x = int((i + 0.5) * cw)
        return px[x].astype(np.int32) if x < W else None

    head = [cell(i) for i in range(HEADER)]
    if any(h is None for h in head):
        return None
    hi, lo = head[0], head[1]
    if (hi - lo).min() < MIN_GAP or (head[2] - head[3]).min() < MIN_GAP:
        return None
    if np.abs(head[0] - head[2]).max() > 12 or np.abs(head[1] - head[3]).max() > 12:
        return None
    ref = np.stack(head[4:8])  # shade index -> (R, G, B) as captured
    # calibration must rise on every channel
    if (np.diff(ref, axis=0) < 6).any():
        return None

    def shades(c):
        return [int(np.argmin(np.abs(ref[:, ch] - c[ch]))) for ch in range(3)]

    bits = []

    def take(nbits, start_cell):
        """Make sure `bits` holds at least nbits, reading cells from start_cell on."""
        i = start_cell + len(bits) // 6
        while len(bits) < nbits:
            c = cell(i)
            if c is None:
                return False
            for s in shades(c):
                bits.extend(((s >> 1) & 1, s & 1))
            i += 1
        return True

    def byte(k):
        v = 0
        for b in bits[k * 8:(k + 1) * 8]:
            v = (v << 1) | b
        return v

    if not take(16, HEADER):
        return None
    n = (byte(0) << 8) | byte(1)
    if n == 0 or n > 2000:
        return None
    if not take((n + 4) * 8, HEADER):
        return None
    data = bytes(byte(2 + k) for k in range(n))
    crc = (byte(2 + n) << 8) | byte(3 + n)
    return data if crc == crc16(data) else None


def find_strips(img: np.ndarray, max_rows: int = 8):
    """img: top rows of the WoW client area (H x W x 3, RGB or BGR - the shades are grey-ish so
    channel order only matters for the calibration, which is per channel). Returns payloads."""
    if img.ndim != 3:
        return []
    found = []
    for y in range(min(max_rows, img.shape[0])):
        row = img[y, :, :3]
        for x0 in range(0, 3):
            for cw in (CELL_W, CELL_W * 1.25, CELL_W * 1.5, CELL_W * 2):
                data = _decode_row(row[x0:], cw)
                if data is not None:
                    if data not in found:
                        found.append(data)
                    break
            if found:
                return found
    return found
