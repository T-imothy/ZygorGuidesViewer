#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import unittest
from pathlib import Path

from validate_guides import (
    audit,
    load_classic_ids,
    next_applicable_step,
    parse_guides,
    run_transition_tests,
)


class BackportValidationTests(unittest.TestCase):
    addon: Path
    guides = []
    classic_ids = {}
    report = {}

    @classmethod
    def setUpClass(cls) -> None:
        cls.guides = parse_guides(sorted((cls.addon / "Guides").glob("Zygor*.lua")))
        cls.classic_ids = load_classic_ids(CLASSIC_DB)
        cls.report = audit(cls.guides, cls.classic_ids)

    def test_all_sources_parse(self) -> None:
        self.assertGreaterEqual(len(self.guides), 100)
        self.assertGreaterEqual(sum(len(guide.steps) for guide in self.guides), 4000)

    def test_transition_model(self) -> None:
        self.assertEqual(run_transition_tests(), [])

    def test_classic_database_fixture(self) -> None:
        self.assertIn(772, self.classic_ids["quests"])
        self.assertIn(758, self.classic_ids["quests"])
        self.assertNotIn(11129, self.classic_ids["quests"])
        self.assertNotIn(23618, self.classic_ids["creatures"])
        self.assertNotIn(33009, self.classic_ids["items"])

    def test_tauren_kyle_chain_only(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        self.assertEqual(len(tauren.steps), 195)
        excluded = set(self.report["unavailable"].get(title, {}))
        self.assertEqual(excluded, {68, 69, 72, 73})
        self.assertTrue({70, 71, 74}.isdisjoint(excluded))

    def test_tauren_explicit_next_guide(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        self.assertEqual(
            tauren.next_guide,
            "Zygor's Horde Leveling Guides\\Main Guide (13-20)",
        )

    def test_tauren_barrens_zone_fallback(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        step82 = tauren.steps[81]
        step83 = tauren.steps[82]
        self.assertEqual(step82.zone_targets, ["The Barrens"])
        self.assertIn(("The Barrens", 61.4, 21.1), step83.coordinates)

    def test_tauren_warrior_class_block_skip(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        excluded = set(self.report["unavailable"].get(title, {}))
        self.assertEqual(
            next_applicable_step(tauren, 88, "Tauren", "Warrior", excluded),
            130,
        )

    def test_tauren_item_started_quest(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        self.assertIn("item_start_accept", tauren.steps[152].actions)

    def test_tauren_flight_path_step(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        self.assertIn("flight_path", tauren.steps[160].actions)

    def test_flight_path_name_normalization(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn('name=string.gsub(name,"^the%s+","")', compat)
        self.assertIn(
            "ZygorClassic_FlightPathKey238(pathKey)==wanted",
            compat,
        )

    def test_tauren_crossroads_home_route(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        step166 = tauren.steps[165]
        self.assertIn("home", step166.actions)
        self.assertIn(("The Barrens", 52.0, 30.0), step166.coordinates)
        self.assertIn(3934, step166.npc_ids)

    def test_tauren_silverpine_return_flight_route(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        step190 = tauren.steps[189]
        self.assertIn(("Silverpine Forest", 45.6, 42.6), step190.coordinates)
        self.assertIn(2226, step190.npc_ids)
        self.assertIn("Undercity", step190.zone_targets)

    def test_tauren_end_handoff_recovery_chain(self) -> None:
        title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        tauren = next(guide for guide in self.guides if guide.title == title)
        self.assertIn(447, tauren.steps[190].quest_ids)
        self.assertIn(("The Barrens", 52.0, 29.9), tauren.steps[191].coordinates)
        self.assertIn("Durotar", tauren.steps[192].zone_targets)

    def test_tauren_final_travel_uses_next_guide_route(self) -> None:
        tauren_title = "Zygor's Horde Leveling Guides\\Tauren (1-13)"
        main_title = "Zygor's Horde Leveling Guides\\Main Guide (13-20)"
        tauren = next(guide for guide in self.guides if guide.title == tauren_title)
        main = next(guide for guide in self.guides if guide.title == main_title)
        self.assertEqual(tauren.next_guide, main.title)
        self.assertIn("The Barrens", tauren.steps[-1].zone_targets)
        self.assertTrue(
            any(map_name == "The Barrens" for map_name, _, _ in main.steps[0].coordinates)
        )
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn("TEST245: the same fallback must cross", compat)

    def test_presentation_hides_pipe_metadata(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn('line=string.gsub(line,"|.*$","")', compat)
        self.assertIn('return "Talk to "..value', compat)

    def test_split_player_ui_and_minimap_logo(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        icon = (self.addon / "ZygorMapIcon.xml").read_text(encoding="utf-8")
        self.assertIn('CreateFrame("Frame","ZygorClassicPlayerFrame246",UIParent)', compat)
        self.assertIn('ZygorClassicPlayerDebug246:SetText("Diagnostics")', compat)
        self.assertIn('ZygorClassicPlayerToggle246:SetText("Player UI")', compat)
        self.assertIn('ZygorGuidesViewerFrame:SetWidth(900)', compat)
        self.assertNotIn('(zglogo)', icon)
        self.assertIn(r"Skin\arrow-here", icon)
        self.assertIn('Skin\\\\arrow-here', compat)
        self.assertIn('CreateFrame("Frame","ZygorClassicHelp252",UIParent)', compat)
        self.assertIn('ZygorClassicPlayerHelp252:SetText("Help")', compat)
        self.assertIn('ZygorClassicMainHelp252:SetText("Help")', compat)
        self.assertIn('ZYGOR_BACKPORT_VERSION = "TEST252"', compat)

    def test_manual_guide_picker_is_faction_and_vanilla_scoped(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn("function ZygorClassic_GuideChoices247()", compat)
        self.assertIn('string.find(title,factionText,1,true)', compat)
        self.assertIn('not invalid and low and high and high<=60', compat)
        self.assertIn('ZygorClassicDB.manualGuide247[key]=guideIndex', compat)
        self.assertIn('ZygorClassicChooseGuide247:SetText("Choose Guide")', compat)

    def test_auto_manual_guide_mode(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn("function ZygorClassic_RecommendedGuide248()", compat)
        self.assertIn('choice.low==level and choice.low>1', compat)
        self.assertIn('string.find(choice.title,"\\\\"..race.." (",1,true)', compat)
        self.assertIn("function ZygorClassic_UseRecommended248()", compat)
        self.assertIn('ZygorClassicUseRecommended248:SetText("Use Recommended")', compat)
        self.assertIn('ZygorClassicGuideAutoFrame248:RegisterEvent("PLAYER_LEVEL_UP")', compat)
        self.assertIn('ZygorClassic_GuideMode248()~="AUTO"', compat)

    def test_manual_lock_preserves_current_step(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn("function ZygorClassic_LockCurrentGuide249()", compat)
        self.assertIn('ZygorClassicDB.manualGuide247[key]=ZygorClassicGuideIndex or 1', compat)
        self.assertIn('ZygorClassicLockCurrent249:SetText("Lock Current (Manual)")', compat)
        self.assertIn('guideIndex==(ZygorClassicGuideIndex or 1)', compat)
        lock_body = compat.split("function ZygorClassic_LockCurrentGuide249()", 1)[1].split("end", 1)[0]
        self.assertNotIn("ZygorClassicStepIndex=", lock_body)

    def test_saved_guide_owns_level_boundary(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        self.assertIn("ZygorClassic_PredecessorRecovery242", compat)
        self.assertIn("TEST242 explicit guide handoff", compat)
        self.assertIn("Saved progress is", compat)
        self.assertIn('string.gsub(parsed.next, "\\\\\\\\", "\\\\")', compat)
        self.assertNotIn("local function ZygorClassic_FindGuideByTitle242", compat)
        self.assertNotIn("local function ZygorClassic_LiveTurninStep242", compat)
        self.assertNotIn("local function ZygorClassic_PredecessorRecovery242", compat)
        self.assertIn("rejected non-user guide change", compat)
        self.assertIn("TEST244 confirmed predecessor", compat)
        self.assertIn("function ZygorClassic_NextGuide(delta,userClick)", compat)

    def test_vanilla_chunk_local_budget(self) -> None:
        compat = (self.addon / "Compat_112.lua").read_text(encoding="utf-8")
        declarations = re.findall(r"^local\s", compat, flags=re.MULTILINE)
        # TEST241 loaded successfully in the Vanilla client with 201 such
        # declarations. TEST242 rose to 204 and failed Lua's 200-active-local
        # compiler limit, so later revisions may never exceed this baseline.
        self.assertLessEqual(len(declarations), 201)

    def test_no_mixed_step_is_auto_excluded(self) -> None:
        mixed = {
            (issue["guide"], issue["step"])
            for issue in self.report["issues"]
            if issue["kind"] == "mixed_missing_quest"
        }
        excluded = {
            (title, int(step))
            for title, steps in self.report["unavailable"].items()
            for step in steps
        }
        self.assertTrue(mixed.isdisjoint(excluded))


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--addon", type=Path, required=True)
    parser.add_argument("--classic-db", type=Path, required=True)
    args, unittest_args = parser.parse_known_args()
    BackportValidationTests.addon = args.addon
    CLASSIC_DB = args.classic_db
    unittest.main(argv=[__file__, *unittest_args])
