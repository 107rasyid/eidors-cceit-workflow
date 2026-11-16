# Maxwell 2D AC Conduction script for AEDT GUI: Tools > Run Script.
# Run only with a blank project active in the AEDT GUI.
#
# Geometry (mm): Medium 0-53 | insulating layer 53-54 | contact 54-55.
# No copper pad: voltage is assigned to the outer edges (r = 55 mm) of Contact sectors.
# Output: project + CSV exports (G, C, Re(Y), Im(Y), scaled) in results\
import math
import os
import ScriptEnv

# ---- switches ---------------------------------------------------------------
SIGMA_MEDIUM = 0.025     # S/m. Set to 1.0 for the "is sigma used?" test (Re(Y) must jump).
N_ELEC = 16
ELECTRODE_SEGMENTS = 4   # Student cap: keep small. Fine version: 8 or more.
GAP_SEGMENTS = 1
USE_MESH_LIMITS = True   # Set False on a full license (fine mesh).
FREQ = "500kHz"


def log(t):
    oDesktop.AddMessage("", "", 0, str(t))


def annular_points(r_inner_mm, r_outer_mm, a0, a1, n):
    pts = []
    for k in range(n + 1):
        a = a0 + (a1 - a0) * float(k) / float(n)
        pts.append((r_outer_mm * math.cos(a), r_outer_mm * math.sin(a)))
    for k in range(n, -1, -1):
        a = a0 + (a1 - a0) * float(k) / float(n)
        pts.append((r_inner_mm * math.cos(a), r_inner_mm * math.sin(a)))
    return pts


def disk_points(radius_mm, angles):
    return [(radius_mm * math.cos(a), radius_mm * math.sin(a)) for a in angles]


def create_polygon(editor, name, points, material, color):
    ppoints = ["NAME:PolylinePoints"]
    for x, y in points:
        ppoints.append(["NAME:PLPoint", "X:=", "%.12gmm" % x,
                        "Y:=", "%.12gmm" % y, "Z:=", "0mm"])
    segs = ["NAME:PolylineSegments"]
    for k in range(len(points)):
        segs.append(["NAME:PLSegment", "SegmentType:=", "Line",
                     "StartIndex:=", k, "NoOfPoints:=", 2])
    params = ["NAME:PolylineParameters", "IsPolylineCovered:=", True,
              "IsPolylineClosed:=", True, ppoints, segs,
              ["NAME:PolylineXSection", "XSectionType:=", "None",
               "XSectionOrient:=", "Auto", "XSectionWidth:=", "0mm",
               "XSectionTopWidth:=", "0mm", "XSectionHeight:=", "0mm",
               "XSectionNumSegments:=", "0", "XSectionBendType:=", "Corner"]]
    attrs = ["NAME:Attributes", "Name:=", name, "Flags:=", "",
             "Color:=", color, "Transparency:=", 0,
             "PartCoordinateSystem:=", "Global", "UDMId:=", "",
             "MaterialValue:=", '"%s"' % material,
             "SurfaceMaterialValue:=", '""', "SolveInside:=", True,
             "IsMaterialEditable:=", True, "UseMaterialAppearance:=", False]
    editor.CreatePolyline(params, attrs)


def add_material(defs, name, sigma, epsr):
    defs.AddMaterial(["NAME:" + name, "permittivity:=", str(epsr),
                      # Maxwell's material editor uses S/m. Include the unit so
                      # the value is not dependent on AEDT's active unit context.
                      "conductivity:=", "%.12gS_per_m" % sigma,
                      "dielectric_loss_tangent:=", "0",
                      "permeability:=", "1"])


def export_report(oReport, tag, template, names, soln, matrix, outdir):
    """Try several report types / name prefixes until one works. template uses {p},{a},{b}."""
    csv_path = os.path.join(outdir, "B6_Maxwell_%s.csv" % tag)
    rname = "R_" + tag
    for rtype in ["Matrix", "AC Conduction"]:
        for prefix in [matrix + ".", "", "Matrix1."]:
            try:
                exprs = [template.format(p=prefix, a=a, b=b) for a in names for b in names]
                oReport.CreateReport(
                    rname, rtype, "Data Table", soln,
                    ["Context:=", matrix],
                    ["Freq:=", ["All"]],
                    ["X Component:=", "Freq", "Y Component:=", exprs])
                if rname not in list(oReport.GetAllReportNames()):
                    log("no report created: %s type=%r prefix=%r" % (tag, rtype, prefix))
                    continue
                oReport.ExportToFile(rname, csv_path, False)
                log("OK %s type=%r prefix=%r -> %s" % (tag, rtype, prefix, csv_path))
                return True
            except Exception as ex:
                log("fail %s type=%r prefix=%r: %s" % (tag, rtype, prefix, ex))
                if rname in list(oReport.GetAllReportNames()):
                    oReport.DeleteReports([rname])
    return False


def main():
    root = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.join(root, "results")
    if not os.path.isdir(outdir):
        os.makedirs(outdir)
    project_path = os.path.join(outdir, "B6_Maxwell_ACConduction.aedt")

    ScriptEnv.Initialize("Ansoft.ElectronicsDesktop")
    oProject = oDesktop.GetActiveProject()
    if oProject is None:
        raise Exception("No active project. Create a blank project in AEDT, then run this script.")
    oProject.InsertDesign("Maxwell 2D", "B6_ACConduction", "AC Conduction", "")
    oDesign = oProject.SetActiveDesign("B6_ACConduction")
    oDesign.SetSolutionType("AC Conduction", "XY")
    # Set thresholds through SetDesignSettings (supported by the 2D AC
    # Conduction design object). SetConductivityThreshold is documented for some
    # AEDT APIs but is absent from the IDispatch object in the user's GUI build.
    # Maxwell's common 1 S/m threshold would classify the 0.025 S/m phantom as
    # an insulator, suppressing its conductive current and forcing Re(Y)=0.
    # Keep the 1e-12 S/m layer insulating while treating medium/contact as
    # conductive.
    conductivity_threshold = 1e-8
    log("conductivity thresholds: perfect=1e12 S/m, insulator/conductor=1e-8 S/m")
    oEditor = oDesign.SetActiveEditor("3D Modeler")
    oDesign.SetDesignSettings(
        ["NAME:Design Settings Data",
         "PerfectConductorThreshold:=", 1e12,
         "InsulatorThreshold:=", conductivity_threshold,
         "ModelDepth:=", "1meter",
         "SymmetryMultiplier:=", 1, "BackgroundMaterialName:=", "vacuum"],
        ["NAME:Model Validation Settings", "EntityCheckLevel:=", "Basic",
         "IgnoreUnclassifiedObjects:=", True, "SkipIntersectionChecks:=", False])

    # ---- Materials (layer/contact scaled to 1 mm, preserving sigma/t and epsr/t) ----
    oDefs = oProject.GetDefinitionManager()
    add_material(oDefs, "CCEIT_Medium", SIGMA_MEDIUM, 80)
    add_material(oDefs, "CCEIT_Layer", 1e-12, 1.58)
    add_material(oDefs, "CCEIT_Contact", 0.1, 10)
    log("materials: medium sigma=%s" % SIGMA_MEDIUM)

    # ---- Geometry ----------------------------------------------------------------
    n_elec = N_ELEC
    seg_e = ELECTRODE_SEGMENTS
    seg_g = GAP_SEGMENTS
    pitch = 2.0 * math.pi / n_elec
    phi0 = -0.5 * math.pi
    width_ang = 18.0 / 55.0
    radius_medium = 53.0
    radius_inner_contact = 54.0
    radius_outer = 55.0

    bounds = []
    for e in range(n_elec):
        center = phi0 + e * pitch
        bounds.append((center - width_ang / 2.0, center + width_ang / 2.0))
    angles = []
    for e in range(n_elec):
        a0, a1 = bounds[e]
        next_a0 = bounds[(e + 1) % n_elec][0]
        if e == n_elec - 1:
            next_a0 += 2.0 * math.pi
        for k in range(seg_e):
            angles.append(a0 + (a1 - a0) * float(k) / float(seg_e))
        for k in range(seg_g):
            angles.append(a1 + (next_a0 - a1) * float(k) / float(seg_g))
    create_polygon(oEditor, "Medium", disk_points(radius_medium, angles),
                   "CCEIT_Medium", "(80 170 220)")

    for e in range(n_elec):
        a0, a1 = bounds[e]
        next_a0 = bounds[(e + 1) % n_elec][0]
        if e == n_elec - 1:
            next_a0 += 2.0 * math.pi
        create_polygon(oEditor, "LayerInner_E%02d" % (e + 1),
                       annular_points(radius_medium, radius_inner_contact, a0, a1, seg_e),
                       "CCEIT_Layer", "(80 170 220)")
        create_polygon(oEditor, "LayerInner_G%02d" % (e + 1),
                       annular_points(radius_medium, radius_inner_contact, a1, next_a0, seg_g),
                       "CCEIT_Layer", "(80 170 220)")
        create_polygon(oEditor, "Contact_E%02d" % (e + 1),
                       annular_points(radius_inner_contact, radius_outer, a0, a1, seg_e),
                       "CCEIT_Contact", "(240 180 60)")
        create_polygon(oEditor, "LayerOuter_G%02d" % (e + 1),
                       annular_points(radius_inner_contact, radius_outer, a1, next_a0, seg_g),
                       "CCEIT_Layer", "(80 170 220)")

    # ---- Excitations: voltage on outer edges of each Contact sector --------------
    bsetup = oDesign.GetModule("BoundarySetup")
    sources = []
    for e in range(n_elec):
        a0, a1 = bounds[e]
        edge_ids = []
        for k in range(seg_e):
            ak = a0 + (a1 - a0) * float(k) / seg_e
            ak1 = a0 + (a1 - a0) * float(k + 1) / seg_e
            xm = 0.5 * radius_outer * (math.cos(ak) + math.cos(ak1))
            ym = 0.5 * radius_outer * (math.sin(ak) + math.sin(ak1))
            eid = oEditor.GetEdgeByPosition(
                ["NAME:EdgeParameters", "BodyName:=", "Contact_E%02d" % (e + 1),
                 "XPosition:=", "%.12gmm" % xm, "YPosition:=", "%.12gmm" % ym,
                 "ZPosition:=", "0mm"])
            edge_ids.append(int(eid))
        src = "V_E%02d" % (e + 1)
        bsetup.AssignVoltage(["NAME:" + src, "Voltage:=", "0V", "Phase:=", "0deg",
                              "Edges:=", edge_ids])
        sources.append(src)

    # ---- Matrix (E16 = reference) -------------------------------------------------
    matrix_mod = oDesign.GetModule("MaxwellParameterSetup")
    entries = ["NAME:MatrixEntry"]
    for src in sources[:-1]:
        entries.append(["NAME:MatrixEntry", "Source:=", src, "NumberOfTurns:=", "1"])
    matrix_mod.AssignMatrix(["NAME:B6_YMatrix", entries,
                             "GroundSources:=", sources[-1] + ","])

    # ---- Setup + mesh limits -----------------------------------------------------
    setup = oDesign.GetModule("AnalysisSetup")
    setup.InsertSetup("AC Conduction", ["NAME:Setup1", "Enabled:=", True,
                      "MaximumPasses:=", 1, "MinimumPasses:=", 1,
                      "MinimumConvergedPasses:=", 1, "PercentRefinement:=", 30,
                      "SolveFieldOnly:=", False, "PercentError:=", 1,
                      "SolveMatrixAtLast:=", True, "UseOutputVariable:=", False,
                      "PreAdaptMesh:=", False, "Frequency:=", FREQ,
                      "HasSweepSetup:=", False])
    if USE_MESH_LIMITS:
        mesh = oDesign.GetModule("MeshSetup")
        mesh.AssignLengthOp(["NAME:L_Medium", "RefineInside:=", True, "Enabled:=", True,
                             "Objects:=", ["Medium"], "RestrictElem:=", True,
                             "NumMaxElem:=", "500", "RestrictLength:=", False])
        thin = ["Contact_E%02d" % (e + 1) for e in range(n_elec)]
        mesh.AssignLengthOp(["NAME:L_Thin", "RefineInside:=", True, "Enabled:=", True,
                             "Objects:=", thin, "RestrictElem:=", True,
                             "NumMaxElem:=", "200", "RestrictLength:=", False])

    oDesign.Analyze("Setup1")
    oProject.SaveAs(project_path, True)
    log("Solve done, project saved: " + project_path)

    # ---- Export (scaled so small values do not round to 0) -----------------------
    # G in uS, C in pF, Re/Im(Y) in uS (all per meter of depth).
    oReport = oDesign.GetModule("ReportSetup")
    names = sources[:-1]
    soln = "Setup1 : LastAdaptive"
    matrix = "B6_YMatrix"
    log("reports before: %s" % list(oReport.GetAllReportNames()))
    ok = {}
    ok["G_uS"] = export_report(oReport, "G_uS", "1e6*{p}G({a},{b})", names, soln, matrix, outdir)
    ok["C_pF"] = export_report(oReport, "C_pF", "1e12*{p}C({a},{b})", names, soln, matrix, outdir)
    ok["Yre_uS"] = export_report(oReport, "Yre_uS", "1e6*re({p}Y({a},{b}))", names, soln, matrix, outdir)
    ok["Yim_uS"] = export_report(oReport, "Yim_uS", "1e6*im({p}Y({a},{b}))", names, soln, matrix, outdir)
    log("export status: %s" % ok)
    if SIGMA_MEDIUM > 0 and ok["G_uS"] and ok["Yre_uS"]:
        # A nonzero medium conductivity must produce nonzero dissipative
        # conductance. Fail loudly instead of leaving a misleading all-zero CSV.
        g_path = os.path.join(outdir, "B6_Maxwell_G_uS.csv")
        yre_path = os.path.join(outdir, "B6_Maxwell_Yre_uS.csv")
        for path in (g_path, yre_path):
            with open(path, "r") as stream:
                rows = stream.readlines()
            numeric = []
            for row in rows[1:]:
                fields = row.strip().split(",")
                for field in fields[1:]:
                    try:
                        numeric.append(float(field.strip().strip('"')))
                    except Exception:
                        pass
            if numeric and max(abs(value) for value in numeric) == 0:
                raise Exception(
                    "%s is identically zero although SIGMA_MEDIUM=%g S/m. "
                    "Do not use this run; inspect the Maxwell material/AC Conduction setup."
                    % (os.path.basename(path), SIGMA_MEDIUM)
                )
    if not any(ok.values()):
        log("All exports failed. Create one matrix report in the GUI, then Tools > Record Script.")


main()
