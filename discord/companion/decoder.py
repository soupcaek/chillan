"""Find and decode Chillan's code strip in a screenshot of the top of the WoW window.

Strip layout (in cells, see Discord.lua): a black quiet zone, then columns of 18 cells:
row 0 and row 17 white, rows 1..16 = 16 data bits (MSB at the top).
Column 0 = all white, column 1 = 0xAAAA, column 2 = 0x5555, column 3 = payload length,
then 2 payload bytes per column, then CRC-16/CCITT-FALSE of the payload.
"""
import numpy as np

ROWS = 18          # 16 data rows + top and bottom border
SYNC1, SYNC2 = 0xAAAA, 0x5555
MIN_RUN_CELLS = 8  # the top border is at least this many cells wide


def crc16(data: bytes) -> int:
    crc = 0xFFFF
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) & 0xFFFF if crc & 0x8000 else (crc << 1) & 0xFFFF
    return crc


def _binary(img: np.ndarray) -> np.ndarray:
    """RGB/RGBA/grey image -> boolean 'white' mask."""
    if img.ndim == 3:
        img = img[:, :, :3].astype(np.uint16).sum(axis=2) // 3
    return img > 128


def _col_value(bw, x0, y0, csx, csy, col):
    """Read the 16 data bits of one column, sampling each cell's centre (cell sizes may be fractional)."""
    cx = int(x0 + (col + 0.5) * csx)
    if cx >= bw.shape[1]:
        return None
    v = 0
    for r in range(1, 17):
        cy = int(y0 + (r + 0.5) * csy)
        if cy >= bw.shape[0]:
            return None
        v = (v << 1) | int(bw[cy, cx])
    # borders must be white
    if not bw[int(y0 + 0.5 * csy), cx] or not bw[min(bw.shape[0] - 1, int(y0 + 17.5 * csy)), cx]:
        return None
    return v


def _read(bw, x0, y0, csx, csy):
    if _col_value(bw, x0, y0, csx, csy, 0) != 0xFFFF:
        return None, None
    if _col_value(bw, x0, y0, csx, csy, 1) != SYNC1 or _col_value(bw, x0, y0, csx, csy, 2) != SYNC2:
        return None, None
    n = _col_value(bw, x0, y0, csx, csy, 3)
    if n is None or n == 0 or n > 4000:
        return None, None
    data = bytearray()
    for i in range((n + 1) // 2):
        v = _col_value(bw, x0, y0, csx, csy, 4 + i)
        if v is None:
            return None, n
        data += bytes((v >> 8, v & 0xFF))
    data = bytes(data[:n])
    crc = _col_value(bw, x0, y0, csx, csy, 4 + (n + 1) // 2)
    if crc is not None and crc == crc16(data):
        return data, n
    return None, n


def _try_at(bw, x0, y0, max_cs=6):
    """Try to decode a strip whose top-left cell starts at (x0, y0)."""
    # column 0 is all white: its height gives the cell height
    h = 0
    while y0 + h < bw.shape[0] and bw[y0 + h, x0]:
        h += 1
    csy = h / ROWS
    if csy < 0.9 or csy > max_cs + 0.5:
        return None
    # the top border runs across every column: its length gives the cell width once we know the column count
    row = bw[int(y0 + 0.5 * csy)]
    run = 0
    while x0 + run < bw.shape[1] and row[x0 + run]:
        run += 1
    for csx in (csy, round(csy) or 1.0):
        data, n = _read(bw, x0, y0, csx, csy)
        if data is not None:
            return data
        if n:
            ncols = 4 + (n + 1) // 2 + 1
            fit = run / ncols
            if abs(fit - csx) <= 0.25 * csx:
                data, _ = _read(bw, x0, y0, fit, csy)
                if data is not None:
                    return data
    return None


def find_strips(img: np.ndarray, max_cs: int = 6):
    """Return a list of decoded payloads (bytes) found in the image."""
    bw = _binary(img)
    H, W = bw.shape
    found = []
    seen_rows = set()
    for y in range(H):
        row = bw[y]
        if not row.any():
            continue
        # white runs in this row
        padded = np.concatenate(([False], row, [False]))
        d = np.diff(padded.astype(np.int8))
        starts = np.where(d == 1)[0]
        ends = np.where(d == -1)[0]
        for s, e in zip(starts, ends):
            if e - s < MIN_RUN_CELLS:
                continue
            # the top border must have black above it (quiet zone)
            if y > 0 and bw[y - 1, s:e].any():
                continue
            key = (y, s)
            if key in seen_rows:
                continue
            seen_rows.add(key)
            data = _try_at(bw, s, y, max_cs)
            if data is not None:
                found.append(data)
    return found
