import unittest

from tools.atk05 import owner_damage


class HistoricalBleedAttributionTest(unittest.TestCase):
    def test_archived_bleed_riders_explain_movement_loss(self):
        sources = {
            "skitter_strike": "Tunnel Crawler",
            "pelt": "Bone Harrier",
            "razor_dive": "Vaeloryx, the Hollow Gale",
            "grave_dive": "Gallows Roc",
            "lash_of_thorns": "Briar Weaver",
            "talon_rake": "Gust Shrike",
        }
        for intent_id, actor in sources.items():
            for logged_intent in (intent_id, None):
                with self.subTest(intent_id=intent_id, logged_intent=logged_intent):
                    self.assertEqual(self._movement_category(actor, logged_intent), "status")

    def test_current_riders_and_unrelated_attacks_do_not_explain_movement_loss(self):
        self.assertEqual(self._movement_category("Tunnel Crawler", "skitter_strike", current=True), "unknown")
        self.assertEqual(self._movement_category("Tunnel Crawler", "another_attack"), "unknown")

    @staticmethod
    def _movement_category(actor, intent, current=False):
        payload = {"actor_name": actor, "target_losses": [{"key": "player", "amount": 4}]}
        if intent is not None:
            payload["intent_id"] = intent
        if current:
            payload["status_riders_retired"] = True
        previous_round = {"events": [{"event_type": "enemy_action_resolved", "payload": payload}]}
        movement = {"event_type": "player_moved", "payload": {}}
        hero_turn = {
            "hp_before": 12,
            "hp_after": 11,
            "losses": [{"event": movement, "after_move": movement, "amount": 1, "detail": "move"}],
        }
        owner_damage.attribute_hero(hero_turn, previous_round)
        return hero_turn["losses"][0]["category"]


if __name__ == "__main__":
    unittest.main()
