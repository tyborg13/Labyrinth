"""Heuristic values for wave-4 family B mechanics (spec/card_mechanics_maneuver.md)."""
import importlib.util
import sys
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('maneuver_heuristic', Path(__file__).resolve().parents[1] / 'tools/card_heuristic.py')
heuristic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = heuristic
SPEC.loader.exec_module(heuristic)


class ManeuverHeuristicTests(unittest.TestCase):
    def score(self, actions, **card):
        return heuristic.score_card('comparison', {'actions': actions, 'element': 'none', 'time': 5, **card}, heuristic.HeuristicWeights())

    def test_area_force_scales_with_radius_and_distance(self):
        small = self.score([{'type': 'force_area', 'center': 'self', 'radius': 1, 'push': 1}])
        wide = self.score([{'type': 'force_area', 'center': 'self', 'radius': 3, 'push': 3}])
        self.assertGreater(small.control, 0.0)
        self.assertGreater(wide.control, small.control * 3)

    def test_area_force_has_no_rotate_bonus(self):
        weights = heuristic.HeuristicWeights()
        area = self.score([{'type': 'force_area', 'center': 'self', 'radius': 0, 'push': 1}])
        targets = heuristic.force_area_targets({'radius': 0}, weights)
        availability = weights.force_area_self_base_availability
        expected = (weights.push_value_per_tile + weights.displacement_hazard_value_per_tile + weights.collision_value_per_tile) * targets * availability
        self.assertAlmostEqual(area.control, expected)

    def test_consumed_center_needs_its_surface(self):
        free = self.score([{'type': 'force_area', 'center': 'target', 'range': 3, 'radius': 1, 'push': 2}])
        rubble = self.score([{'type': 'force_area', 'center': 'target', 'range': 3, 'radius': 1, 'push': 2, 'consume_center': 'rubble'}])
        self.assertLess(rubble.control, free.control)
        self.assertGreater(rubble.surface_fuel_cost, 0.0)

    def test_self_flags(self):
        self.assertGreater(self.score([{'type': 'self_flag', 'flag': 'ice_skate'}]).mobility, 0.0)
        self.assertLess(self.score([{'type': 'self_flag', 'flag': 'no_move'}]).mobility, 0.0)
        self.assertGreater(self.score([{'type': 'self_flag', 'flag': 'anchored'}]).defense, 0.0)
        self.assertGreater(self.score([{'type': 'self_flag', 'flag': 'fire_immune_turn'}]).defense, 0.0)

    def test_defensive_conversions(self):
        weights = heuristic.HeuristicWeights()
        self.assertAlmostEqual(self.score([{'type': 'mantle', 'amount': 2}]).defense, 2 * weights.mantle_per_layer)
        self.assertGreater(self.score([{'type': 'convert_block_to_stoneskin'}]).defense, 0.0)
        self.assertAlmostEqual(self.score([{'type': 'cleanse', 'statuses': ['bleed', 'shock']}]).defense, 2 * weights.cleanse_value_per_status)

    def test_petrify_pays_for_the_block_it_grants(self):
        cheap = self.score([{'type': 'petrify', 'range': 3, 'block': 0}])
        armored = self.score([{'type': 'petrify', 'range': 3, 'block': 8}])
        self.assertGreater(cheap.control, armored.control)
        self.assertGreater(armored.control, 0.0)

    def test_move_and_blink_riders(self):
        plain = self.score([{'type': 'move', 'range': 3}])
        self.assertGreater(self.score([{'type': 'move', 'range': 3, 'trail_surface': 'fire'}]).surfaces, plain.surfaces)
        self.assertGreater(self.score([{'type': 'move', 'range': 3, 'origin_surface': 'ice'}]).surfaces, plain.surfaces)
        self.assertGreater(self.score([{'type': 'move', 'range': 3, 'block_per_tile': 1}]).defense, plain.defense)
        self.assertLess(self.score([{'type': 'move', 'range': 3, 'straight_line': True}]).mobility, plain.mobility)
        self.assertGreater(self.score([{'type': 'move', 'range': 4, 'trail_light': {'radius': 1, 'duration': 2}}]).radiance, 0.0)
        hot = self.score([{'type': 'move', 'range': 2, 'if_started_on_surface': {'surface': 'fire', 'rewards': [{'type': 'block', 'amount': 4}]}}])
        self.assertGreater(hot.defense, 0.0)
        blink = self.score([{'type': 'blink', 'range': 3}])
        self.assertLess(self.score([{'type': 'blink', 'range': 3, 'destination_requires_light': True}]).mobility, blink.mobility)
        self.assertGreater(self.score([{'type': 'blink', 'range': 3, 'illusion_at_origin': 4}]).defense, blink.defense)
        self.assertGreater(self.score([{'type': 'blink', 'range': 3, 'if_no_adjacent_enemies': [{'type': 'card_play', 'amount': 1}]}]).flow, blink.flow)

    def test_swap_and_force_trail(self):
        swap = self.score([{'type': 'swap', 'range': 3, 'targets': ['enemy', 'illusion']}])
        self.assertGreater(swap.mobility, 0.0)
        self.assertGreater(swap.control, 0.0)
        plain = self.score([{'type': 'push', 'damage': 2, 'range': 3, 'amount': 2}])
        trail = self.score([{'type': 'push', 'damage': 2, 'range': 3, 'amount': 2, 'trail_surface': 'fire'}])
        self.assertGreater(trail.surfaces, plain.surfaces)


if __name__ == '__main__':
    unittest.main()
