"""Comparative balance regressions for scarce ground and spatial setup."""
import importlib.util
import sys
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('surface_heuristic', Path(__file__).resolve().parents[1] / 'tools/card_heuristic.py')
heuristic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = heuristic
SPEC.loader.exec_module(heuristic)


class SurfaceHeuristicTests(unittest.TestCase):
    def score(self, actions, *, flurry=False, element='none'):
        return heuristic.score_card('comparison', {'actions': actions, 'flurry': flurry, 'element': element, 'time': 5}, heuristic.HeuristicWeights())

    def test_connected_conductors_have_more_setup_value_than_equal_disconnected_cells(self):
        connected = self.score([{'type': 'surface', 'surface': 'electrified', 'range': 4, 'pattern': [[0, 0], [1, 0], [2, 0]]}])
        diagonal = self.score([{'type': 'surface', 'surface': 'electrified', 'range': 4, 'pattern': [[0, 0], [1, 1], [2, 2]]}])
        self.assertGreater(connected.surfaces, diagonal.surfaces)

    def test_new_ice_does_not_make_instant_freeze_more_available(self):
        attack = {'type': 'ranged', 'damage': 4, 'range': 5, 'element': 'ice'}
        plain = self.score([attack])
        fresh = self.score([{'type': 'surface', 'surface': 'ice', 'range': 5}, attack])
        self.assertEqual(plain.control, fresh.control)
        self.assertGreater(fresh.surfaces, plain.surfaces)

    def test_new_fire_is_available_to_a_paid_detonate(self):
        blast = {'type': 'detonate', 'damage': 6, 'range': 4}
        existing = self.score([blast])
        painted = self.score([{'type': 'surface', 'surface': 'fire', 'range': 4}, blast])
        self.assertGreater(painted.offense, existing.offense)
        self.assertGreater(painted.surface_fuel_cost, existing.surface_fuel_cost)

    def test_flurry_repeats_direct_damage_but_not_the_same_consumed_network(self):
        direct = {'type': 'ranged', 'damage': 4, 'range': 5}
        normal = self.score([direct])
        repeat = self.score([direct], flurry=True)
        self.assertEqual(repeat.offense, normal.offense * 2)
        charged = self.score([direct], element='lightning')
        charged_repeat = self.score([direct], element='lightning', flurry=True)
        self.assertGreater(charged_repeat.offense, repeat.offense)
        self.assertLess(charged_repeat.offense - repeat.offense, 2 * (charged.offense - normal.offense))

    def test_explicit_repaint_restores_each_detonate_but_unpaid_fuel_does_not(self):
        blast = {'type': 'detonate', 'damage': 6, 'range': 4}
        one = self.score([blast])
        repeat = self.score([blast], flurry=True)
        self.assertLess(repeat.offense, one.offense * 2)
        self.assertLess(repeat.surface_fuel_cost, one.surface_fuel_cost * 2)
        sequence = [{'type': 'surface', 'surface': 'fire', 'range': 4}, blast]
        one_repaint = self.score(sequence)
        repeat_repaint = self.score(sequence, flurry=True)
        self.assertEqual(repeat_repaint.offense, 2 * one_repaint.offense)
        self.assertEqual(repeat_repaint.surface_fuel_cost, 2 * one_repaint.surface_fuel_cost)

    def test_freeze_payoff_cannot_refresh_on_every_flurry_copy(self):
        ice_hit = {'type': 'ranged', 'damage': 4, 'range': 5, 'element': 'ice'}
        one = self.score([ice_hit])
        repeat = self.score([ice_hit], flurry=True)
        self.assertGreater(repeat.control, one.control)
        self.assertLess(repeat.control, 2 * one.control)


if __name__ == '__main__':
    unittest.main()
