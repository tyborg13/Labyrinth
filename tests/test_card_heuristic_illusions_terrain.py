"""Scoring of the wave-4 illusion and terrain families (spec/card_mechanics_illusions_terrain.md)."""
import importlib.util
import sys
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('illusion_terrain_heuristic', Path(__file__).resolve().parents[1] / 'tools/card_heuristic.py')
heuristic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = heuristic
SPEC.loader.exec_module(heuristic)

WEIGHTS = heuristic.HeuristicWeights()
ADJ = [[0, -1], [1, 0], [0, 1], [-1, 0]]


def illusion(health=3, rng=3, **extra):
    action = {'type': 'illusion', 'health': health, 'range': rng}
    action.update(extra)
    return action


def score(actions, **card):
    card = dict(card)
    card.setdefault('time', 5)
    card['actions'] = actions
    return heuristic.score_card('illusion_terrain_case', card, WEIGHTS)


class IllusionTerrainHeuristicTests(unittest.TestCase):
    def test_retort_is_damage_discounted_by_trigger_chance(self):
        plain = score([illusion()])
        charged = score([illusion(on_damaged={'damage': 4, 'element': 'lightning', 'shock': 1})])
        expected = heuristic.immediate_damage_value(4, WEIGHTS.illusion_retort_trigger_chance, 1.0, WEIGHTS)
        self.assertAlmostEqual(charged.offense - plain.offense, expected, places=4)
        self.assertAlmostEqual(charged.control - plain.control, WEIGHTS.shock_value * WEIGHTS.illusion_retort_trigger_chance, places=4)

    def test_reflection_is_capped_by_the_illusion_health(self):
        small = score([illusion(health=2, reflect=True)])
        large = score([illusion(health=8, reflect=True)])
        self.assertAlmostEqual(small.offense, 2 * WEIGHTS.damage_per_point * WEIGHTS.illusion_retort_trigger_chance, places=4)
        self.assertAlmostEqual(large.offense, WEIGHTS.illusion_reflect_expected_hit * WEIGHTS.damage_per_point * WEIGHTS.illusion_retort_trigger_chance, places=4)

    def test_ring_scores_the_expected_number_of_illusions(self):
        single = score([illusion(health=2, rng=0)])
        ring = score([illusion(health=2, rng=0, place='ring_around_self')])
        expected = 2 * WEIGHTS.illusion_health_per_point * (WEIGHTS.illusion_ring_expected_tiles - 1.0)
        self.assertAlmostEqual(ring.defense - single.defense, expected, places=4)

    def test_flanking_placement_and_ranged_origin_are_control(self):
        plain = score([illusion()])
        feint = score([illusion(place='adjacent_to_enemy', expose_adjacent=3)])
        self.assertAlmostEqual(feint.control - plain.control, WEIGHTS.illusion_adjacent_placement_value + 3 * WEIGHTS.expose_value_per_point, places=4)
        doppel = score([illusion(ranged_origin=True)])
        self.assertAlmostEqual(doppel.control - plain.control, WEIGHTS.ranged_origin_value, places=4)

    def test_refraction_adds_expected_extra_targets(self):
        shot = {'type': 'ranged', 'damage': 4, 'range': 3, 'element': 'none'}
        plain = score([shot])
        refracted = score([dict(shot, also_hits_near_illusions=True)])
        expected = heuristic.immediate_damage_value(4, heuristic.ranged_playability(3), WEIGHTS.refraction_expected_extra_targets, WEIGHTS)
        self.assertAlmostEqual(refracted.offense - plain.offense, expected, places=4)

    def test_own_illusion_actions_depend_on_an_illusion_being_present(self):
        shatter = score([{'type': 'destroy_illusion', 'range': 6, 'damage': 6}])
        expected = heuristic.immediate_damage_value(6, WEIGHTS.illusion_on_board_availability, WEIGHTS.destroy_illusion_expected_targets, WEIGHTS)
        self.assertAlmostEqual(shatter.offense, expected, places=4)
        swap = score([{'type': 'illusion_swap', 'range': 99, 'transfer_block': True}])
        self.assertGreater(swap.mobility, 0.0)
        self.assertGreater(swap.defense, 0.0)

    def test_terrain_bursts_and_outcrop_kinds(self):
        rockburst = score([{'type': 'burst_terrain', 'range': 3, 'damage': 6}])
        worldbreak = score([{'type': 'burst_terrain', 'range': 1, 'owned_outcrop_only': True, 'line_damage': 6, 'line_length': 3}])
        self.assertGreater(rockburst.offense, 0.0)
        # Needing your own outcrop is rarer than any crate in range.
        self.assertLess(worldbreak.offense / WEIGHTS.burst_line_expected_targets, rockburst.offense / WEIGHTS.burst_terrain_expected_targets)
        plain = score([{'type': 'outcrop', 'range': 2, 'health': 3}])
        keg = score([{'type': 'outcrop', 'range': 2, 'health': 3, 'kind': 'powder_keg', 'burst_damage': 8}])
        self.assertGreater(keg.offense, plain.offense)
        spines = score([{'type': 'outcrop', 'range': 3, 'health': 4, 'pattern': ADJ, 'around_target': True, 'kind': 'worldspine', 'pulse_damage': 3}])
        self.assertAlmostEqual(spines.offense, 3 * WEIGHTS.damage_per_point * WEIGHTS.worldspine_pulse_targets * WEIGHTS.worldspine_expected_pulses, places=4)


if __name__ == '__main__':
    unittest.main()
