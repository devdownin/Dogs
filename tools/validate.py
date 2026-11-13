"""Valide les fichiers de mission et rejoue les solutions de référence.

Usage : python3 -I tools/validate.py data
Code de sortie 0 si tout passe, 1 sinon.
"""
import csv
import json
import sys
from pathlib import Path

import jsonschema

sys.path.insert(0, str(Path(__file__).resolve().parent))
from sim import (
    ALERTS,
    COST,
    Mission,
    RuleError,
    expand,
    manhattan,
    parse_cell,
    replay,
)

ACTION_PARAMS = {
    "show_tip": ["key"], "dialogue": ["lines"], "set_flag": ["name"], "highlight": ["feature"],
    "camera_focus": ["cell"], "start_countdown": ["id", "turns"], "territory_advance": ["territory", "direction"],
    "close_extraction": [], "set_alert": ["level"], "guardian_order": ["guardian"], "cinematic": ["key"],
    "end_mission": ["result"]}
COND_PARAMS = {
    "turn_start": ["turn"], "turn_end": ["turn"], "max_turns": ["value"], "unit_in": ["unit", "cells"],
    "all_units_extracted": [], "unit_extracted": ["unit"], "unit_disabled": ["unit"], "no_unit_disabled": [],
    "interacted": ["feature"], "feature_revealed": ["feature"], "cells_revealed": ["cells"],
    "reveal_ratio_at_least": ["value"], "terrain_entered": ["terrain"], "territory_revealed": ["territory"],
    "territory_entered": ["territory"], "never_end_turn_on": ["territory"], "unit_end_turn_on": ["territory"],
    "guardian_observed": [], "alert_at_least": ["level"], "alert_never_above": ["level"],
    "countdown_expired": ["countdown"], "flag": ["name"]}


def walk_conditions(c):
    yield c
    for k in ("all", "any", "sequence"):
        for x in c.get(k, []):
            yield from walk_conditions(x)
    if "not" in c:
        yield from walk_conditions(c["not"])


def static_checks(d, keys):
    errs = []
    m = Mission(d)
    rows = d["map"]["rows"]
    if len(rows) != m.h:
        return [f"grille : {len(rows)} lignes, {m.h} attendues"]
    bad = [i + 1 for i, r in enumerate(rows) if len(r.split(" ")) != m.w]
    if bad:
        return [f"grille : ligne(s) {', '.join(map(str, bad))} sans {m.w} cases"]

    def cells_ok(cells, where, passable=False):
        for p in expand(cells):
            if not m.inside(p):
                errs.append(f"{where} : case hors carte")
            elif passable and COST[m.terrain(p)] is None:
                errs.append(f"{where} : case infranchissable")

    unit_ids = [u["id"] for u in d["deployment"]["units"]]
    guard_ids = [g["id"] for g in d["guardians"]]
    feat_ids = list(m.features)
    ids = unit_ids + guard_ids + feat_ids
    if len(ids) != len(set(ids)):
        errs.append("identifiants en double entre unités, Gardiens et points d'intérêt")

    starts = []
    for u in d["deployment"]["units"]:
        cells_ok([u["cell"]], f"unité {u['id']}", True)
        starts.append(u["cell"])
    for g in d["guardians"]:
        cells_ok([g["cell"]] + g.get("route", []), f"Gardien {g['id']}", True)
        starts.append(g["cell"])
        if g["type"] == "sentinel" and not (g.get("facing") or g.get("facing_cycle")):
            errs.append(f"Sentinelle {g['id']} sans orientation")
        if g["type"] == "patroller" and not g.get("route"):
            errs.append(f"Patrouilleur {g['id']} sans ronde")
    if len(starts) != len(set(starts)):
        errs.append("deux unités sur la même case de départ")
    cells_ok(d["deployment"]["extraction"], "extraction", True)
    for f in m.features.values():
        cells_ok([f["cell"]], f"point {f['id']}")
    cells_ok(d["map"].get("elevated"), "elevated")
    for k, v in d["map"].get("territory", {}).items():
        cells_ok(v, f"territoire {k}")

    countdowns = {a["id"] for t in d["triggers"] for a in t["do"] if a["type"] == "start_countdown"}
    flags = {a["name"] for t in d["triggers"] for a in t["do"] if a["type"] == "set_flag"}
    record_ids = {r["id"] for r in d["objectives"]["records"]}

    conds = [("objectif principal", d["objectives"]["main"]["condition"])]
    conds += [(f"relevé {r['id']}", r["condition"]) for r in d["objectives"]["records"]]
    if "failure" in d["objectives"]:
        conds.append(("échec", d["objectives"]["failure"]))
    conds += [(f"déclencheur {t['id']}", t["when"]) for t in d["triggers"]]
    for where, root in conds:
        for c in walk_conditions(root):
            t = c.get("type")
            if not t:
                continue
            for p in COND_PARAMS[t]:
                if p not in c:
                    errs.append(f"{where} : {t} sans paramètre {p}")
            if "feature" in c and c["feature"] not in feat_ids:
                errs.append(f"{where} : point d'intérêt inconnu {c['feature']}")
            if "unit" in c and c["unit"] not in unit_ids + ["any", "scout", "technician", "protector", "interceptor"]:
                errs.append(f"{where} : unité inconnue {c['unit']}")
            if "countdown" in c and c["countdown"] not in countdowns:
                errs.append(f"{where} : compte à rebours jamais lancé {c['countdown']}")
            if t == "flag" and c["name"] not in flags:
                errs.append(f"{where} : drapeau jamais posé {c['name']}")
            if "cells" in c:
                cells_ok(c["cells"], where)
            if "level" in c and c["level"] not in ALERTS:
                errs.append(f"{where} : cran inconnu {c['level']}")
            if t == "terrain_entered" and c["terrain"] not in COST:
                errs.append(f"{where} : terrain inconnu {c['terrain']}")
    for t in d["triggers"]:
        for a in t["do"]:
            for p in ACTION_PARAMS[a["type"]]:
                if p not in a:
                    errs.append(f"déclencheur {t['id']} : {a['type']} sans paramètre {p}")
            if a.get("feature") and a["feature"] not in feat_ids:
                errs.append(f"déclencheur {t['id']} : point d'intérêt inconnu {a['feature']}")
            if a.get("guardian") and a["guardian"] not in guard_ids:
                errs.append(f"déclencheur {t['id']} : Gardien inconnu {a['guardian']}")
    for e in d["campaign_effects"]:
        if e.get("if_record") and e["if_record"] not in record_ids:
            errs.append(f"effet de campagne : relevé inconnu {e['if_record']}")

    used = {d["title_key"], d["objectives"]["main"]["text_key"]}
    used |= {r["text_key"] for r in d["objectives"]["records"]}
    used |= {f["label_key"] for f in m.features.values() if "label_key" in f}
    for t in d["triggers"]:
        for a in t["do"]:
            used |= {a[k] for k in ("key", "label_key") if k in a}
            used |= {ln["key"] for ln in a.get("lines", [])}
    for k in sorted(used - keys):
        errs.append(f"clé de traduction absente : {k}")

    # Accessibilité : chaque point à activer doit avoir une case adjacente atteignable par l'unité requise.
    for f in m.features.values():
        if f["kind"] in ("boundary_marker", "point_of_interest", "fragment_cache"):
            continue
        need_tech = f["kind"] in ("signal_source", "relay_point", "beacon", "node")
        cands = [u for u in d["deployment"]["units"] if u["type"] == "technician" or not need_tech]
        ok = False
        for u in cands:
            dist, _ = m.paths(parse_cell(u["cell"]))
            if any(manhattan(p, f["pos"]) == 1 for p in dist):
                ok = True
        if not ok:
            errs.append(f"point {f['id']} : aucune case adjacente accessible pour l'unité requise")
    return errs


BRANCHES = {"observation", "link", "engineering", "xenology", "crew"}
NATURES = {"knowledge_base", "sample", "observation", "chronicle"}
STAGES = {"survival", "observation", "link", "research", "projection", "navigation"}


def research_checks(root):
    """Arbre de découverte : références, exclusivités, absence de cycle, traductions."""
    errs = []
    disc = json.loads((root / "research/discoveries.json").read_text(encoding="utf-8"))["discoveries"]
    tree = json.loads((root / "research/tree.json").read_text(encoding="utf-8"))["hypotheses"]
    with open(root / "i18n/research.csv", encoding="utf-8") as fh:
        keys = {r["keys"] for r in csv.DictReader(fh) if r.get("fr") and r.get("en")}
    dids = [d["id"] for d in disc]
    hids = [h["id"] for h in tree]
    for name, ids in (("découverte", dids), ("hypothèse", hids)):
        errs += [f"{name} {i} en double" for i in {i for i in ids if ids.count(i) > 1}]
    for d in disc:
        if d["nature"] not in NATURES:
            errs.append(f"découverte {d['id']} : nature {d['nature']} inconnue")
        if d["title_key"] not in keys:
            errs.append(f"découverte {d['id']} : clé {d['title_key']} non traduite")
    used = set()
    for h in tree:
        req, w = h["requires"], f"hypothèse {h['id']}"
        if h["branch"] not in BRANCHES:
            errs.append(f"{w} : branche {h['branch']} inconnue")
        if h["title_key"] not in keys:
            errs.append(f"{w} : clé {h['title_key']} non traduite")
        if not any(req.get(k) for k in ("discoveries", "ship_stage", "hypotheses", "any_hypothesis")):
            errs.append(f"{w} : rien ne la révèle (ni découverte, ni étape, ni hypothèse parente)")
        if req.get("ship_stage", "survival") not in STAGES:
            errs.append(f"{w} : étape {req['ship_stage']} inconnue")
        for d in req.get("discoveries", []):
            used.add(d)
            if d not in dids:
                errs.append(f"{w} : découverte {d} inconnue")
        for p in req.get("hypotheses", []) + req.get("any_hypothesis", []):
            if p not in hids:
                errs.append(f"{w} : hypothèse parente {p} inconnue")
        ex = h.get("exclusive_with")
        if ex and next((o.get("exclusive_with") for o in tree if o["id"] == ex), None) != h["id"]:
            errs.append(f"{w} : exclusivité avec {ex} non réciproque")
        if h["cycles"] < 1 or h["data_cost"] < 0:
            errs.append(f"{w} : durée ou coût invalide")
    errs += [f"découverte {d} : n'alimente aucune hypothèse" for d in dids if d not in used]
    parents = {h["id"]: h["requires"].get("hypotheses", []) + h["requires"].get("any_hypothesis", []) for h in tree}
    state = {}

    def cyclic(n):
        if state.get(n) == 1:
            return True
        if state.get(n) == 2:
            return False
        state[n] = 1
        bad = any(cyclic(p) for p in parents.get(n, []) if p in parents)
        state[n] = 2
        return bad

    errs += [f"hypothèse {h} : dépendance circulaire" for h in hids if cyclic(h)]
    print(f"{'OK ' if not errs else 'KO '} arbre de découverte ({len(hids)} hypothèses, {len(dids)} découvertes)")
    for e in errs:
        print(f"     - {e}")
    return bool(errs)


def main(root):
    root = Path(root)
    schema = json.loads((root / "schema/mission.schema.json").read_text(encoding="utf-8"))
    with open(root / "i18n/missions.csv", encoding="utf-8") as fh:
        rows = list(csv.DictReader(fh))
    keys = {r["keys"] for r in rows}
    missing_en = [r["keys"] for r in rows if not r.get("en")]
    missions, failed = {}, False
    for f in sorted((root / "missions").glob("*.json")):
        d = json.loads(f.read_text(encoding="utf-8"))
        errs = [f"schéma : {e.message} ({'/'.join(map(str, e.absolute_path))})"
                for e in jsonschema.Draft202012Validator(schema).iter_errors(d)]
        if d.get("id") != f.stem:
            errs.append(f"id {d.get('id')} différent du nom de fichier")
        if not errs:
            errs = static_checks(d, keys)
        print(f"{'OK ' if not errs else 'KO '} {f.name}")
        for e in errs:
            print(f"     - {e}")
        failed |= bool(errs)
        if not errs:
            missions[d.get("id")] = d
    for f in sorted((root / "replays").glob("*.json")):
        rep = json.loads(f.read_text(encoding="utf-8"))
        d = missions.get(rep["mission"])
        if d is None:
            print(f"--  rejeu {f.name} : ignoré (mission {rep['mission']} invalide ou absente)")
            failed = True
            continue
        try:
            g = replay(d, rep)
            exp, problems = rep["expect"], []
            if g.result != exp["result"]:
                problems.append(f"résultat {g.result}, attendu {exp['result']}")
            if "turn" in exp and g.result_turn != exp["turn"]:
                problems.append(f"fin au tour {g.result_turn}, attendu {exp['turn']}")
            if "alert_max" in exp and ALERTS[g.alert_max] != exp["alert_max"]:
                problems.append(f"alerte max {ALERTS[g.alert_max]}, attendue {exp['alert_max']}")
            recs = g.records()
            for k, v in exp.get("records", {}).items():
                if recs.get(k) != v:
                    problems.append(f"relevé {k} = {recs.get(k)}, attendu {v}")
        except RuleError as e:
            problems = [f"commande illégale : {e}"]
            g = None
        status = "OK " if not problems else "KO "
        detail = f"{g.result} au tour {g.result_turn}, alerte max {ALERTS[g.alert_max]}" if g else ""
        print(f"{status} rejeu {f.name} : {detail}")
        for p in problems:
            print(f"     - {p}")
        if g:
            for line in g.log:
                print(f"       · {line}")
        failed |= bool(problems)
    if (root / "research").exists():
        failed |= research_checks(root)
    if missing_en:
        print(f"Note : {len(missing_en)} clés sans traduction anglaise.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
