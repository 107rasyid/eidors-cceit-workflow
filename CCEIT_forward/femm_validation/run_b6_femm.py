"""Build a FEMM current-flow model from the saved B6 boundary geometry.

Purpose: cross-solver forward check of the explicit-layer B6 model.
Inputs: elmer_validation/B6_hmed2.00mm_hring0.35mm/B6_mesh_reference.mat.
Outputs: a FEMM .FEC current-flow model and pair-current CSV under results.
Implements: Section IV external-solver validation (separate from EIDORS runs).

The script preserves the exported Netgen boundary polylines, region interface,
and electrode IDs, then lets FEMM/Triangle mesh the interiors. FEMM cannot use
the EIDORS triangle connectivity through this workflow. Electrode contacts are
ideal conductors here; the small EIDORS z_el is therefore not reproduced.
"""

from __future__ import annotations

import argparse
import csv
import math
from pathlib import Path
from typing import Any

import numpy as np
from scipy.io import loadmat


ROOT = Path(__file__).resolve().parent.parent
REFERENCE_MAT = (
    ROOT
    / "elmer_validation"
    / "B6_hmed2.00mm_hring0.35mm"
    / "B6_mesh_reference.mat"
)
OUTPUT_DIR = Path(__file__).resolve().parent / "results"


def field(struct: Any, name: str) -> Any:
    """Read a field from a scipy MATLAB struct with a useful error."""
    if not hasattr(struct, name):
        raise ValueError(f"Saved B6 MAT is missing field {name!r}")
    return getattr(struct, name)


def scalar(struct: Any, name: str) -> float:
    return float(np.asarray(field(struct, name)).squeeze())


def read_reference() -> tuple[np.ndarray, np.ndarray, np.ndarray, dict[str, float]]:
    if not REFERENCE_MAT.is_file():
        raise FileNotFoundError(
            "Saved B6 reference is missing. Recreate it in Octave with "
            "setup_paths; run('elmer_validation/export_B6_mesh_for_elmer.m')."
        )

    data = loadmat(REFERENCE_MAT, squeeze_me=True, struct_as_record=False)
    mesh = data.get("mesh_export")
    params = data.get("P")
    if mesh is None or params is None:
        raise ValueError("B6 MAT must contain mesh_export and P structures")

    nodes_m = np.asarray(field(mesh, "nodes_m"), dtype=float).reshape((-1, 2))
    edges = np.asarray(field(mesh, "boundary_edges"), dtype=np.int64).reshape((-1, 2))
    boundary_ids = np.asarray(field(mesh, "boundary_id"), dtype=np.int64).reshape(-1)
    if len(edges) != len(boundary_ids):
        raise ValueError("B6 boundary edge and ID arrays have different lengths")
    if np.any(edges < 1) or np.any(edges > len(nodes_m)):
        raise ValueError("B6 boundary edges contain invalid one-based node IDs")

    values = {
        name: scalar(params, name)
        for name in (
            "nElec", "R", "d", "depth", "Vtx", "f", "sigma", "epsr",
            "sigma_d", "epsr_d", "z_el", "eps0",
        )
    }
    values["h_ring"] = scalar(field(mesh, "mesh_info"), "h_ring")
    values["h_medium"] = scalar(field(mesh, "mesh_info"), "h_medium")
    return nodes_m, edges, boundary_ids, values


def create_femm_model(
    femm: Any,
    nodes_m: np.ndarray,
    edges: np.ndarray,
    boundary_ids: np.ndarray,
    p: dict[str, float],
    model_file: Path,
) -> None:
    """Create the planar core/ring geometry and attach electrode conductors."""
    femm.openfemm()
    femm.newdocument(3)  # Current Flow
    femm.ci_probdef(
        "millimeters", "planar", p["f"], 1e-8, p["depth"] * 1000.0, 30
    )
    femm.ci_addmaterial(
        "B6 medium", p["sigma"], p["sigma"], p["epsr"], p["epsr"], 0, 0
    )
    femm.ci_addmaterial(
        "B6 dielectric ring", p["sigma_d"], p["sigma_d"],
        p["epsr_d"], p["epsr_d"], 0, 0,
    )

    n_elec = int(round(p["nElec"]))
    for electrode in range(1, n_elec + 1):
        # Current-flow conductor type 0 means prescribed total current.
        femm.ci_addconductorprop(f"E{electrode:02d}", 0, 0, 0)

    used_nodes = np.unique(edges.reshape(-1))
    node_xy_mm = nodes_m * 1000.0
    for node_id in used_nodes:
        x_mm, y_mm = node_xy_mm[node_id - 1]
        femm.ci_addnode(float(x_mm), float(y_mm))

    for (node_a, node_b), boundary_id in zip(edges, boundary_ids):
        xa, ya = node_xy_mm[node_a - 1]
        xb, yb = node_xy_mm[node_b - 1]
        femm.ci_addsegment(float(xa), float(ya), float(xb), float(yb))
        if 11 <= boundary_id <= 10 + n_elec:
            electrode = int(boundary_id - 10)
            midpoint = ((xa + xb) / 2.0, (ya + yb) / 2.0)
            femm.ci_clearselected()
            femm.ci_selectsegment(float(midpoint[0]), float(midpoint[1]))
            femm.ci_setsegmentprop(
                "", p["h_ring"] * 1000.0, 0, 0, 0, f"E{electrode:02d}"
            )
            femm.ci_clearselected()
        elif boundary_id == 2:
            midpoint = ((xa + xb) / 2.0, (ya + yb) / 2.0)
            femm.ci_clearselected()
            femm.ci_selectsegment(float(midpoint[0]), float(midpoint[1]))
            femm.ci_setsegmentprop("", p["h_ring"] * 1000.0, 0, 0, 0, "<None>")
            femm.ci_clearselected()

    # The saved boundary polylines retain the original B6 interface shape.
    for x_m, y_m, material, mesh_size_m in (
        (0.0, 0.0, "B6 medium", p["h_medium"]),
        (p["R"] + p["d"] / 2.0, 0.0, "B6 dielectric ring", p["h_ring"]),
    ):
        x_mm, y_mm = x_m * 1000.0, y_m * 1000.0
        femm.ci_addblocklabel(x_mm, y_mm)
        femm.ci_clearselected()
        femm.ci_selectlabel(x_mm, y_mm)
        femm.ci_setblockprop(material, 0, mesh_size_m * 1000.0, 0)
        femm.ci_clearselected()

    femm.ci_saveas(str(model_file))


def as_complex(value: Any) -> complex:
    """Normalize a scalar returned through pyFEMM's COM bridge."""
    array = np.asarray(value).squeeze()
    if np.iscomplexobj(array):
        return complex(array)
    if isinstance(value, (tuple, list)) and len(value) == 2:
        return complex(float(value[0]), float(value[1]))
    return complex(float(array), 0.0)


def pair_scan(
    femm: Any,
    tx: int,
    rx: int,
    n_elec: int,
    v_tx: float,
    show_solver: bool = False,
) -> dict[str, float]:
    """Solve one voltage-drive/current-sense pair with other terminals floating."""
    for electrode in range(1, n_elec + 1):
        name = f"E{electrode:02d}"
        if electrode == tx or electrode == rx:
            voltage = v_tx if electrode == tx else 0.0
            femm.ci_modifyconductorprop(name, 1, voltage)
            femm.ci_modifyconductorprop(name, 3, 1)  # prescribed voltage
        else:
            femm.ci_modifyconductorprop(name, 2, 0.0)
            femm.ci_modifyconductorprop(name, 3, 0)  # zero total current

    femm.ci_analyze(0 if show_solver else 1)
    femm.ci_loadsolution()
    terminal = {}
    for electrode in range(1, n_elec + 1):
        values = femm.co_getconductorproperties(f"E{electrode:02d}")
        terminal[electrode] = (as_complex(values[0]), as_complex(values[1]))

    currents = [terminal[e][1] for e in range(1, n_elec + 1)]
    tx_v, tx_i = terminal[tx]
    rx_v, rx_i = terminal[rx]
    scale = max(abs(tx_i), np.finfo(float).tiny)
    floating = max(
        (abs(currents[e - 1]) for e in range(1, n_elec + 1) if e not in (tx, rx)),
        default=0.0,
    )
    return {
        "U_tx_re_V": tx_v.real,
        "U_tx_im_V": tx_v.imag,
        "U_rx_re_V": rx_v.real,
        "U_rx_im_V": rx_v.imag,
        "I_tx_re_A": tx_i.real,
        "I_tx_im_A": tx_i.imag,
        "I_rx_re_A": rx_i.real,
        "I_rx_im_A": rx_i.imag,
        "Y_re_S_per_m_depth": (tx_i / v_tx).real,
        "Y_im_S_per_m_depth": (tx_i / v_tx).imag,
        "dcc": abs(sum(currents)) / scale,
        "floating_over_It": floating / scale,
        "dev_U_V": max(abs(tx_v - v_tx), abs(rx_v)),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="solve all 120 unique pairs")
    parser.add_argument("--tx", type=int, default=1, help="transmitter for a single-pair check")
    parser.add_argument("--rx", type=int, default=9, help="receiver for a single-pair check")
    parser.add_argument(
        "--show-solver", action="store_true",
        help="show FEMM's solver console for diagnosing a single-pair run",
    )
    args = parser.parse_args()

    nodes_m, edges, boundary_ids, p = read_reference()
    n_elec = int(round(p["nElec"]))
    if args.all:
        pairs = [(tx, rx) for tx in range(1, n_elec + 1) for rx in range(tx + 1, n_elec + 1)]
    else:
        if not (1 <= args.tx <= n_elec and 1 <= args.rx <= n_elec and args.tx != args.rx):
            raise ValueError("Choose distinct --tx and --rx electrode numbers in range")
        pairs = [(args.tx, args.rx)]

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    # FEMM uses .FEC for Current Flow inputs; .FEM is reserved for magnetics.
    model_file = OUTPUT_DIR / "B6_FEMM_current_flow.fec"
    csv_file = OUTPUT_DIR / ("B6_FEMM_120_pairs.csv" if args.all else "B6_FEMM_pair_check.csv")

    try:
        import femm
    except ImportError as exc:
        raise RuntimeError(
            "pyFEMM is not installed in this Python environment. Install FEMM 4.2 "
            "and its pyFEMM package, then retry."
        ) from exc

    create_femm_model(femm, nodes_m, edges, boundary_ids, p, model_file)
    columns = ["pair_index", "tx", "rx", "pair_separation"]
    metric_columns = [
        "U_tx_re_V", "U_tx_im_V", "U_rx_re_V", "U_rx_im_V",
        "I_tx_re_A", "I_tx_im_A", "I_rx_re_A", "I_rx_im_A",
        "Y_re_S_per_m_depth", "Y_im_S_per_m_depth", "dcc",
        "floating_over_It", "dev_U_V",
    ]
    with csv_file.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=columns + metric_columns)
        writer.writeheader()
        for pair_index, (tx, rx) in enumerate(pairs, start=1):
            result = pair_scan(
                femm, tx, rx, n_elec, p["Vtx"], show_solver=args.show_solver
            )
            writer.writerow({
                "pair_index": pair_index,
                "tx": tx,
                "rx": rx,
                "pair_separation": min(rx - tx, n_elec - (rx - tx)),
                **result,
            })
            stream.flush()
            print(
                f"{pair_index:3d}/{len(pairs)} tx={tx:02d} rx={rx:02d} "
                f"|It|={math.hypot(result['I_tx_re_A'], result['I_tx_im_A']):.6g} A "
                f"dcc={result['dcc']:.3g} float/It={result['floating_over_It']:.3g}"
            )
            femm.co_close()

    print(f"FEMM model: {model_file}")
    print(f"Pair data:  {csv_file}")
    print(
        "Note: FEMM uses an independently generated Triangle mesh and ideal "
        "electrode contacts; compare after mesh refinement and account for B6 z_el."
    )


if __name__ == "__main__":
    main()
