"""Promote inspected case paint and additive Gaoler-only runtime wiring.
Run only after inspecting --proof's native front/rear cycles. Existing files are
changed with asserted text anchors; no other enemy registration is replaced.
"""
from pathlib import Path
import argparse,json,shutil,hashlib,sys
from PIL import Image
R=Path(__file__).resolve().parents[1];REPO=R.parents[3]
p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,required=True);p.add_argument('--assets-only',action='store_true');args=p.parse_args()
assets=REPO/'assets/units/chainbound_gaoler_cutout';scripts=REPO/'scripts/chainbound_gaoler_cutout'
assets.mkdir(parents=True,exist_ok=True);scripts.mkdir(parents=True,exist_ok=True)
config=json.loads((R/'cutout.json').read_text())
for view,path in config['layouts'].items():
 layout=json.loads((R/path).read_text());folder=assets/view;folder.mkdir(exist_ok=True)
 for part in layout['parts']+layout.get('joint_meshes',[]):
  old=R/part['file'];dest=folder/old.name;shutil.copy2(old,dest);part['file']=view+'/'+dest.name
  dest.with_suffix('.png.import').write_text('[remap]\n\nimporter="keep"\n')
 rest=args.proof/(view+'_rest.png');assert rest.is_file(),rest
 shutil.copy2(rest,folder/'rest.png');(folder/'rest.png.import').write_text('[remap]\n\nimporter="keep"\n')
 layout['rest_source']=view+'/rest.png';layout['rest_source_sha256']=hashlib.sha256(rest.read_bytes()).hexdigest()
 (assets/(view+'.json')).write_text(json.dumps(layout,indent=2)+'\n')
shutil.copy2(R/'motion.gd',scripts/'motion.gd')
for name in ['rig.gd','renderer.gd']:shutil.copy2(R.parent/'runtime_draft'/name,scripts/name)
shutil.copy2(assets/'front/rest.png',REPO/'assets/art/enemies/chainbound_gaoler.png')
# Portrait is a registered crop of the new helmet/upper torso, not another design.
source=Image.open(R/'source/front_registered.png').convert('RGBA');crop=source.crop((94,8,193,118));crop=crop.resize((115,128),Image.Resampling.NEAREST)
portrait=Image.new('RGBA',(128,128));portrait.alpha_composite(crop,(6,0));portrait.save(REPO/'assets/art/portraits/chainbound_gaoler.png')
(REPO/'assets/art/portraits/chainbound_gaoler.png.import').write_text('[remap]\n\nimporter="keep"\n')
(REPO/'assets/art/enemies/chainbound_gaoler.png.import').write_text('[remap]\n\nimporter="keep"\n')
if args.assets_only:
 print("Inspected Gaoler art and motion refreshed");sys.exit(0)
def replace(s,a,b,count=1):
 assert s.count(a)==count,(a[:120],s.count(a),count)
 return s.replace(a,b)
board=REPO/'scripts/combat_board_view.gd';s=board.read_text()
s=replace(s,'var _warden_renderers: Dictionary = {}','var _warden_renderers: Dictionary = {}\nconst GaolerCutout = preload("res://scripts/chainbound_gaoler_cutout/renderer.gd")\nvar _gaoler_renderers: Dictionary = {}')
# The existing Warden lifecycle is retained; Gaoler owns separate instances.
a=s.index('func warden_animation_snapshot(');b=s.index('func _unit_uses_cutout(',a)
helpers=s[a:b].replace('warden','gaoler').replace('Warden','Gaoler').replace('"gaoler"','"chainbound_gaoler"')
a2=s.index('func _sync_warden_renderers()');b2=s.index('func _exit_tree()',a2)
sync=s[a2:b2].replace('warden','gaoler').replace('Warden','Gaoler').replace('"gaoler"','"chainbound_gaoler"')
s=replace(s,'func _exit_tree() -> void:',helpers+sync+'func _exit_tree() -> void:')
s=replace(s,'or str(unit.get("type", "")) == "warden"','or str(unit.get("type", "")) in ["warden", "chainbound_gaoler"]')
s=replace(s,'\t_sync_warden_renderers()','\t_sync_warden_renderers()\n\t_sync_gaoler_renderers()')
s=replace(s,'"_protagonist_renderer", "_warden_renderers",','"_protagonist_renderer", "_warden_renderers", "_gaoler_renderers",')
s=replace(s,'if is_instance_valid(_warden_renderer_for_unit(unit)) else _unit_draw_rect_for_texture','if is_instance_valid(_warden_renderer_for_unit(unit)) or is_instance_valid(_gaoler_renderer_for_unit(unit)) else _unit_draw_rect_for_texture')
s=replace(s,'or is_instance_valid(_warden_renderer_for_unit(unit)):\n\t\treturn Rect2','or is_instance_valid(_warden_renderer_for_unit(unit)) or is_instance_valid(_gaoler_renderer_for_unit(unit)):\n\t\treturn Rect2')
s=replace(s,'\tif unit_type == "warden":\n\t\t_unit_textures', '\tif unit_type == "chainbound_gaoler":\n\t\t_unit_textures[unit_type] = AssetLoader.load_texture_source_first(GaolerCutout.REST_PATH)\n\t\t_queue_unit_shadow_source_data(unit_type)\n\t\treturn\n\tif unit_type == "warden":\n\t\t_unit_textures')
for function in ['_texture_for_unit','_enemy_shadow_dissolve_source_texture']:
 anchor=f'func {function}(unit: Dictionary) -> Texture2D:\n'
 s=replace(s,anchor,anchor+'\tvar gaoler: Node = _gaoler_renderer_for_unit(unit)\n\tif is_instance_valid(gaoler):\n\t\treturn gaoler.call("texture") as Texture2D\n')
board.write_text(s)
run=REPO/'scripts/run_scene.gd';s=run.read_text();s=replace(s,'const WardenCutout = preload("res://scripts/stone_warden_cutout/renderer.gd")','const WardenCutout = preload("res://scripts/stone_warden_cutout/renderer.gd")\nconst GaolerCutout = preload("res://scripts/chainbound_gaoler_cutout/renderer.gd")')
s=replace(s,'\t\t\t\tvar warden_attack: bool = WardenCutout.uses_attack(step, _animation_actor_unit(animated_state, step_actor_key))','\t\t\t\tvar warden_attack: bool = WardenCutout.uses_attack(step, _animation_actor_unit(animated_state, step_actor_key))\n\t\t\t\tvar gaoler_attack: bool = GaolerCutout.uses_attack(step, _animation_actor_unit(animated_state, step_actor_key))')
s=replace(s,'if str(step.get("kind", "")) == "melee" and not warden_attack:','if str(step.get("kind", "")) == "melee" and not warden_attack and not gaoler_attack:')
s=replace(s,'\tvar warden_walk: bool = str(actor_unit.get("type", "")) == "warden"','\tvar warden_walk: bool = str(actor_unit.get("type", "")) == "warden"\n\tvar gaoler_walk: bool = str(actor_unit.get("type", "")) == "chainbound_gaoler"')
s=replace(s,'board_view.warden_source_pixel_scale() if warden_walk else board_view.protagonist_source_pixel_scale()','board_view.gaoler_source_pixel_scale() if gaoler_walk else board_view.warden_source_pixel_scale() if warden_walk else board_view.protagonist_source_pixel_scale()')
anchor='\t\telif warden_walk:\n'
s=replace(s,anchor,'\t\telif gaoler_walk:\n\t\t\tpresentation["gaoler_motion"] = {actor_key: {"clip": "walk", "direction": segment_to - segment_from,\n\t\t\t\t"phase": (distance_before[path_index] + from_point.distance_to(to_point) * t) / source_scale / GaolerCutout.walk_cycle_distance()}}\n'+anchor)
anchor='\tif bool(cutout_effect.get("protagonist_melee", false)):\n'
s=replace(s,anchor,'''\tif not effect_actor_key.is_empty() and GaolerCutout.uses_attack(cutout_effect, _animation_actor_unit(display_state, effect_actor_key)):
		var gaoler_motions: Dictionary = (presentation.get("gaoler_motion", {}) as Dictionary).duplicate(false)
		gaoler_motions[effect_actor_key] = {"clip": "attack", "action": GaolerCutout.action_clip(cutout_effect),
			"phase": float(presentation.get("effect_progress", 1.0)),
			"direction": (cutout_effect.get("to", Vector2i.ZERO) as Vector2i) - (cutout_effect.get("from", Vector2i.ZERO) as Vector2i)}
		rendered_presentation["gaoler_motion"] = gaoler_motions
'''+anchor)
run.write_text(s)
data=REPO/'data/enemies.json';d=json.loads(data.read_text());e=d['chainbound_gaoler'];e['art_path']='res://assets/units/chainbound_gaoler_cutout/front/rest.png'
for key in ['idle_sheet_columns','idle_sheet_rows','idle_sheet_order','idle_sheet_ping_pong']:e.pop(key,None)
data.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n')
export=REPO/'export_presets.cfg';s=export.read_text();s=replace(s,'assets/units/stone_warden_cutout/*.json','assets/units/stone_warden_cutout/*.json,assets/units/chainbound_gaoler_cutout/*.json',3);export.write_text(s)
tests=REPO/'tests/run_tests.gd';s=tests.read_text();anchor='\tawait preload("res://tests/suites/stone_warden_cutout_suite.gd").run(self, Callable(self, "_assert"))';s=replace(s,anchor,anchor+'\n\tawait preload("res://tests/suites/chainbound_gaoler_cutout_suite.gd").run(self, Callable(self, "_assert"))');tests.write_text(s)
print('Gaoler production closure and small additive runtime registrations installed')
