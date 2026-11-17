#!/usr/bin/env python3
"""Writes Modules/Suffixes.lua: the stats each random suffix adds, by suffix id.

Random-suffix gear such as "of the Monkey" keeps its stats in a bonus list, not on the item, and an auction item key
only names the suffix by its ItemNameDescription id. The client has no API from that id to the stats, so they are read
from its item tables on wago.tools:

  ItemNameDescription  suffix id and name
  ItemBonus            bonus list rows: Type 5 is the suffix name (Value_0 its id), Type 2 a stat (Value_0 its type)
  ItemBonusTreeNode    the bonus lists of a bonus tree
  ItemXBonusTree       the bonus tree of an item

Run from the repo root after a new client build:  python3 Tools/suffixes.py 1.60.1.70938
"""

import csv
import io
import sys
import urllib.request
from collections import Counter, defaultdict

# Stat types of ItemBonus Type 2 rows and ItemSparse StatModifier_bonusStat, as the keys Modules/ItemStats.lua reads.
# The suffix names confirm them: "of the Monkey" is 3 and 7, "of Power" 38, "of Fiery Wrath" 85. Types the filter
# cannot read, such as the resistances 51 to 56, are left out.
STATS = {
    3: "agility", 4: "strength", 5: "intellect", 6: "spirit", 7: "stamina",
    12: "defense", 13: "dodge", 14: "parry", 15: "block",
    31: "hit", 32: "crit", 36: "haste", 37: "expertise",
    38: "attackpower", 39: "rangedattackpower",
    41: "healing", 42: "spellpower", 43: "mp5", 45: "spellpower", 46: "hp5", 47: "spellpenetration", 48: "blockvalue",
    84: "holydamage", 85: "firedamage", 86: "naturedamage", 87: "frostdamage", 88: "shadowdamage", 89: "arcanedamage",
}

OUTPUT = "Modules/Suffixes.lua"


def table(name, build):
    url = f"https://wago.tools/db2/{name}/csv?build={build}"
    request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(request) as response:
        return list(csv.DictReader(io.StringIO(response.read().decode("utf-8"))))


def lua_list(values):
    return "{ " + ", ".join(values) + " }"


def wrapped(numbers, indent, width=118):
    lines, line = [], indent
    for number in numbers:
        piece = f"{number}, "
        if len(line) + len(piece) > width:
            lines.append(line.rstrip())
            line = indent
        line += piece
    lines.append(line.rstrip())
    return "\n".join(lines)


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    build = sys.argv[1]

    names = {row["ID"]: row["Description_lang"] for row in table("ItemNameDescription", build)}

    # Per bonus list: its suffix ids and its readable stats
    suffixes, stats = defaultdict(set), defaultdict(set)
    for row in table("ItemBonus", build):
        bonus_list = row["ParentItemBonusListID"]
        if row["Type"] == "5":
            suffixes[bonus_list].add(row["Value_0"])
        elif row["Type"] == "2" and int(row["Value_0"]) in STATS:
            stats[bonus_list].add(STATS[int(row["Value_0"])])

    # Per bonus tree: its lists, through child trees too
    children = defaultdict(list)
    for row in table("ItemBonusTreeNode", build):
        children[row["ParentItemBonusTreeID"]].append(row)

    def lists_of(tree, seen):
        if tree in seen:
            return set()
        seen.add(tree)
        found = set()
        for node in children[tree]:
            if node["ChildItemBonusListID"] != "0":
                found.add(node["ChildItemBonusListID"])
            if node["ChildItemBonusTreeID"] != "0":
                found |= lists_of(node["ChildItemBonusTreeID"], seen)
        return found

    # Per suffix: the stat set of every item that can roll it
    by_suffix = defaultdict(dict)
    for row in table("ItemXBonusTree", build):
        item = int(row["ItemID"])
        for bonus_list in lists_of(row["ItemBonusTreeID"], set()):
            for suffix in suffixes[bonus_list]:
                found = tuple(sorted(stats[bonus_list]))
                known = by_suffix[suffix].setdefault(item, found)
                if known != found:
                    sys.exit(f"Item {item} rolls suffix {suffix} with two stat sets: {known} and {found}")

    # The set most items share is the suffix's own; items that differ are listed apart
    common, exceptions = {}, []
    for suffix, items in by_suffix.items():
        common[suffix] = Counter(items.values()).most_common(1)[0][0]
        groups = defaultdict(list)
        for item, found in items.items():
            if found != common[suffix]:
                groups[found].append(item)
        for found, group in groups.items():
            exceptions.append((int(suffix), found, sorted(group)))

    out = [
        "local _, ns = ...",
        "",
        f"-- Written by Tools/suffixes.py from the client's item tables, build {build}. Do not edit by hand.",
        "",
        "-- The stats a random suffix adds, by the suffix id an auction item key carries. Suffix gear keeps its stats in",
        "-- the suffix, not on the item, so the tooltip of an item key does not show them. Stats the filter cannot read,",
        "-- such as resistances, are left out",
        "ns.SuffixStats = {",
    ]
    for suffix in sorted(common, key=int):
        if common[suffix]:
            keys = lua_list(f'"{key}"' for key in common[suffix])
            out.append(f"    [{suffix}] = {keys}, -- {names.get(suffix, '?')}")
    out += [
        "}",
        "",
        "-- Items whose suffix adds other stats than it does on most gear, such as weapons of Magic with Intellect",
        "ns.SuffixItemStats = {",
    ]
    for suffix, found, items in sorted(exceptions):
        keys = lua_list(f'"{key}"' for key in found)
        out.append(f"    {{ suffix = {suffix}, stats = {keys}, items = {{ -- {names.get(str(suffix), '?')}")
        out.append(wrapped(items, " " * 8))
        out.append("    } },")
    out += ["}", ""]

    with open(OUTPUT, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out))
    print(f"{OUTPUT}: {sum(1 for found in common.values() if found)} suffixes, {len(exceptions)} exception groups")


if __name__ == "__main__":
    main()
