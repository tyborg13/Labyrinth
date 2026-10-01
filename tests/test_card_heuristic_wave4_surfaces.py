"""Scoring of the wave-4 surface family (spec/card_mechanics_surfaces.md)."""
import importlib.util
import sys
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('wave4_surface_heuristic', Path(__file__).resolve().parents[1] / 'tools/card_heuristic.py')
heuristic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = heuristic
SPEC.loader.exec_module(heuristic)

WEIGHTS = heuristic.HeuristicWeights()
CROSS = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]]
LINE3 = [[0, 0], [1, 0], [2, 0]]


def score(actions, **card):
    card = dict(card)
    card.setdefault('time', 5)
    card['actions'] = actions
    return heuristic.score_card('wave4_case', card, WEIGHTS)


def ranged(damage, rng=3, **extra):
    action = {'type': 'ranged', 'damage': damage, 'range': rng, 'element': 'none'}
    action.update(extra)
    return action


class Wave4SurfaceHeuristicTests(unittest.TestCase):
    def test_adjacent_surface_uses_expected_adjacent_tiles(self):
        ward = score([{'type': 'surface_adjacent_enemies', 'surface': 'fire'}])
        self.assertAlmostEqual(ward.surfaces, WEIGHTS.surface_fire_per_tile * WEIGHTS.adjacent_enemies_expected, places=4)
        with_self = score([{'type': 'surface_adjacent_enemies', 'surface': 'fire', 'include_self': True}])
        self.assertGreater(with_self.surfaces, ward.surfaces)

    def test_consume_bonus_is_conditional_and_pays_fuel(self):
        plain = score([ranged(9)])
        consuming = score([ranged(9, consume={'surface': 'fire', 'bonus_damage': 6})])
        bigger = score([ranged(15)])
        self.assertGreater(consuming.offense, plain.offense)
        self.assertLess(consuming.offense, bigger.offense)
        self.assertGreater(consuming.surface_fuel_cost, 0.0)

    def test_required_consume_scales_the_whole_attack(self):
        plain = score([ranged(6)])
        required = score([ranged(6, consume={'surface': 'ice', 'required': True})])
        self.assertAlmostEqual(required.offense, plain.offense * WEIGHTS.surface_setup_availability, places=4)

    def test_spare_player_removes_shared_hazard_cost(self):
        blast = {'type': 'detonate', 'damage': 7, 'range': 0, 'pattern': CROSS, 'element': 'fire'}
        spared = dict(blast, spare_player=True)
        self.assertLess(score([spared]).surface_fuel_cost, score([blast]).surface_fuel_cost)

    def test_rubble_detonate_leaving_fire_adds_surface_value(self):
        vent = score([{'type': 'detonate', 'damage': 5, 'range': 3, 'pattern': [[0, 0]], 'detonate_surface': 'rubble', 'leave_surface': 'fire'}])
        self.assertGreater(vent.surfaces, 0.0)

    def test_per_tile_reward_uses_expected_tiles_and_cap(self):
        action = {'type': 'consume_surface', 'surface': 'electrified', 'target': 'player', 'pattern': CROSS, 'min_consumed': 1}
        per_tile = score([dict(action, rewards=[{'type': 'stoneskin', 'amount': 2, 'per_tile': True, 'max': 8}])])
        flat = score([dict(action, rewards=[{'type': 'stoneskin', 'amount': 2}])])
        self.assertGreater(per_tile.defense, flat.defense)
        capped = score([dict(action, rewards=[{'type': 'stoneskin', 'amount': 6, 'per_tile': True, 'max': 8}])])
        uncapped = score([dict(action, rewards=[{'type': 'stoneskin', 'amount': 6, 'per_tile': True}])])
        self.assertLess(capped.defense, uncapped.defense)

    def test_on_result_reward_is_discounted_by_availability(self):
        plain = score([ranged(5, element='ice')])
        rewarded = score([ranged(5, element='ice', on_result={'when': 'froze', 'rewards': [{'type': 'draw', 'amount': 2}]})])
        self.assertGreater(rewarded.flow, plain.flow)
        self.assertLess(rewarded.flow - plain.flow, 2 * WEIGHTS.draw_per_point)

    def test_selector_strike_is_targetless_and_white_silence_freezes(self):
        stoke = score([{'type': 'all_enemies', 'selector': 'on_fire', 'damage': 3, 'element': 'fire'}])
        self.assertGreater(stoke.offense, 0.0)
        silence = score([{'type': 'all_enemies', 'selector': 'chilled', 'damage': 4, 'element': 'ice'}])
        self.assertAlmostEqual(silence.control, WEIGHTS.freeze_value * WEIGHTS.selector_chilled_targets, places=4)
        ranged_glare = score([{'type': 'all_enemies', 'selector': 'in_light', 'range': 4, 'damage': 0, 'expose': 3}])
        self.assertAlmostEqual(ranged_glare.control, 3 * WEIGHTS.expose_value_per_point * WEIGHTS.selector_in_light_targets * WEIGHTS.selector_range_factor, places=4)

    def test_ignore_los_raises_playability_only(self):
        self.assertGreater(score([ranged(5, rng=4, ignore_los=True)]).offense, score([ranged(5, rng=4)]).offense)

    def test_meteor_marks_score_delayed_damage_and_surface(self):
        meteor = score([{'type': 'meteor_marks', 'range': 4, 'pattern': LINE3, 'rotate': True, 'damage': 8, 'surface': 'fire', 'element': 'fire'}])
        instant = score([{'type': 'aoe', 'range': 4, 'pattern': LINE3, 'rotate': True, 'damage': 8, 'element': 'fire'}])
        self.assertGreater(meteor.surfaces, 0.0)
        self.assertLess(meteor.offense, instant.offense)

    def test_convert_and_discharge_need_their_setup(self):
        convert = score([{'type': 'convert_surface', 'range': 3, 'surface': 'ice', 'to': 'electrified', 'connected': True, 'damage': 2, 'element': 'lightning', 'shock': 1}])
        painted = score([{'type': 'surface', 'surface': 'ice', 'range': 3, 'pattern': LINE3}, {'type': 'convert_surface', 'range': 3, 'surface': 'ice', 'to': 'electrified', 'connected': True, 'damage': 2, 'element': 'lightning', 'shock': 1}])
        self.assertGreater(painted.control, convert.control)
        discharge = score([{'type': 'discharge', 'range': 4, 'damage': 4, 'element': 'lightning'}])
        self.assertGreater(discharge.offense, 0.0)
        self.assertGreater(discharge.surface_fuel_cost, 0.0)


if __name__ == '__main__':
    unittest.main()
