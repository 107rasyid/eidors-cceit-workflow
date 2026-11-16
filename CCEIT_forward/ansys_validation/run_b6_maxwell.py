# Maxwell 2D AC Conduction script for AEDT GUI: Tools > Run Script.
# Run only with a blank project active in the AEDT GUI.
import math
import os
import ScriptEnv


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
    n = len(points)
    for k in range(n):
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
                      "conductivity:=", str(sigma), "dielectric_loss_tangent:=", "0",
                      "permeability:=", "1"])


def main():
    root = os.path.dirname(os.path.abspath(__file__))
    outdir = os.path.join(root, "results")
    if not os.path.isdir(outdir):
        os.makedirs(outdir)
    project_path = os.path.join(outdir, "B6_Maxwell_ACConduction.aedt")
    matrix_path = os.path.join(outdir, "B6_Maxwell_Ymatrix.tab")

    ScriptEnv.Initialize("Ansoft.ElectronicsDesktop")
    # Use the blank project already active in the AEDT GUI.
    oProject = oDesktop.GetActiveProject()
    if oProject is None:
        raise Exception("No active project. Create/open a blank project in AEDT, then run this script.")
    oProject.InsertDesign("Maxwell 2D", "B6_ACConduction", "AC Conduction", "")
    oDesign = oProject.SetActiveDesign("B6_ACConduction")
    oDesign.SetSolutionType("AC Conduction", "XY")
    oEditor = oDesign.SetActiveEditor("3D Modeler")
    oDesign.SetDesignSettings(
        ["NAME:Design Settings Data", "ModelDepth:=", "1meter",
         "SymmetryMultiplier:=", 1, "BackgroundMaterialName:=", "vacuum"],
        ["NAME:Model Validation Settings", "EntityCheckLevel:=", "Basic",
         "IgnoreUnclassifiedObjects:=", True, "SkipIntersectionChecks:=", False])
    oDefs = oProject.GetDefinitionManager()
    add_material(oDefs, "CCEIT_Medium", 0.025, 80)
    add_material(oDefs, "CCEIT_Layer", 1e-12, 3)
    add_material(oDefs, "CCEIT_Contact", 0.01, 1)

    n_elec = 16
    pitch = 2.0 * math.pi / n_elec
    phi0 = -0.5 * math.pi
    width_ang = 18.0 / 55.0
    # AEDT Student permits at most 2,000 triangles for a 2D Maxwell solve.
    # Use very coarse polygonal arcs and one adaptive pass for a feasibility
    # solve under that cap; this is not a quantitatively comparable B6 mesh.
    electrode_segments = 4
    gap_segments = 1
    radius_medium = 53.0
    radius_inner_contact = 54.9
    radius_outer = 55.0
    radius_pad = 55.2
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
        for k in range(electrode_segments):
            angles.append(a0 + (a1 - a0) * float(k) / float(electrode_segments))
        gap_end = next_a0
        for k in range(gap_segments):
            angles.append(a1 + (gap_end - a1) * float(k) / float(gap_segments))
    angles.append(angles[0] + 2.0 * math.pi)
    create_polygon(oEditor, "Medium", disk_points(radius_medium, angles[:-1]),
                   "CCEIT_Medium", "(80 170 220)")

    # The inner dielectric annulus is split into matching sectors so Maxwell
    # receives explicit, shared interfaces with the contact and gap sectors.
    for e in range(n_elec):
        a0, a1 = bounds[e]
        next_a0 = bounds[(e + 1) % n_elec][0]
        if e == n_elec - 1:
            next_a0 += 2.0 * math.pi
        create_polygon(oEditor, "LayerInner_E%02d" % (e + 1),
                       annular_points(radius_medium, radius_inner_contact,
                                      a0, a1, electrode_segments),
                       "CCEIT_Layer", "(80 170 220)")
        create_polygon(oEditor, "LayerInner_G%02d" % (e + 1),
                       annular_points(radius_medium, radius_inner_contact,
                                      a1, next_a0, gap_segments),
                       "CCEIT_Layer", "(80 170 220)")
        create_polygon(oEditor, "Contact_E%02d" % (e + 1),
                       annular_points(radius_inner_contact, radius_outer,
                                      a0, a1, electrode_segments),
                       "CCEIT_Contact", "(240 180 60)")
        create_polygon(oEditor, "LayerOuter_G%02d" % (e + 1),
                       annular_points(radius_inner_contact, radius_outer,
                                      a1, next_a0, gap_segments),
                       "CCEIT_Layer", "(80 170 220)")
        create_polygon(oEditor, "Electrode_%02d" % (e + 1),
                       annular_points(radius_outer, radius_pad,
                                      a0, a1, electrode_segments),
                       "copper", "(180 180 180)")

    # 15 AC voltage sources are signals; electrode 16 is the matrix reference.
    # The exported Y matrix is intended for floating-port reduction in a later
    # post-processing step; this file does not claim a completed 120-pair scan.
    bsetup = oDesign.GetModule("BoundarySetup")
    sources = []
    for e in range(n_elec):
        src = "V_E%02d" % (e + 1)
        bsetup.AssignVoltage(["NAME:" + src, "Voltage:=", "0V", "Phase:=", "0deg",
                              "Objects:=", ["Electrode_%02d" % (e + 1)]])
        sources.append(src)

    matrix_mod = oDesign.GetModule("MaxwellParameterSetup")
    # AC Conduction expects MatrixEntry and GroundSources directly under the
    # matrix name. A GCMatrix wrapper is only used by other Maxwell solvers;
    # with it here, the ground excitation is ignored and matrix validation fails.
    entries = ["NAME:MatrixEntry"]
    for src in sources[:-1]:
        entries.append(["NAME:MatrixEntry", "Source:=", src, "NumberOfTurns:=", "1"])
    matrix_mod.AssignMatrix(["NAME:B6_YMatrix", entries,
                             "GroundSources:=", sources[-1] + ","])

    setup = oDesign.GetModule("AnalysisSetup")
    setup.InsertSetup("AC Conduction", ["NAME:Setup1", "Enabled:=", True,
                      "MaximumPasses:=", 1, "MinimumPasses:=", 1,
                      "MinimumConvergedPasses:=", 1, "PercentRefinement:=", 30,
                      "SolveFieldOnly:=", False, "PercentError:=", 1,
                      "SolveMatrixAtLast:=", True, "UseOutputVariable:=", False,
                      "PreAdaptMesh:=", False, "Frequency:=", "500kHz",
                      "HasSweepSetup:=", False])
    oDesign.Analyze("Setup1")
    sol = oDesign.GetModule("Solutions")
    sol.ExportNetworkData("", ["Setup1:LastAdaptive"], 2, matrix_path,
                          ["all"], False, 0, "Y", -1, 1, 15, False, False, False)
    oProject.SaveAs(project_path, True)
    print("Saved Maxwell project: " + project_path)
    print("Saved terminal admittance matrix: " + matrix_path)
    print("The launcher converts this grounded matrix to 120 floating-pair rows.")


main()
