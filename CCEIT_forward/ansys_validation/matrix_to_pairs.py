#!/usr/bin/env python3
"""Reduce Maxwell's 15x15 grounded Y matrix to the 120 floating-pair scans.

Run with ordinary Python after AEDT has produced B6_Maxwell_Ymatrix.tab.
The matrix reference terminal is electrode 16. The parser accepts a TSV with
15 rows of 30 real/imaginary numbers (optionally preceded by a row number or
frequency), or a flat 450-number payload. If the installed AEDT export layout
differs, it stops with a diagnostic instead of guessing silently.
"""
import argparse
import csv
import math
import os
import re


NUMBER = re.compile(r"(?<![A-Za-z_])[-+]?(?:\d+\.?\d*|\.\d+)(?:[Ee][-+]?\d+)?")


def read_complex_matrix(path, n=15):
    with open(path, "r", encoding="utf-8-sig", errors="replace") as f:
        lines = f.readlines()
    rows = []
    all_values = []
    for line in lines:
        vals = [float(x) for x in NUMBER.findall(line)]
        # Ignore headings and port-index labels, which may themselves contain
        # digits. Physical matrix values are exported with decimal notation.
        if not vals or not re.search(r"[.Ee]", line):
            continue
        all_values.extend(vals)
        if len(vals) == 2 * n:
            rows.append(vals)
        elif len(vals) == 2 * n + 1 and (vals[0].is_integer() or vals[0] > 1e4):
            rows.append(vals[1:])
        elif len(vals) == 2 * n + 2:
            if vals[0].is_integer() and vals[1] > 1e4:
                rows.append(vals[2:])
            elif vals[0] > 1e4 and vals[1].is_integer():
                rows.append(vals[2:])
    if len(rows) >= n:
        # AEDT files can contain repeated setup/frequency blocks; use final block.
        rows = rows[-n:]
        flat = [v for row in rows for v in row]
    elif len(all_values) == 2 * n * n:
        flat = all_values
    elif len(all_values) == 2 * n * n + 1 and all_values[0] > 1e4:
        flat = all_values[1:]
    else:
        raise ValueError(
            "Could not identify 15 rows of 15 complex entries in the Maxwell "
            "export. Expected 450 real/imaginary values; inspect the .tab file "
            "and adapt this parser to its actual layout."
        )
    if len(flat) != 2 * n * n:
        raise ValueError("Internal parse error: expected exactly 450 real/imag values")
    return [[complex(flat[2 * (i * n + j)], flat[2 * (i * n + j) + 1])
             for j in range(n)] for i in range(n)]


def solve_complex(a, b):
    """Small pivoted Gauss-Jordan solve; avoids external Python packages."""
    n = len(b)
    m = [list(map(complex, a[i])) + [complex(b[i])] for i in range(n)]
    for k in range(n):
        pivot = max(range(k, n), key=lambda i: abs(m[i][k]))
        if abs(m[pivot][k]) < 1e-30:
            raise ValueError("Singular terminal constraint system")
        m[k], m[pivot] = m[pivot], m[k]
        div = m[k][k]
        m[k] = [v / div for v in m[k]]
        for i in range(n):
            if i == k:
                continue
            factor = m[i][k]
            if factor:
                m[i] = [m[i][j] - factor * m[k][j] for j in range(n + 1)]
    return [m[i][-1] for i in range(n)]


def restore_full_matrix(y_ref):
    """Restore the 16-terminal matrix from the 15-terminal grounded form."""
    n = len(y_ref) + 1
    y = [[0j] * n for _ in range(n)]
    for i in range(n - 1):
        for j in range(n - 1):
            y[i][j] = y_ref[i][j]
    for i in range(n - 1):
        y[i][n - 1] = -sum(y_ref[i])
        y[n - 1][i] = -sum(y_ref[k][i] for k in range(n - 1))
    y[n - 1][n - 1] = sum(sum(row) for row in y_ref)
    return y


def pair_scan(y, n=16):
    out = []
    for tx in range(n):
        for rx in range(tx + 1, n):
            floating = [e for e in range(n) if e not in (tx, rx)]
            # I_floating=0, U_tx-U_rx=1 V, and mean(U)=0 fix gauge.
            a = [y[e][:] for e in floating]
            rhs = [0j] * len(floating)
            row = [0j] * n
            row[tx], row[rx] = 1, -1
            a.append(row)
            rhs.append(1 + 0j)
            a.append([1 + 0j] * n)
            rhs.append(0j)
            u = solve_complex(a, rhs)
            cur = [sum(y[i][j] * u[j] for j in range(n)) for i in range(n)]
            it = cur[tx]
            scale = max(abs(it), 1e-30)
            dcc = abs(sum(cur)) / scale
            floating_ratio = max(abs(cur[e]) for e in floating) / scale
            # The zero-mean gauge is only numerical; shift to the acquisition
            # convention U_tx=1 V and U_rx=0 V before saving terminal values.
            dev_u = abs((u[tx] - u[rx]) - 1)
            gauge = u[rx]
            u = [value - gauge for value in u]
            out.append({
                "pair_index": len(out) + 1, "tx": tx + 1, "rx": rx + 1,
                "pair_separation": min(rx - tx, n - (rx - tx)),
                "U_tx_re_V": u[tx].real, "U_tx_im_V": u[tx].imag,
                "U_rx_re_V": u[rx].real, "U_rx_im_V": u[rx].imag,
                "I_tx_re_A": it.real, "I_tx_im_A": it.imag,
                "I_rx_re_A": cur[rx].real, "I_rx_im_A": cur[rx].imag,
                "Y_re_S_per_m_depth": it.real, "Y_im_S_per_m_depth": it.imag,
                "abs_Y_S_per_m_depth": abs(it),
                "phase_Y_deg": math.degrees(math.atan2(it.imag, it.real)),
                "dcc": dcc, "floating_over_It": floating_ratio,
                "dev_U_V": dev_u,
            })
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("matrix", nargs="?", help="Maxwell Y matrix .tab file")
    args = parser.parse_args()
    here = os.path.dirname(os.path.abspath(__file__))
    source = args.matrix or os.path.join(here, "results", "B6_Maxwell_Ymatrix.tab")
    outpath = os.path.join(here, "results", "B6_Maxwell_pairs_120.csv")
    if not os.path.isfile(source):
        raise SystemExit("Matrix file not found: " + source)
    y = restore_full_matrix(read_complex_matrix(source))
    rows = pair_scan(y)
    os.makedirs(os.path.dirname(outpath), exist_ok=True)
    with open(outpath, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0].keys()))
        writer.writeheader()
        writer.writerows(rows)
    print("Wrote 120 acquisition-order voltage-driven/current-sense pairs:")
    print(outpath)
    print("Check a single pair against EIDORS before treating this as validation.")


if __name__ == "__main__":
    main()
