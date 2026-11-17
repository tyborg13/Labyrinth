#!/usr/bin/env python3
"""Exhaustive current-catalog tile-effect inventory, with audited resolver models.

Prints Markdown to stdout. No writes to game data, assets, or tests.
"""
from collections import Counter
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ENEMIES = json.loads((ROOT/'data/enemies.json').read_text())
RULES = json.loads((ROOT/'data/battlefield_rules.json').read_text())['instances']

# Scope includes surface/trail creation, any tile pattern, conduction, force,
# Marked, splash/Burst and battlefield beats. Single-unit damage/status only,
# ordinary summons, heals, buffs and non-trail self movement are excluded.
def scoped(a):
    return (a['type'] in {'aoe','surface','lightning_strikes','terrain_burst','cinder_marks','detonate_cinders','gale_force','umbra_eclipse','chain_discharge','burrow','erupt','icefall_mark','icefall_land','lob_mark','lob_land','upheaval_mark','push','pull','call_wind'}
            or any(k in a for k in ['surface','trail_surface','terminal_surface','push','pull','chain','committed_shape','guardian_shape','snuff_brazier'])
            or a.get('element')=='lightning' and a.get('damage',0)>0)

def location(path, fragment):
    lines=(ROOT/path).read_text().splitlines()
    return f'{path}:{next(i for i,line in enumerate(lines,1) if fragment in line)}'

def intent_location(enemy, intent):
    text=(ROOT/'data/enemies.json').read_text()
    start=text.index(f'  "{enemy}": {{')
    at=text.index(f'"id": "{intent}"',start)
    return f'data/enemies.json:{text[:at].count(chr(10))+1}'

def model(enemy, intent):
    actions=intent['actions']; types={a['type'] for a in actions}
    if intent.get('restore_braziers'):
        return ('Neither','live melee at activation; fixed brazier relight at cleanup','HYBRID: unit-aimed strike plus global relight; no pre-relight footprint','A','Melee rows; explicit braziers-relight-afterward note, including skipped intent.','scripts/guardian_combat_rules.gd:34')
    if enemy=='cinder_ooze' and intent['id']=='cinder_bloom':
        return ('Neither','as it fires around the live Ooze body','HYBRID: body-centered fixed cardinal cross; does not aim at hero; displacement changes origin','A','AoE shape/Fire; no absolute-tile lock or live-origin contract.','scripts/combat_engine.gd:4536')
    if types & {'lob_land','icefall_land'}:
        return ('Locked','when the preceding mark fires; held before this landing is shown','No retarget; held marks survive hero movement','M','Marked location and delayed timing; Lob text states center/arms.','scripts/enemy_mechanics/marked_strike.gd:32')
    if types & {'lob_mark','icefall_mark','burrow'}:
        return ('Follows','as the marking action fires','HYBRID: preview follows current hero; only the resulting mark locks','M','Marked wording gives target/shape and later timing; no explicit “preview follows until marking”.','scripts/enemy_mechanics/marked_strike.gd:32' if 'burrow' not in types else 'scripts/enemy_mechanics/burrow.gd:35')
    if types & {'upheaval_mark'}:
        return ('Neither','as Thornwall fires','HYBRID: current hero-relative wall; later terrain legality can prune it','W','Thornwall/Outcrop shape; no explicit lock/follow timing.','scripts/enemy_mechanics/bramble.gd:47')
    if types & {'erupt'}:
        return ('Neither','hero tile stored when Burrow fires; emergence recomputed when Erupt fires','HYBRID: central mark held, blocked emergence relocates; splash/push from live landing','E','Erupt/neighbor pushes; no exhaustive blocked-tile fallback policy.','scripts/enemy_mechanics/burrow.gd:35')
    if any(a.get('committed_shape') or a.get('guardian_shape') for a in actions):
        connector=any(a.get('guardian_shape')=='connector' for a in actions)
        return ('Neither','when shown: direction/path or connector tiles; footprint rebuilt as it fires','HYBRID: held direction/connector translates to actual arrival after blockers/displacement; live board filters/extends','S' if connector or all(a['type'] in {'move_toward','move_away','surface'} for a in actions) else 'A',
                'Connector note states network extension toward target; not commit/translation timing.' if connector else 'Shape/range/force/surface icons; no held-direction versus live-origin contract.', 'scripts/guardian_combat_rules.gd:95')
    if types & {'terrain_burst','detonate_cinders','umbra_eclipse'}:
        return ('Neither','as it fires, from current owned terrain/Fire or current darkness','HYBRID: preview is a board snapshot; terrain/surfaces/Light can change; compound direct shot re-aims','A','Names/icons identify Burst/Fire/darkness; no fixed-versus-live targeting contract.','scripts/combat_engine.gd:7030')
    if types & {'cinder_marks','lightning_strikes'} and enemy in {'vyraketh','zekarion'}:
        # Both have declaration-time declared_tiles. Skybreak can add live conduction.
        if enemy=='vyraketh' and intent['id']=='kindle_ground':
            return ('Neither','band tiles when shown; direct shot at activation','HYBRID: fixed pressure band plus live-aimed shot; board can change the shot','A','Pressure-band/shot text; mixed locking not stated.','scripts/dragon_combat_rules.gd:56')
        if enemy=='vyraketh':
            return ('Neither','band tiles when shown; melee at activation','HYBRID: live melee plus held band; prior action/board can change victims','A','Melee plus Fire field; mixed locking not stated.','scripts/dragon_combat_rules.gd:56')
        return ('Neither','primary band when shown; conduction as it fires','HYBRID: held primary band; live networks may add remote victims','A','Strike count/Electrified; band selector and live extension not fully stated.','scripts/dragon_combat_rules.gd:56')
    if types & {'chain_discharge'}:
        return ('Neither','first target and jumps recomputed as it fires','HYBRID: nearest unit, not necessarily hero; deaths/positions change later hops','A','Arc Burst rows state nearest target, jumps/falloff; source-specific tooltip loop.','scripts/enemy_mechanics/capacitor.gd:45')
    if types & {'call_wind'}:
        return ('Neither','Call installs direction; rule moves live occupants on later beats','NO TILES before Call; direction/landings become forecast by its rule','G','Call wording states wind and duration; full selector via rule/arrow.','scripts/battlefield_rules/dispatcher.gd:95')
    return ('Follows','start of foe activation; each action resolves on the live board','HYBRID: re-aims after hero/foe movement; live path, orientation, network or force landings','A',
            'Movement/range and effect icons; no explicit “follows” timing. Conduction/force rules require their keyword tooltips.','scripts/combat_engine.gd:9487')

VISIBILITY = {
 'A':'Rest: red planned attack if visible/due; foe hover: same tiles isolated + expanded rows; destination: plan rebuilt there. Later/hit receipts add only known forecast threats.',
 'S':'NO RED footprint for surface-only intent; foe hover: rows + ordinary move ghost, no connector tiles; destination: still no surface threat footprint.',
 'M':'Rest: predicted mark or held landing red (even delayed); foe hover: isolates it; destination: marking follows, held landing stays.',
 'E':'Rest: held central/splash forecast red; foe hover: Erupt footprint; destination: held mark plus board-dependent landing/splash prediction.',
 'W':'Rest/hover/destination: wall preview from current hero; current attack red can differ after earlier board changes.',
 'G':'Rest/destination after installation: arrow + wind ghosts/collision marks; foe hover gives Call text; no all-board red for push paths.'
}

def rows():
    out=[]
    for enemy,data in ENEMIES.items():
        for intent in data.get('intents',[]):
            if not (any(scoped(a) for a in intent['actions']) or intent.get('restore_braziers')): continue
            tag,when,change,view,text,resolver=model(enemy,intent)
            visible=VISIBILITY[view]
            if any(a.get('trail_surface') for a in intent['actions']):visible+=' NO RED footprint for the movement trail; red attack footprint alone does not state the laid trail.'
            if enemy=='lightning_wisp' and intent['id']=='static_lash':visible+=' NO RED footprint for its separate Wisp-centered range-0 surface.'
            if enemy=='slag_mortar' and intent['id']=='lob_slag':change+='; Warband barrage side is saved at declaration, centers/axis follow until marking fires'
            out.append(dict(name=f'{data["name"]} — {intent["name"]} (`{enemy}/{intent["id"]}`)',model=tag,when=when,change=change,view=visible,text=text,source=intent_location(enemy,intent['id'])+'; '+resolver))
        if data.get('death_burst'):
            out.append(dict(name=f'{data["name"]} — Burst (trait)',model='Neither',when='at death, around actual death tile',change='NO TILES: live death location; chains may kill and Burst more units',view='Rest/foe hover: Burst trait icon/text, no persistent death-radius red; destination: only forecast hero-hit receipt when known before next turn.',text='Trait says radius, damage, surface and friendly fire; no exact future death location.',source=location('data/enemies.json',f'"{enemy}":')+'; scripts/enemy_mechanics/death_burst.gd:1'))
    for key,rule in RULES.items():
        kind=rule['rule'];sentence=rule['sentence']
        if kind=='upheaval':
            tag='Neither';when='marks when rule prepares; legality/occupant placement at beat';change='HYBRID: locked marks, but new terrain/connectivity may prune rises; displacement chooses live free tile';view='Rest/destination: due rise marks red; displacement ghosts; foe hover does not add a new footprint.'
        elif kind=='lightning_storm':
            tag='Neither';when='as beat fires: current eligible Electrified plus live Chain/conduction';change='HYBRID: live fuel/occupants; Chain can leave painted primary tiles';view='Rest/destination: due eligible fuel red; known resource-loss receipt adds hero tile, not complete Chain route. Foe hover does not isolate a separate rule move.'
        elif kind=='frostbite':
            tag='Neither';when='as beat fires: current eligible Ice';change='HYBRID: live Ice and occupants; Freeze consumes Ice';view='Rest/destination: due consumed Ice red; rule text/rail; foe hover does not lock the field.'
        elif kind=='wildfire':
            tag='Neither';when='direction when prepared (toward-player mode); current Fire at beat';change='HYBRID: held direction, live fuel; new/removed Fire changes spread';view='Rest/destination: forecast newly caught Fire red when due; foe hover does not freeze spread.'
        elif kind=='gust':
            tag='Neither';when='announced direction; live actor locations and blockers at beat';change='HYBRID: aimed rules can relock after source move; live paths/collisions';view='NO RED area for all shove paths: arrow, landing ghosts and collision marks at rest/destination; known loss may add hero red.'
        else:
            tag='Neither';when='as beat fires: current hidden eligible foes';change='NO STRIKE TILES: live visibility/occupancy and hero-relative Blink destination';view='Rest/destination: anonymous emergence/move ghosts where visible; no damage-area red; rule text/rail.'
        out.append(dict(name=f'Rule `{key}` — {kind}',model=tag,when=when,change=change,view=view,text=sentence,source=location('data/battlefield_rules.json',f'"{key}":')+f'; scripts/battlefield_rules/{kind}.gd:1'))
    return out

def main():
    values=rows();counts=Counter(r['model'] for r in values)
    print(f'Catalog: {len(values)} rows; models: '+', '.join(f'{key} {counts[key]}' for key in ['Locked','Follows','Neither'])+'.')
    print('')
    print('| Move / model | (1) Tiles chosen | (2) Can differ / why | (3) Rest / foe hover / destination | (4) Targeting text | (5) Source |')
    print('|---|---|---|---|---|---|')
    for r in values:
        print('| '+' | '.join(str(x).replace('|','/') .replace('\n',' ') for x in [r['name']+' **'+r['model']+'**',r['when'],r['change'],r['view'],r['text'],r['source']])+' |')
    print('\nNeither list: '+ '; '.join(r['name'] for r in values if r['model']=='Neither')+'.')

if __name__=='__main__':main()
