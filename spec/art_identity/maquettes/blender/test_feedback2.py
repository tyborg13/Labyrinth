"""Adversarial final-fit, native-surface and footprint regressions for mq-05."""
from copy import deepcopy
import json
from pathlib import Path
import shutil
import tempfile
from types import SimpleNamespace as NS
import unittest

from .compile_recipe import compile_recipe
from .contract import digest
from .curate_delivery import verify
from .delivery_validation import validate_delivery, seal_delivery
from .sculpted_mass import native_stack_matches, frozen_differs_from_base
from .solid_fit import compute_fit

ROOT=Path(__file__).resolve().parents[1]
FIGURES=('burrow_grub','ember_tick','glacial_mirror')
FEEDBACK_TEST_DEFAULTS={'image_size_px':(8,8),'image_rgba':(80,90,100,255),
    'base_vertex':[0.,0.,0.],'surface_change_m':.01,'forged_iou_delta':.001,
    'projection_offset_m':3.,'stale_sha256':'0'*64}


class FeedbackTwoTests(unittest.TestCase):
    def spec(self,name):return compile_recipe(json.loads((ROOT/name/'measurements.json').read_text()))

    def copied(self,name,temporary):
        folder=Path(temporary)/name
        shutil.copytree(ROOT/name,folder,ignore=shutil.ignore_patterns('proof','spec_native.json','__pycache__'))
        # Build a complete valid fixture inventory before any report mutation.
        # Generated blends/proof are excluded; final real curation runs separately.
        names=sorted(str(p.relative_to(folder)) for p in folder.rglob('*') if p.is_file())
        (folder/'COMMIT_MANIFEST.txt').write_text('\n'.join(names)+'\n')
        return folder

    def test_failed_zero_stale_and_forged_fit_rejected_for_every_figure(self):
        for name in FIGURES:
            with tempfile.TemporaryDirectory() as temporary:
                folder=self.copied(name,temporary);spec=self.spec(name)
                validate_delivery(spec,folder/'delivery')
                verify(folder)
                path=folder/'delivery/fit_report.json';before=path.read_bytes()
                for mutation in ('missing','failed','zero','stale_spec','stale_capture','forged_iou'):
                    data=json.loads(before)
                    if mutation=='failed':data['passed']=False
                    elif mutation=='zero':data['views']['front']['iou']=0
                    elif mutation=='stale_spec':data['spec_hash']=FEEDBACK_TEST_DEFAULTS['stale_sha256']
                    elif mutation=='stale_capture':data['input_sha256']['native_render_manifest']=FEEDBACK_TEST_DEFAULTS['stale_sha256']
                    elif mutation=='forged_iou':data['views']['rear']['iou']+=FEEDBACK_TEST_DEFAULTS['forged_iou_delta']
                    path.write_text(json.dumps(data))
                    if mutation=='missing':path.unlink()
                    for operation in (lambda:validate_delivery(spec,folder/'delivery',require_binding=False),
                                      lambda:seal_delivery(spec,folder/'delivery'),lambda:verify(folder)):
                        with self.subTest(figure=name,mutation=mutation),self.assertRaises(ValueError):operation()
                    path.write_bytes(before)

    def test_native_contacts_and_sculpted_sections_cannot_be_omitted(self):
        for name,key in (('glacial_mirror','native_contacts'),('burrow_grub','native_sculpted_sections'),('ember_tick','native_sculpted_sections')):
            with tempfile.TemporaryDirectory() as temporary:
                folder=self.copied(name,temporary);spec=self.spec(name)
                for filename,field in (('build_report.json','checks'),('capture_checks.json','geometry_checks')):
                    path=folder/'delivery'/filename;data=json.loads(path.read_text());del data[field][key]
                    path.write_text(json.dumps(data))
                with self.subTest(figure=name,key=key),self.assertRaises(ValueError):
                    validate_delivery(spec,folder/'delivery',require_binding=False)

    def test_every_required_modifier_must_evaluate_in_both_modes(self):
        piece=self.spec('glacial_mirror')['pieces'][0]
        mods=[NS(name='rounded_mass_subdivision',type='SUBSURF',levels=piece['subdivision_levels'],render_levels=piece['subdivision_levels']),
              NS(name='modelled_surface_relief',type='DISPLACE',strength=piece['relief']['strength']),
              NS(name='modelled_chipped_bevel',type='BEVEL',width=piece['bevel']['width'],segments=piece['bevel']['segments'])]
        mods += [NS(name='modelled_fracture_'+str(i),type='BOOLEAN',operation='DIFFERENCE',solver='EXACT',object=object()) for i in range(len(piece.get('fractures',[])))]
        for mod in mods:mod.show_viewport=mod.show_render=True
        source=NS(modifiers=mods,get=lambda key:key=='modelled_profile')
        self.assertTrue(native_stack_matches(piece,source))
        for mod in mods:
            for field in ('show_viewport','show_render'):
                setattr(mod,field,False)
                with self.subTest(modifier=mod.name,mode=field):self.assertFalse(native_stack_matches(piece,source))
                setattr(mod,field,True)

    def test_frozen_surface_must_differ_from_base_mesh(self):
        mesh=NS(data=NS(vertices=[NS(co=FEEDBACK_TEST_DEFAULTS['base_vertex'].copy())],polygons=[NS(vertices=[0])]))
        self.assertFalse(frozen_differs_from_base(mesh,deepcopy(mesh)))
        changed=deepcopy(mesh);changed.data.vertices[0].co[2]=FEEDBACK_TEST_DEFAULTS['surface_change_m']
        self.assertTrue(frozen_differs_from_base(mesh,changed))
        self.assertFalse(frozen_differs_from_base(mesh,None))

    def test_each_foot_rejects_unpainted_projection_and_wrong_height(self):
        from PIL import Image
        from .compile_recipe import PROJECT
        from .foot_projection import report
        spec=self.spec('ember_tick')
        recipe=json.loads((ROOT/'ember_tick/measurements.json').read_text())
        views=json.loads((ROOT/'ember_tick/delivery/fit_report.json').read_text())['views']
        sources={v:Image.open(PROJECT/recipe['sources'][v]).convert('RGBA') for v in views}
        self.assertTrue(report(spec,views,sources)['passed'])
        for name in spec['foot_contacts']['pieces']:
            for mutation in ('height','projection'):
                changed=deepcopy(spec);piece=next(p for p in changed['pieces'] if p['id']==name)
                if mutation=='height':
                    # Both views still project inside the painted shell: this
                    # isolates height rejection from the footprint predicate.
                    piece['path'][-1]=next(p['centre'].copy() for p in spec['pieces'] if p['id']=='shell')
                else:piece['path'][-1][0]+=FEEDBACK_TEST_DEFAULTS['projection_offset_m']
                result=report(changed,views,sources)
                with self.subTest(foot=name,mutation=mutation):
                    self.assertFalse(result['passed'])
                    if mutation=='height':
                        self.assertGreater(result['feet'][name]['ground_error_m'],.05)
                        self.assertTrue(all(v['distance_px']<=2 for v in result['feet'][name]['views'].values()))
                    else:self.assertTrue(any(v['distance_px']>2 for v in result['feet'][name]['views'].values()))

    def test_native_spec_regeneration_requires_both_clays_and_maps(self):
        from unittest.mock import patch
        from . import regenerate_delivery as runner
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);figure=root/'native_fixture';figure.mkdir()
            spec_path=figure/'approved_spec.json'
            spec_path.write_bytes((ROOT/'frostglass_lancer/spec_r3.json').read_bytes())
            reference=figure/'reference';reference.mkdir()
            from PIL import Image
            for view in ('front','rear'):
                for kind in ('clay','parts'):Image.new('RGBA',FEEDBACK_TEST_DEFAULTS['image_size_px'],FEEDBACK_TEST_DEFAULTS['image_rgba']).save(reference/(view+'_'+kind+'.png'))
            bundle=root/'bundle.fixture';bundle.write_text('test-only bundle hash input')
            def native(script,values,**kwargs):
                capture=Path(values[1]);capture.mkdir()
                for directory in (reference,parts):
                    for path in directory.glob('*.png'):shutil.copyfile(path,capture/path.name)
                return {'stdout':'fixture build','exit':0,'seconds':0,'id':'test-only'}
            parts=root/'part_reference';parts.mkdir()
            for view in ('front','rear'):
                name=view+'_parts.png'
                shutil.copyfile(reference/name,parts/name);(reference/name).unlink()
            output=root/'out'
            argv=['regenerate_delivery',str(figure),'--spec-input',str(spec_path),'--reference',str(reference),
                  '--reference-parts',str(parts),'--preview','--verify','--discard-build','--out',str(output)]
            with patch('sys.argv',argv),patch.object(runner,'run_job',side_effect=native),patch.object(runner,'DEFAULT_BUNDLE',str(bundle)):
                self.assertEqual(runner.main(),0)
            report=json.loads((output/'regeneration.json').read_text())
            self.assertTrue(report['passed'] and report['comparison_required'])
            self.assertEqual(set(report['views']),{'front','rear'})
            self.assertTrue(all(set(v)=={'clay','parts'} for v in report['views'].values()))
            self.assertEqual(report['compiled_spec_hash'],digest(json.loads(spec_path.read_text())))
            self.assertFalse((output/'clean_project').exists())
            self.assertTrue((output/'clean_input_sha256.json').is_file())

    def test_all_tick_contacts_match_paint_and_the_ground_plane(self):
        result,_=compute_fit(ROOT/'ember_tick')
        contacts=result['contacts'];self.assertEqual(len(contacts['feet']),8)
        self.assertTrue(contacts['passed'],contacts)
        self.assertFalse(self.spec('ember_tick')['foot_contacts']['exceptions'])
        for foot in contacts['feet'].values():
            self.assertLessEqual(foot['ground_error_m'],.05)
            for view in foot['views'].values():self.assertLessEqual(view['distance_px'],2.)
        native=json.loads((ROOT/'ember_tick/delivery/build_report.json').read_text())
        self.assertEqual(len(native['geometry_details']['native_contacts']['feet']),8)
        self.assertTrue(native['checks']['native_contacts'])
        for foot in native['geometry_details']['native_contacts']['feet'].values():
            self.assertTrue(foot['passed'])
            self.assertLessEqual(foot['ground_error_m'],.05)


if __name__=='__main__':unittest.main()
