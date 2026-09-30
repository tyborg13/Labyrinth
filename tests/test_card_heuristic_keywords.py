"""Scoring of Stagger, Follow-up, Empower, state and scale bonuses (spec/card_keywords.md)."""
import importlib.util
import sys
import unittest
from pathlib import Path

SPEC = importlib.util.spec_from_file_location('keyword_heuristic', Path(__file__).resolve().parents[1] / 'tools/card_heuristic.py')
heuristic = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = heuristic
SPEC.loader.exec_module(heuristic)

WEIGHTS = heuristic.HeuristicWeights()


def melee(damage, **extra):
    action = {'type': 'melee', 'damage': damage, 'range': 1, 'element': 'none'}
    action.update(extra)
    return action


def score(actions, **card):
    card = dict(card)
    card.setdefault('time', 5)
    card['actions'] = actions
    return heuristic.score_card('keyword_case', card, WEIGHTS)


class KeywordHeuristicTests(unittest.TestCase):
    def test_stagger_is_priced_per_point_by_playability_and_targets(self):
        plain = score([melee(6)])
        staggered = score([melee(6, stagger=3)])
        expected = 3 * WEIGHTS.stagger_value_per_point * heuristic.melee_playability(1)
        self.assertAlmostEqual(staggered.control - plain.control, expected, places=4)

    def test_follow_up_adds_share_of_the_bonus_score(self):
        base = score([melee(6)])
        boosted = score([melee(9)])
        follow = score([melee(6)], follow_up={'mods': [{'action': 0, 'add': {'damage': 3}}]})
        self.assertAlmostEqual(follow.follow_up, WEIGHTS.follow_up_bonus_share * (boosted.total - base.total), places=3)
        self.assertAlmostEqual(follow.total, base.total + follow.follow_up, places=3)

    def test_empower_subtracts_its_cost_before_the_share(self):
        base = score([melee(12)])
        boosted = score([melee(20, pierce=True)])
        empowered = score([melee(12)], empower={'cost': {'health': 2}, 'mods': [{'action': 0, 'add': {'damage': 8}, 'set': {'pierce': True}}]})
        expected = WEIGHTS.empower_bonus_share * max(0.0, boosted.total - base.total - 2 * WEIGHTS.empower_health_cost_per_point)
        self.assertAlmostEqual(empowered.empower, expected, places=3)
        cheap = score([{'type': 'draw', 'amount': 1}], empower={'cost': {'time': 1}, 'mods': [{'action': 0, 'set': {'amount': 2}}]})
        self.assertAlmostEqual(cheap.empower, WEIGHTS.empower_bonus_share * (WEIGHTS.draw_per_point - WEIGHTS.empower_time_cost_per_point), places=3)
        overpriced = score([{'type': 'draw', 'amount': 1}], empower={'cost': {'time': 2}, 'mods': [{'action': 0, 'set': {'amount': 2}}]})
        self.assertEqual(overpriced.empower, 0.0)
        exhaust = heuristic.empower_cost_value({'exhaust': True}, WEIGHTS)
        self.assertAlmostEqual(exhaust, WEIGHTS.empower_exhaust_cost)

    def test_conditional_state_bonus_is_worth_less_than_printed_damage(self):
        base = score([melee(10)])
        conditional = score([melee(10, state_bonus=[{'state': 'half_hp', 'damage': 5}])])
        printed = score([melee(15)])
        self.assertGreater(conditional.offense, base.offense)
        self.assertLess(conditional.offense, printed.offense)

    def test_scale_bonus_uses_expected_points_capped_at_max(self):
        stonefist = score([melee(5, scale_bonus={'per': 'stoneskin', 'damage': 1, 'max': 6})])
        self.assertGreater(stonefist.offense, score([melee(5)]).offense)
        wheel = score([{'type': 'move', 'range': 3}, melee(4, required=True, scale_bonus={'per': 'tiles_moved', 'damage': 1, 'max': 5})])
        lance = score([melee(4, scale_bonus={'per': 'tiles_moved', 'damage': 1, 'max': 5})])
        self.assertGreater(wheel.offense, lance.offense)
        self.assertEqual(heuristic.expected_scale_bonus({'per': 'tiles_moved', 'damage': 1, 'max': 5}, 10, WEIGHTS), 5)


if __name__ == '__main__':
    unittest.main()
