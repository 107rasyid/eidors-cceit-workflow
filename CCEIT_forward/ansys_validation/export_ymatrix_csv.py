"""Reduce Maxwell's grounded 15-port matrix to 120 floating-pair responses.

This file intentionally uses only the Python standard library so it can run
from the AEDT script runner (IronPython) as well as ordinary Python.
"""
import cmath
import math
import os
import sys

FREQ_HZ = 500e3
N_SIGNAL = 15
N_ELECTRODES = 16
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
RESULTS_DIR = os.path.join(SCRIPT_DIR, "results")


def load_report_matrix(path, scale, expected_freq_hz=FREQ_HZ):
    """Read one flat 15x15 matrix row from an AEDT report CSV."""
    stream = open(path, "r")
    try:
        lines = stream.readlines()
    finally:
        stream.close()
    for line in lines[1:]:
        fields = [field.strip().strip('"') for field in line.strip().split(",")]
        if len(fields) != 1 + N_SIGNAL * N_SIGNAL:
            continue
        try:
            frequency_hz = float(fields[0]) * 1e3  # AEDT reports kHz.
            values = [float(value) * scale for value in fields[1:]]
        except (ValueError, TypeError):
            continue
        if abs(frequency_hz - expected_freq_hz) > max(1e-6, expected_freq_hz * 1e-9):
            raise ValueError("%s: %.9g Hz, expected %.9g Hz" %
                             (path, frequency_hz, expected_freq_hz))
        if any((math.isnan(value) or math.isinf(value)) for value in values):
            raise ValueError("%s contains NaN or Inf" % path)
        return [values[row * N_SIGNAL:(row + 1) * N_SIGNAL]
                for row in range(N_SIGNAL)]
    raise ValueError("%s: no valid numeric 15x15 matrix row" % path)


def load_grounded_admittance(results_dir):
    """Prefer direct Re(Y)/Im(Y); fall back to G/C only if absent."""
    yre_path = os.path.join(results_dir, "B6_Maxwell_Yre_uS.csv")
    yim_path = os.path.join(results_dir, "B6_Maxwell_Yim_uS.csv")
    g_path = os.path.join(results_dir, "B6_Maxwell_G_uS.csv")
    c_path = os.path.join(results_dir, "B6_Maxwell_C_pF.csv")

    if os.path.isfile(yre_path) and os.path.isfile(yim_path):
        real_y = load_report_matrix(yre_path, 1e-6)
        imag_y = load_report_matrix(yim_path, 1e-6)
        print("Source reports: direct Re(Y) and Im(Y) (preferred)")
        # Compare G with Re(Y) when both reports exist; AEDT G() may use a
        # different report scaling in some matrix entries.
        if os.path.isfile(g_path):
            conductance = load_report_matrix(g_path, 1e-6)
            discrepancy = max(abs(conductance[i][j] - real_y[i][j])
                              for i in range(N_SIGNAL) for j in range(N_SIGNAL))
            if discrepancy > 1e-9:
                print("WARNING: G and Re(Y) reports differ (max %.6g S); using Re(Y)."
                      % discrepancy)
        return [[complex(real_y[i][j], imag_y[i][j])
                 for j in range(N_SIGNAL)] for i in range(N_SIGNAL)]

    if os.path.isfile(g_path) and os.path.isfile(c_path):
        conductance = load_report_matrix(g_path, 1e-6)
        capacitance = load_report_matrix(c_path, 1e-12)
        print("Source reports: G and C; Y = G + j*2*pi*f*C")
        return [[complex(conductance[i][j], 2.0 * math.pi * FREQ_HZ * capacitance[i][j])
                 for j in range(N_SIGNAL)] for i in range(N_SIGNAL)]
    raise IOError("Need direct Yre/Yim reports or G/C reports in %s" % results_dir)


def reconstruct_full_matrix(y_grounded):
    """Restore electrode 16 using current conservation (row/column sums zero)."""
    y_full = [[0j for unused_col in range(N_ELECTRODES)]
              for unused_row in range(N_ELECTRODES)]
    for i in range(N_SIGNAL):
        for j in range(N_SIGNAL):
            y_full[i][j] = y_grounded[i][j]
        y_full[i][N_SIGNAL] = -sum(y_grounded[i])
    for j in range(N_SIGNAL):
        y_full[N_SIGNAL][j] = -sum(y_grounded[i][j] for i in range(N_SIGNAL))
    y_full[N_SIGNAL][N_SIGNAL] = sum(sum(row) for row in y_grounded)
    return y_full


def solve_linear(matrix, rhs):
    """Solve complex A X=B with pivoted Gaussian elimination."""
    n = len(matrix)
    m = len(rhs[0])
    a = [list(matrix[i]) + list(rhs[i]) for i in range(n)]
    for col in range(n):
        pivot = max(range(col, n), key=lambda row: abs(a[row][col]))
        if abs(a[pivot][col]) < 1e-30:
            raise ValueError("singular floating-electrode submatrix")
        a[col], a[pivot] = a[pivot], a[col]
        divisor = a[col][col]
        for j in range(col, n + m):
            a[col][j] /= divisor
        for row in range(n):
            if row == col:
                continue
            factor = a[row][col]
            for j in range(col, n + m):
                a[row][j] -= factor * a[col][j]
    return [row[n:n + m] for row in a]


def pair_admittance(y_full, tx, rx):
    """Admittance with tx/rx retained and all other electrodes floating."""
    kept = [tx, rx]
    floating = [index for index in range(N_ELECTRODES) if index not in kept]
    y_kk = [[y_full[i][j] for j in kept] for i in kept]
    y_kf = [[y_full[i][j] for j in floating] for i in kept]
    y_fk = [[y_full[i][j] for j in kept] for i in floating]
    y_ff = [[y_full[i][j] for j in floating] for i in floating]
    solved = solve_linear(y_ff, y_fk)
    correction = [[sum(y_kf[i][k] * solved[k][j] for k in range(len(floating)))
                   for j in range(2)] for i in range(2)]
    reduced_01 = y_kk[0][1] - correction[0][1]
    return -reduced_01


def main():
    results_dir = os.path.abspath(sys.argv[1]) if len(sys.argv) > 1 else RESULTS_DIR
    grounded_y = load_grounded_admittance(results_dir)
    max_y = max(abs(value) for row in grounded_y for value in row)
    asymmetry = max(abs(grounded_y[i][j] - grounded_y[j][i])
                    for i in range(N_SIGNAL) for j in range(N_SIGNAL)) / max(max_y, 1e-30)
    max_real = max(abs(value.real) for row in grounded_y for value in row)
    max_imag = max(abs(value.imag) for row in grounded_y for value in row)
    print("15-port matrix: max|Re(Y)|=%.6g S, max|Im(Y)|=%.6g S" %
          (max_real, max_imag))
    print("matrix reciprocity residual=%.3e" % asymmetry)
    if max_real == 0:
        raise ValueError("Re(Y) is identically zero; refusing to export phase-only data")
    if asymmetry > 1e-3:
        print("WARNING: matrix is not symmetric; check AEDT report ordering and solve.")

    y_full = reconstruct_full_matrix(grounded_y)
    output = os.path.join(results_dir, "B6_Maxwell_pairs_120.csv")
    stream = open(output, "w")
    try:
        stream.write("Yreal,Yim,abs_Y,phase\n")
        pair_count = 0
        for tx in range(N_ELECTRODES):
            for rx in range(tx + 1, N_ELECTRODES):
                pair_count += 1
                value = pair_admittance(y_full, tx, rx)
                stream.write("%.12g,%.12g,%.12g,%.9g\n" %
                             (value.real, value.imag, abs(value),
                              math.degrees(cmath.phase(value))))
    finally:
        stream.close()
    print("Wrote %d acquisition-order pair rows -> %s" % (pair_count, output))


if __name__ == "__main__":
    main()
