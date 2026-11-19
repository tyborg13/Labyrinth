"""el-02 consumes the binding owner table and approved icon/copy assets."""
import json
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]

AREA_02_UPHEAVAL_SENTENCES = {
    'Warband · The Thornmother': (
        'After every second Thornmother turn, its marked tiles rise as Outcrops.'
    ),
    'Umbral Snare · earth': (
        'After each of your turns, a marked tile on your way out rises as an Outcrop.'
    ),
}

class ElementRuleContractTest(unittest.TestCase):
    def test_panel_sentences_match_binding_owner_table(self):
        design = (ROOT / 'spec/peer_benchmark/element_rules/design.md').read_text()
        rows = [line.split('|') for line in design.splitlines() if line.startswith('| Warband ·') or line.startswith('| Umbral Snare ·')]
        data = json.loads((ROOT / 'data/special_encounters.json').read_text())['types']
        rules = json.loads((ROOT / 'data/battlefield_rules.json').read_text())['instances']
        by_fight = {row[1].strip(): (row[2].strip(), row[-2].strip()) for row in rows}
        self.assertEqual(len(by_fight), 12)
        for cohort, field, fight in [('warband', 'order', 'Warband'), ('umbral_snare', 'pressure', 'Umbral Snare')]:
            for biome, variant in data[cohort]['variants'].items():
                with self.subTest(cohort=cohort, biome=biome):
                    title = f"{fight} · {variant['title'] if cohort == 'warband' else biome}"
                    rule, sentence = by_fight[title]
                    instance = rules[variant[field]['battlefield_instance']]
                    # Area-02 supersedes these two panel sentences.
                    if title not in AREA_02_UPHEAVAL_SENTENCES:
                        self.assertEqual(variant[field]['text'], sentence)
                    self.assertEqual(instance['sentence'], AREA_02_UPHEAVAL_SENTENCES.get(title, sentence))
                    self.assertEqual(instance['rule'], rule)

    def test_retired_keywords_and_inert_dial_are_absent(self):
        glossary = json.loads((ROOT / 'data/glossary.json').read_text())
        self.assertFalse({'bramble', 'ice_pillar', 'tether'} & {e['id'] for e in glossary})
        for e in glossary:
            self.assertNotRegex(e['definition'], r'\b(?:Bramble|Ice Pillars?|Tether)\b')
        rules = json.loads((ROOT / 'data/battlefield_rules.json').read_text())
        self.assertNotIn('lasting', json.dumps(rules))
        self.assertNotIn('lasting', (ROOT / 'scripts/battlefield_rules/wildfire.gd').read_text())
        enemies = json.loads((ROOT / 'data/enemies.json').read_text())
        for enemy in ('briar_weaver', 'hoarfrost_seer', 'arc_thrall'):
            for intent in enemies[enemy]['intents']:
                for action in intent['actions']:
                    self.assertNotIn(action['type'], ('grow_bramble', 'tether_beam'))
                    self.assertNotIn(action.get('terrain'), ('bramble', 'ice_pillar'))

if __name__ == '__main__':
    unittest.main(verbosity=2)
