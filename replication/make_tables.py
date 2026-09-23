"""make_tables.py -- write the LaTeX tables of the technical note from the CSV
files that the replication scripts leave in out/.

    python make_tables.py [out_dir] [tex_dir]

Defaults: out/ and ../paper/fig/.  Each table is a tabular body meant to be
\\input inside a table environment of the note.
"""
import csv, os, sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
TEX = sys.argv[2] if len(sys.argv) > 2 else os.path.join("..", "paper", "fig")
os.makedirs(TEX, exist_ok=True)

GOODS = {"corn": "Corn", "wheat": "Wheat", "rice": "Rice", "other": "Other cereals",
         "composite": "All other goods"}


def read(name):
    with open(os.path.join(OUT, name + ".csv"), newline="") as f:
        rows = list(csv.reader(f))
    head = rows[0][1:]
    body = [(r[0], [float(x) if x not in ("", ".") else float("nan") for x in r[1:]]) for r in rows[1:]]
    return head, body


def fmt(x, d=3):
    if x != x:
        return "--"
    return f"{x:.{d}f}"


def tex(name, text):
    with open(os.path.join(TEX, name + ".tex"), "w", encoding="utf-8") as f:
        f.write(text)


def esc(s):
    return s.replace("_", "\\_").replace("%", "\\%").replace("&", "\\&")


# ---- Table 1: the data -----------------------------------------------------
head, body = read("table1_data")
lines = ["\\begin{tabular}{lrrrrrr}", "\\toprule",
         "Good & Share (\\%) & Reporters & \\% & Clusters & $\\bar n^{+}$ & $\\bar n$ \\\\", "\\midrule"]
for r, v in body:
    lines.append(f"{GOODS.get(r, r)} & {fmt(v[0],2)} & {int(v[1]):,} & {fmt(v[2],1)} & {int(v[3]):,} & {fmt(v[4],2)} & {fmt(v[5],2)} \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_data", "\n".join(lines) + "\n")

# ---- Table 2: quality -------------------------------------------------------
head, body = read("table2_quality")
lines = ["\\begin{tabular}{lrrrrrrr}", "\\toprule",
         "Good & $\\hat\\beta^0$ & $\\hat\\beta^1$ & (s.e.) & $\\hat e$ & (s.e.) & $\\hat\\zeta$ & $\\hat\\zeta\\bar w=\\hat\\beta^1/\\hat e$ & $\\hat\\psi_{GG}$ \\\\", "\\midrule"]
lines[0] = "\\begin{tabular}{lrrrrrrrr}"
for r, v in body:
    b0, se_e, b1, se_b1, e, z, zw, psi = v
    lines.append(f"{GOODS.get(r, r)} & {fmt(b0,4)} & {fmt(b1,4)} & ({fmt(se_b1,4)}) & {fmt(e,3)} & ({fmt(se_e,3)}) & {fmt(z,3)} & {fmt(zw,3)} & {fmt(psi,3)} \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_quality", "\n".join(lines) + "\n")

# ---- Table 3: elasticities with SE ------------------------------------------
head, E = read("table3_elast")
_, SE = read("table3_se")
cols = [GOODS.get(c, c) for c in head]
cols[-1] = "All other"
lines = ["\\begin{tabular}{l" + "r" * len(head) + "}", "\\toprule",
         "Quantity of & " + " & ".join(f"$p_{{\\text{{{c.lower()}}}}}$" for c in cols) + " \\\\", "\\midrule"]
for (r, v), (_, s) in zip(E, SE):
    name = GOODS.get(r, r) if r != "other" or E.index((r, v)) < 4 else "All other goods"
    if E.index((r, v)) == len(E) - 1:
        name = "All other goods"
    lines.append(f"{name} & " + " & ".join(fmt(x) for x in v) + " \\\\")
    lines.append(" & " + " & ".join(f"({fmt(x)})" for x in s) + " \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_elast", "\n".join(lines) + "\n")

# ---- Table 4: treatments ----------------------------------------------------
head, body = read("table4_treatments")
lines = ["\\begin{tabular}{lrrrr}", "\\toprule",
         "Good & No quality correction & Quality, unrestricted & Quality, symmetric & Completed system \\\\", "\\midrule"]
for r, v in body:
    lines.append(f"{GOODS.get(r, r)} & " + " & ".join(fmt(x) for x in v) + " \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_treatments", "\n".join(lines) + "\n")

# ---- Table 5: variance validation -------------------------------------------
head, body = read("table5_ownprice_se")
_, ratios = read("table5_ratios")
lab = {"srs": "Simple random sampling of clusters", "aw": "Sampling weights (aweight)",
       "svy": "Survey design (svyset, strata, pweight)"}
lines = ["\\begin{tabular}{llrrrrrrrr}", "\\toprule",
         "Design & Standard error & Corn & Wheat & Rice & Other & All other & \\multicolumn{3}{c}{Ratio over all parameters} \\\\",
         " & & & & & & & min & median & max \\\\", "\\midrule"]
rd = {r: v for r, v in ratios}
for i in range(0, len(body), 2):
    ra, va = body[i]
    rb, vb = body[i + 1]
    case = ra.split("_")[0]
    mn, md, mx, _ = rd[case]
    lines.append(f"{lab[case]} & Linearized & " + " & ".join(fmt(x, 4) for x in va) + f" & {fmt(mn)} & {fmt(md)} & {fmt(mx)} \\\\")
    lines.append(" & Bootstrap & " + " & ".join(fmt(x, 4) for x in vb) + " & & & \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_validation", "\n".join(lines) + "\n")

# ---- Table 6: shortcut ------------------------------------------------------
head, body = read("table6_shortcut")
lines = ["\\begin{tabular}{lrrrrrrrrr}", "\\toprule",
         " & \\multicolumn{5}{c}{Own-price elasticity} & \\multicolumn{4}{c}{Expenditure elasticity} \\\\",
         "Bootstrap & Corn & Wheat & Rice & Other & All other & Corn & Wheat & Rice & Other \\\\", "\\midrule"]
lab = {"both_stages": "Both stages", "shortcut": "Second stage only (shortcut)", "ratio": "Ratio"}
for r, v in body:
    d = 3 if r == "ratio" else 4
    lines.append(f"{lab[r]} & " + " & ".join(fmt(x, d) for x in v) + " \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_shortcut", "\n".join(lines) + "\n")

# ---- Table 7: deciles -------------------------------------------------------
head, body = read("table7_deciles")
lines = ["\\begin{tabular}{lrrrrrrrr}", "\\toprule",
         "Group & Corn & (s.e.) & Wheat & (s.e.) & Rice & (s.e.) & Other & (s.e.) \\\\", "\\midrule"]
for r, v in body:
    cells = []
    for k in range(0, len(v), 2):
        cells.append(fmt(v[k]))
        cells.append(f"({fmt(v[k+1])})")
    lines.append(f"{esc(r)} & " + " & ".join(cells) + " \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_deciles", "\n".join(lines) + "\n")

# ---- Table 8: timing --------------------------------------------------------
head, body = read("table8_timing")
lines = ["\\begin{tabular}{lrrrr}", "\\toprule",
         "Version & Estimation & Ten deciles & Bootstrap replication, both stages & Replication, shortcut \\\\", "\\midrule"]
lab = {"WELCOM_2017": "WELCOM \\cmd{duvm} (2017)", "duvm_1_0": "\\cmd{duvm} 1.0"}
for r, v in body:
    lines.append(f"{lab[r]} & " + " & ".join(fmt(x, 2) for x in v) + " \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_timing", "\n".join(lines) + "\n")

# ---- Table A1: corrections one at a time ------------------------------------
head, body = read("tableA1_corrections")
labA1 = {"welcom": "WELCOM formulas (all)", "zeta": "+ $\\zeta$ of eq. (5.92)",
         "completion": "+ completion with $\\zeta^x$, not $1/\\zeta^x$",
         "sign": "+ last row of $\\Theta^x$ = $-$colsum", "counts": "+ effective cluster sizes",
         "chi": "+ $\\chi$ from eq. (5.82)", "mean": "+ cluster means over the observed households",
         "region": "+ region = first non-missing household (the book)"}
lines = ["\\begin{tabular}{lrrrrr}", "\\toprule",
         "Formulas & Corn & Wheat & Rice & Other & All other \\\\", "\\midrule"]
for r, v in body:
    lines.append(f"{labA1.get(r, esc(r))} & " + " & ".join(fmt(x, 4) for x in v) + " \\\\")
lines += ["\\bottomrule", "\\end{tabular}"]
tex("tab_corrections", "\n".join(lines) + "\n")

# ---- Table A2: compat lock --------------------------------------------------
if os.path.exists(os.path.join(OUT, "tableA2_compat_lock.csv")):
    head, body = read("tableA2_compat_lock")
    lab = {"w_region": "weights, region", "unw_region": "unweighted, region", "w_noregion": "weights, no region",
           "w_region_csb": "weights, region, \\opt{csb(1)}", "w_region_con": "weights, region, continuous controls"}
    lines = ["\\begin{tabular}{lrr}", "\\toprule",
             "Case & Moments and coefficients & Elasticities \\\\", "\\midrule"]
    for r, v in body:
        lines.append(f"{lab.get(r, esc(r))} & {v[0]:.1e} & {v[1]:.1e} \\\\")
    lines += ["\\bottomrule", "\\end{tabular}"]
    tex("tab_lock", "\n".join(lines) + "\n")

print("tables written to", TEX)
