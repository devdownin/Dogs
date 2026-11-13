"""Mini-simulateur de référence des règles de Dogs of Gods (prototype).

Sert uniquement à valider les données de mission et les rejeux en intégration continue.
Le cœur de règles du jeu reste celui de Godot ; ce module en est une transcription
volontairement réduite (pas de modules, pas de Liaison). Toute divergence doit être
corrigée des deux côtés.
"""
import heapq

UNITS = {  # mouvement, intégrité, vision
    "scout": (5, 2, 4), "technician": (3, 2, 2), "protector": (3, 4, 2), "interceptor": (4, 3, 3)}
GUARD_MOVE = {"sentinel": 0, "patroller": 4, "regulator": 2, "herald": 3}
COST = {".": 1, "R": 2, "X": 2, "M": 1, "r": 1, "G": 1, "C": None, "B": None}
BLOCKS_LOS = {"R", "X"}
ALERTS = ["watch", "warning", "interception", "lockdown"]
DIRS = {"N": (0, -1), "NE": (1, -1), "E": (1, 0), "SE": (1, 1), "S": (0, 1),
        "SW": (-1, 1), "W": (-1, 0), "NW": (-1, -1)}
INTERFACE_KINDS = {"signal_source", "relay_point", "beacon", "node"}
PROBE_RANGE, PROBE_RADIUS = 5, 1
GUARD_HP = {"sentinel": 3, "patroller": 3, "regulator": 5, "herald": 2}
ATTACK = {"protector": (1, 1, 1), "interceptor": (2, 1, 2)}  # dégâts, portée min, portée max
PATROLLER_DAMAGE, SENTINEL_DAMAGE, SENTINEL_RANGE = 2, 1, 3


def parse_cell(c):
    return ord(c[0]) - 65, int(c[1:]) - 1


def cell_name(p):
    return f"{chr(65 + p[0])}{p[1] + 1}"


def expand(cells):
    out = []
    for c in cells or []:
        if ":" in c:
            (x1, y1), (x2, y2) = (parse_cell(s) for s in c.split(":"))
            out += [(x, y) for y in range(min(y1, y2), max(y1, y2) + 1)
                    for x in range(min(x1, x2), max(x1, x2) + 1)]
        else:
            out.append(parse_cell(c))
    return out


def manhattan(a, b):
    return abs(a[0] - b[0]) + abs(a[1] - b[1])


def bresenham(a, b):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err, pts = dx + dy, []
    while True:
        pts.append((x0, y0))
        if (x0, y0) == (x1, y1):
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy; x0 += sx
        if e2 <= dx:
            err += dx; y0 += sy


class RuleError(Exception):
    pass


class Mission:
    def __init__(self, data):
        self.d = data
        m = data["map"]
        self.w, self.h = m["width"], m["height"]
        self.grid = [r.split(" ") for r in m["rows"]]
        self.elevated = {(x, y) for y, row in enumerate(self.grid) for x, t in enumerate(row) if t == "M"}
        self.elevated |= set(expand(m.get("elevated")))
        self.features = {f["id"]: dict(f, pos=parse_cell(f["cell"])) for f in m.get("features", [])}
        self.extraction = set(expand(data["deployment"]["extraction"]))

    def terrain(self, p):
        return self.grid[p[1]][p[0]]

    def inside(self, p):
        return 0 <= p[0] < self.w and 0 <= p[1] < self.h

    def neighbors(self, p):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            q = (p[0] + dx, p[1] + dy)
            if self.inside(q):
                yield q

    def step_ok(self, a, b):
        if COST[self.terrain(b)] is None:
            return False
        if (a in self.elevated) != (b in self.elevated):
            return "r" in (self.terrain(a), self.terrain(b))
        return True

    def paths(self, src, blocked=frozenset()):
        dist, prev, q = {src: 0}, {}, [(0, src)]
        while q:
            c, p = heapq.heappop(q)
            if c > dist[p]:
                continue
            for n in self.neighbors(p):
                if n in blocked or not self.step_ok(p, n):
                    continue
                nc = c + COST[self.terrain(n)]
                if nc < dist.get(n, 1e9):
                    dist[n], prev[n] = nc, p
                    heapq.heappush(q, (nc, n))
        return dist, prev

    def los(self, a, b, viewer_elevated):
        for p in bresenham(a, b)[1:-1]:
            t = self.terrain(p)
            if t in BLOCKS_LOS and not (viewer_elevated and t == "R"):
                return False
        return True

    def vision(self, p, radius):
        elev = p in self.elevated
        r = radius + (1 if elev else 0)
        return {(x, y) for y in range(self.h) for x in range(self.w)
                if manhattan(p, (x, y)) <= r and self.los(p, (x, y), elev)}

    def cone(self, p, facing):
        dx, dy = DIRS[facing]
        out = set()
        for y in range(self.h):
            for x in range(self.w):
                ox, oy = x - p[0], y - p[1]
                if dx == 0 or dy == 0:  # axe
                    fwd = ox * dx + oy * dy
                    side = abs(ox) if dx == 0 else abs(oy)
                    ok = 1 <= fwd <= 4 and side <= fwd - 1
                else:  # diagonale : quadrant, axes exclus
                    ok = ox * dx > 0 and oy * dy > 0 and abs(ox) + abs(oy) <= 4
                if ok and self.los(p, (x, y), p in self.elevated):
                    out.add((x, y))
        return out


class Game:
    def __init__(self, data, rules=()):
        self.m = Mission(data)
        self.d = data
        self.rules = set(rules)  # règles débloquées par la campagne (ex. radio_silence)
        self.units = {u["id"]: {"type": u["type"], "pos": parse_cell(u["cell"]),
                                "hp": UNITS[u["type"]][1], "status": "active",
                                "braced": False, "rampart": False, "silent": False}
                      for u in data["deployment"]["units"]}
        self.guards = {}
        for g in data["guardians"]:
            st = {"type": g["type"], "pos": parse_cell(g["cell"]), "cycle": g.get("facing_cycle"),
                  "facing": g.get("facing"), "route": [parse_cell(c) for c in g.get("route", [])],
                  "mode": g.get("route_mode", "loop"), "ri": 0, "dirn": 1,
                  "hp": GUARD_HP[g["type"]], "chase": None}
            self.guards[g["id"]] = st
        terr = data["map"].get("territory", {})
        self.recolored = set(expand(terr.get("recolored")))
        self.alert_enabled = data["alert"].get("enabled", True)
        self.alert = ALERTS.index(data["alert"]["initial"])
        self.alert_max, self.quiet_phases = self.alert, 0
        self.turn, self.completed = 0, 0
        self.revealed, self.observed_guards = set(), set()
        self.probed = set()
        self.interacted, self.flags = set(), set()
        self.terrains_entered, self.territory_entered = set(), False
        self.end_turn_on_recolored = False
        self.countdowns, self.expired = {}, set()
        self.advance, self.extraction_open = None, True
        self.fired, self.seq_progress = set(), {}
        self.result, self.result_turn, self.log = None, None, []
        self.neutralized = set()
        self.refresh_vision()

    # ---------- état dérivé
    def active(self):
        return {k: u for k, u in self.units.items() if u["status"] == "active"}

    def occupied(self, exclude=None):
        occ = {u["pos"] for k, u in self.active().items() if k != exclude}
        return occ | {g["pos"] for g in self.guards.values()}

    def refresh_vision(self):
        seen = set(self.probed)
        for u in self.active().values():
            seen |= {u["pos"]} if u["silent"] else self.m.vision(u["pos"], UNITS[u["type"]][2])
        self.current_vision = seen
        self.revealed |= seen
        for gid, g in self.guards.items():
            if g["pos"] in seen:
                self.observed_guards.add(gid)

    # ---------- conditions
    def match_unit(self, sel, uid):
        return sel == "any" or sel == uid or sel == self.units[uid]["type"]

    def cond(self, c, final=False, path="r"):
        if "all" in c:
            return all(self.cond(x, final, f"{path}.a{i}") for i, x in enumerate(c["all"]))
        if "any" in c:
            return any(self.cond(x, final, f"{path}.o{i}") for i, x in enumerate(c["any"]))
        if "not" in c:
            return not self.cond(c["not"], final, path + ".n")
        if "sequence" in c:
            i = self.seq_progress.get(path, 0)
            while i < len(c["sequence"]) and self.cond(c["sequence"][i], final, f"{path}.s{i}"):
                i += 1
            self.seq_progress[path] = i
            return i == len(c["sequence"])
        t = c["type"]
        if t == "turn_start":
            return self.turn >= c["turn"]
        if t == "turn_end":
            return self.completed >= c["turn"]
        if t == "max_turns":
            return self.result_turn is not None and self.result_turn <= c["value"]
        if t == "unit_in":
            cells = set(expand(c["cells"]))
            return any(self.match_unit(c["unit"], k) and u["pos"] in cells for k, u in self.active().items())
        if t == "all_units_extracted":
            st = [u["status"] for u in self.units.values()]
            return "active" not in st and "extracted" in st
        if t == "unit_extracted":
            return any(self.match_unit(c["unit"], k) and u["status"] == "extracted" for k, u in self.units.items())
        if t == "unit_disabled":
            return any(self.match_unit(c["unit"], k) and u["status"] == "disabled" for k, u in self.units.items())
        if t == "no_unit_disabled":
            return all(u["status"] != "disabled" for u in self.units.values())
        if t == "interacted":
            return c["feature"] in self.interacted
        if t == "feature_revealed":
            return self.m.features[c["feature"]]["pos"] in self.revealed
        if t == "cells_revealed":
            return set(expand(c["cells"])) <= self.revealed
        if t == "reveal_ratio_at_least":
            return len(self.revealed) / (self.m.w * self.m.h) >= c["value"]
        if t == "terrain_entered":
            return c["terrain"] in self.terrains_entered
        if t == "territory_revealed":
            return bool(self.recolored & self.revealed)
        if t == "territory_entered":
            return self.territory_entered
        if t == "never_end_turn_on":
            return not self.end_turn_on_recolored
        if t == "unit_end_turn_on":
            return self.end_turn_on_recolored
        if t == "guardian_observed":
            return bool(self.observed_guards) if c.get("guardian", "any") == "any" else c["guardian"] in self.observed_guards
        if t == "alert_at_least":
            return self.alert >= ALERTS.index(c["level"])
        if t == "alert_never_above":
            return self.alert_max <= ALERTS.index(c["level"])
        if t == "countdown_expired":
            return c["countdown"] in self.expired
        if t == "flag":
            return c["name"] in self.flags
        if t == "guardian_neutralized":
            return bool(self.neutralized) if c.get("guardian", "any") == "any" else c["guardian"] in self.neutralized
        if t == "no_guardian_neutralized":
            return not self.neutralized
        raise RuleError(f"condition inconnue {t}")

    # ---------- déclencheurs et fin
    def check(self):
        for tr in self.d["triggers"]:
            if tr["id"] in self.fired and tr.get("once", True):
                continue
            if self.cond(tr["when"], path="t." + tr["id"]):
                self.fired.add(tr["id"])
                for a in tr["do"]:
                    self.act(a)
        if self.result:
            return
        obj = self.d["objectives"]
        if self.cond(obj["main"]["condition"], path="main"):
            self.finish("victory")
        elif "failure" in obj and self.cond(obj["failure"], path="fail"):
            self.finish("failure")
        elif not self.active():
            self.finish("failure" if all(u["status"] == "disabled" for u in self.units.values()) else "retreat")

    def finish(self, res):
        if not self.result:
            self.result, self.result_turn = res, self.turn

    def act(self, a):
        t = a["type"]
        if t == "set_flag":
            self.flags.add(a["name"])
        elif t == "start_countdown":
            self.countdowns[a["id"]] = a["turns"]
        elif t == "territory_advance":
            self.advance = a
        elif t == "close_extraction":
            self.extraction_open = False
            for u in self.active().values():
                u["status"] = "disabled"
        elif t == "set_alert":
            self.set_alert(ALERTS.index(a["level"]))
        elif t == "end_mission":
            self.finish(a["result"])
        elif t == "guardian_order" and "chase_cell" in a:
            for gid, g in self.guards.items():
                if a["guardian"] in ("all", gid) and g["type"] == "patroller":
                    g["chase"] = parse_cell(a["chase_cell"])
        # show_tip, dialogue, highlight, camera_focus, cinematic, guardian_order : présentation

    def set_alert(self, lvl):
        self.alert = min(lvl, len(ALERTS) - 1)
        self.alert_max = max(self.alert_max, self.alert)

    # ---------- commandes du joueur
    def move(self, uid, dest):
        u = self.units[uid]
        if u["status"] != "active" or u["moved"]:
            raise RuleError(f"{uid} ne peut pas se déplacer")
        enemies = {g["pos"] for g in self.guards.values()}
        dist, prev = self.m.paths(u["pos"], frozenset(enemies))
        d = parse_cell(dest)
        if d not in dist:
            raise RuleError(f"{uid} : {dest} inaccessible")
        if dist[d] > UNITS[u["type"]][0]:
            raise RuleError(f"{uid} : {dest} coûte {dist[d]} > {UNITS[u['type']][0]}")
        if d in self.occupied(exclude=uid):
            raise RuleError(f"{uid} : {dest} occupée")
        path, p = [d], d
        while p != u["pos"]:
            p = prev[p]; path.append(p)
        for p in reversed(path[:-1]):
            self.terrains_entered.add(self.m.terrain(p))
            if p in self.recolored:
                self.territory_entered = True
            if not u["silent"]:
                self.revealed |= self.m.vision(p, UNITS[u["type"]][2])
        u["pos"], u["moved"] = d, True
        self.refresh_vision()

    def action(self, uid, kind, target=None):
        u = self.units[uid]
        if u["status"] != "active" or u["acted"]:
            raise RuleError(f"{uid} ne peut pas agir")
        if u["silent"] and kind != "reconnect":
            raise RuleError(f"{uid} est en silence radio")
        if kind == "silence":
            if "radio_silence" not in self.rules:
                raise RuleError("silence radio non débloqué")
            u["silent"] = True
        elif kind == "reconnect":
            if not u["silent"]:
                raise RuleError(f"{uid} est déjà relié")
            u["silent"] = False
        elif kind == "extract":
            if not self.extraction_open or u["pos"] not in self.m.extraction:
                raise RuleError(f"{uid} : rappel impossible ici")
            u["status"] = "extracted"
        elif kind == "probe":
            t = parse_cell(target)
            if u["type"] != "scout" or manhattan(u["pos"], t) > PROBE_RANGE or not self.m.inside(t):
                raise RuleError(f"{uid} : sonde impossible en {target}")
            self.probed |= {(t[0] + dx, t[1] + dy) for dx in range(-PROBE_RADIUS, PROBE_RADIUS + 1)
                            for dy in range(-PROBE_RADIUS, PROBE_RADIUS + 1)
                            if self.m.inside((t[0] + dx, t[1] + dy))}
        elif kind == "attack":
            t = parse_cell(target)
            gid = next((k for k, g in self.guards.items() if g["pos"] == t), None)
            if gid is None or not self.can_attack(uid, t):
                raise RuleError(f"{uid} : attaque impossible en {target}")
            g = self.guards[gid]
            g["hp"] -= self.attack_damage(uid, t)
            if g["hp"] <= 0:
                del self.guards[gid]
                self.neutralized.add(gid)
                if self.alert_enabled:
                    self.set_alert(self.alert + 1); self.quiet_phases = 0
        elif kind == "brace":
            u["braced"] = True
        elif kind == "rampart":
            if u["type"] != "protector":
                raise RuleError(f"{uid} : Rempart réservé au Protecteur")
            u["rampart"] = True
        elif kind == "repair":
            t = parse_cell(target)
            ally = next((k for k, o in self.units.items() if o["pos"] == t and o["status"] in ("active", "disabled")), None)
            if u["type"] != "technician" or ally is None or ally == uid or manhattan(t, u["pos"]) != 1:
                raise RuleError(f"{uid} : réparation impossible en {target}")
            o = self.units[ally]
            if o["status"] == "disabled":
                o["status"], o["hp"] = "active", 1
            elif o["hp"] < UNITS[o["type"]][1]:
                o["hp"] += 1
            else:
                raise RuleError(f"{uid} : {ally} est intact")
        elif kind in ("interact", "interface"):
            f = next((f for f in self.m.features.values() if f["cell"] == target), None)
            if not f or manhattan(f["pos"], u["pos"]) != 1:
                raise RuleError(f"{uid} : {target} n'est pas un point d'intérêt adjacent")
            if f["kind"] in INTERFACE_KINDS and u["type"] != "technician":
                raise RuleError(f"{uid} : {f['kind']} exige le Technicien")
            self.interacted.add(f["id"])
        else:
            raise RuleError(f"action inconnue {kind}")
        u["acted"] = True
        self.refresh_vision()

    def can_attack(self, uid, t):
        u = self.units[uid]
        if u["type"] not in ATTACK:
            return False
        _dmg, rmin, rmax = ATTACK[u["type"]]
        d = manhattan(u["pos"], t)
        return rmin <= d <= rmax and self.m.los(u["pos"], t, u["pos"] in self.m.elevated)

    def attack_damage(self, uid, t):
        u = self.units[uid]
        dmg = ATTACK[u["type"]][0]
        if manhattan(u["pos"], t) > 1 and self.m.terrain(t) in BLOCKS_LOS:
            dmg -= 1  # couvert contre les tirs à distance
        return max(1, dmg)

    def damage_to(self, uid, base, ranged, hp_view=None):
        u = self.units[uid]
        dmg = base - (1 if u["braced"] else 0)
        if ranged and self.m.terrain(u["pos"]) in BLOCKS_LOS:
            dmg -= 1
        if any(k != uid and o["status"] == "active" and o["rampart"] and manhattan(o["pos"], u["pos"]) == 1
               for k, o in self.units.items()):
            dmg -= 1
        return max(1, dmg)  # un coup porte toujours au moins 1 dégât

    # ---------- déroulé d'un tour
    def start_turn(self):
        self.turn += 1
        self.probed = set()
        self.refresh_vision()
        for u in self.units.values():
            u["moved"] = u["acted"] = False
            u["braced"] = u["rampart"] = False
        self.check()

    def end_player_turn(self):
        for u in self.active().values():
            if u["pos"] in self.recolored:
                self.end_turn_on_recolored = True
        self.check()
        if self.result:
            return
        self.guardian_phase()
        self.completed += 1
        dl = self.d["objectives"]["main"].get("deadline_turn")
        if dl and self.completed >= dl and not self.result:
            self.finish("failure")
        self.check()

    def hidden(self, uid, guard_cells):
        u = self.units[uid]
        near = any(manhattan(u["pos"], q) == 1 for q in guard_cells)
        return u["type"] == "scout" and self.m.terrain(u["pos"]) in BLOCKS_LOS and not near

    def plan(self):
        """Phase des Gardiens simulée sans modifier l'état : ce que les intentions affichent.
        Un drone en silence radio barre toujours le passage, mais n'est ni vu ni visé."""
        unit_at = {u["pos"]: k for k, u in self.active().items()}
        protectors = [u["pos"] for u in self.active().values() if u["type"] == "protector"]
        gpos = {gid: g["pos"] for gid, g in self.guards.items()}
        plans, watched, blockers = {}, set(), set()
        for gid, g in self.guards.items():
            pl = {"path": [], "facing": None, "ri": g["ri"], "dirn": g["dirn"], "attack": None}
            if g["type"] == "patroller":
                target = g["chase"]
                if target is None and g["route"]:
                    pl["ri"], pl["dirn"] = self.next_waypoint(g)
                    target = g["route"][pl["ri"]]
                if target is not None and target != g["pos"]:
                    others = frozenset(q for k, q in gpos.items() if k != gid)
                    dist, prev = self.m.paths(g["pos"], others)
                    if target in dist:
                        path, p = [target], target
                        while p != g["pos"]:
                            p = prev[p]; path.append(p)
                        for p in list(reversed(path))[1:GUARD_MOVE["patroller"] + 1]:
                            if p in unit_at:
                                if not self.units[unit_at[p]]["silent"]:
                                    blockers.add(p)
                                break
                            pl["path"].append(p)
                            if any(manhattan(p, q) == 1 for q in protectors):
                                break  # Ancrage
                end = pl["path"][-1] if pl["path"] else g["pos"]
                gpos[gid] = end
                watched |= self.m.vision(end, 2)
            elif g["type"] == "sentinel":
                pl["facing"] = g["cycle"][(self.turn - 1) % len(g["cycle"])] if g["cycle"] else g["facing"]
                watched |= self.m.cone(g["pos"], pl["facing"])
            plans[gid] = pl
        hp = {k: u["hp"] for k, u in self.active().items() if not u["silent"]}
        attacks = []
        cells = set(gpos.values())
        for gid, g in self.guards.items():
            pos, cand, base, ranged = gpos[gid], [], 0, False
            if g["type"] == "patroller" and self.alert >= 1:
                cand = [k for k in hp if hp[k] > 0 and manhattan(self.units[k]["pos"], pos) == 1]
                base = PATROLLER_DAMAGE
            elif g["type"] == "sentinel" and self.alert >= 2:
                cone = self.m.cone(pos, plans[gid]["facing"])
                cand = [k for k in hp if hp[k] > 0 and self.units[k]["pos"] in cone
                        and manhattan(self.units[k]["pos"], pos) <= SENTINEL_RANGE and not self.hidden(k, cells)]
                base, ranged = SENTINEL_DAMAGE, True
            if cand:
                k = min(cand, key=lambda k: (manhattan(self.units[k]["pos"], pos), hp[k], self.units[k]["pos"]))
                dmg = self.damage_to(k, base, ranged)
                hp[k] -= dmg
                attacks.append((gid, k, dmg))
        detected = set(blockers)
        for p, uid in unit_at.items():
            if uid not in hp or hp[uid] <= 0:
                continue
            if (p in watched and not self.hidden(uid, cells)) or (p in self.recolored and self.guards):
                detected.add(p)
        return {"plans": plans, "watched": watched, "attacks": attacks, "detected": detected}

    def guardian_phase(self):
        k = self.turn
        pl = self.plan()
        for gid, p in pl["plans"].items():
            g = self.guards[gid]
            if p["path"]:
                g["pos"] = p["path"][-1]
            if g["chase"] is None:
                g["ri"], g["dirn"] = p["ri"], p["dirn"]
            elif g["pos"] == g["chase"]:
                g["chase"] = None
            if p["facing"]:
                g["facing"] = p["facing"]
        for gid, uid, dmg in pl["attacks"]:
            u = self.units[uid]
            u["hp"] -= dmg
            self.log.append(f"phase {k} : {gid} frappe {uid} ({dmg})")
            if u["hp"] <= 0:
                u["status"] = "disabled"
        detected = pl["detected"]
        if self.alert_enabled and self.guards:
            if detected:
                self.set_alert(self.alert + 1); self.quiet_phases = 0
                self.log.append(f"phase {k} : détection en {', '.join(sorted(cell_name(p) for p in detected))}")
                for g in self.guards.values():
                    if g["type"] == "patroller":
                        g["chase"] = min(detected, key=lambda p: (manhattan(p, g["pos"]), p))
            else:
                self.quiet_phases += 1
                if self.quiet_phases >= 3 and self.alert > 0:
                    self.alert -= 1; self.quiet_phases = 0
                    if self.alert == 0:
                        for g in self.guards.values():
                            g["chase"] = None
        if self.advance:
            front = max((p[1] for p in self.recolored), default=-1) + 1
            if self.advance["direction"] == "S" and front < self.m.h:
                self.recolored |= {(x, front) for x in range(self.m.w)}
            for uid, u in self.active().items():
                if u["pos"] in self.recolored:
                    u["hp"] -= self.advance.get("damage", 1)
                    if u["hp"] <= 0:
                        u["status"] = "disabled"
        for cid in list(self.countdowns):
            self.countdowns[cid] -= 1
            if self.countdowns[cid] <= 0:
                del self.countdowns[cid]; self.expired.add(cid)
        self.refresh_vision()

    def next_waypoint(self, g):
        n, ri, dirn = len(g["route"]), g["ri"], g["dirn"]
        if g["mode"] == "loop":
            return (ri + 1) % n, 1
        if not 0 <= ri + dirn < n:
            dirn = -dirn
        return ri + dirn, dirn

    def records(self):
        return {r["id"]: self.cond(r["condition"], final=True, path="rec." + r["id"])
                for r in self.d["objectives"]["records"]}


def replay(data, rep):
    g = Game(data, rep.get("rules", ()))
    for cmds in rep["turns"]:
        g.start_turn()
        for c in cmds:
            if g.result:
                break
            if "move" in c:
                g.move(c["unit"], c["move"])
            if "act" in c:
                g.action(c["unit"], c["act"], c.get("target"))
            g.check()
        if g.result:
            break
        g.end_player_turn()
        if g.result:
            break
    return g
