"""Sound-lab behavioral proof. All recordings are synthetic, temporary fixtures."""
from __future__ import annotations

import argparse
import copy
from html.parser import HTMLParser
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.sfx_lab.common import (LabError, TakeLibrary, decode, encode, fade_in, fade_out,
    read_json, safe_path, sha256, write_json, write_jsonl, workers, SHORT_PEAK_TARGETS,
    FADE_IN_MS, FADE_CURVE)
from tools.sfx_lab.index import create_index, query
from tools.sfx_lab.slice import create_slices, slice_audio
from tools.sfx_lab.features import create_features, measure
from tools.sfx_lab.audition import audition, PAGE_SCRIPT, PAGE_TITLE, AUDITION_CSS, KEYBOARD_SHORTCUTS
from tools.sfx_lab.build import build, process, CATEGORY_TARGETS, choose_channels, crossfade_loop
import numpy as np
import soundfile as sf


# Debug-only proof defaults, not production design or approved cue choices.
FIXTURE_RATE = 48000
FIXTURE_RANDOM_SEED = 19012
FIXTURE_DESIGN = {}  # Production decisions are now supplied by approved constants.
FIXTURE_STEREO_SIDE_RATIOS = [0.249, 0.25, 0.251]
PROOF_OUT: Path | None = None


def sine(seconds: float, frequency: float = 1000, amplitude: float = 0.2) -> np.ndarray:
    return (amplitude * np.sin(2 * np.pi * frequency * np.arange(round(seconds * FIXTURE_RATE))
                              / FIXTURE_RATE))[:, None]


class PageParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.audio = []
        self.radios = []
        self.data = ""
        self.reading_data = False
        self.waveforms = []

    def handle_starttag(self, tag, attrs):
        value = dict(attrs)
        if tag == "audio":
            self.audio.append(value)
        if tag == "input" and value.get("type") == "radio":
            self.radios.append(value)
        if tag == "polyline":
            self.waveforms.append(value)
        if tag == "script" and value.get("id") == "page-data":
            self.reading_data = True

    def handle_data(self, data):
        if self.reading_data:
            self.data += data

    def handle_endtag(self, tag):
        if tag == "script":
            self.reading_data = False


class SfxLabTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix="sfx-lab-tests-")
        cls.root = Path(cls.temporary.name)
        cls.sources = cls.root / "sources"
        for source in ("kenney", "sonniss_gdc", "opengameart"):
            folder = cls.sources / source
            folder.mkdir(parents=True)
            (folder / "LICENSE.txt").write_text("Synthetic test licence record\n")
        sf.write(cls.sources / "kenney/tone.wav", sine(3), FIXTURE_RATE, subtype="PCM_24")
        sf.write(cls.sources / "kenney/tiny.wav", sine(0.02), FIXTURE_RATE)
        sf.write(cls.sources / "kenney/short.wav", sine(0.09), FIXTURE_RATE)
        bursts = np.zeros((round(1.4 * FIXTURE_RATE), 1))
        bursts[round(.1 * FIXTURE_RATE):round(.25 * FIXTURE_RATE)] = sine(.15)
        bursts[round(.65 * FIXTURE_RATE):round(.9 * FIXTURE_RATE)] = sine(.25, frequency=2000)
        sf.write(cls.sources / "sonniss_gdc/takes.wav", bursts, FIXTURE_RATE)
        sf.write(cls.sources / "opengameart/tone.flac", sine(.7, frequency=200), FIXTURE_RATE)
        sf.write(cls.sources / "opengameart/tone.ogg", sine(.8, frequency=6000), FIXTURE_RATE)
        encode(cls.sources / "kenney/tone.mp3", sine(.8), FIXTURE_RATE, "mp3")
        hidden = cls.sources / "kenney/__MACOSX"
        hidden.mkdir()
        sf.write(hidden / "ignored.wav", sine(.5), FIXTURE_RATE)
        (cls.sources / "kenney/.DS_Store").write_bytes(b"ignored")
        cls.analysis = cls.root / "analysis"
        cls.index = cls.analysis / "index.json"
        cls.takes = cls.analysis / "takes.jsonl"
        cls.features = cls.analysis / "features.jsonl"
        cls.catalogue = create_index(cls.sources, cls.index, 4)
        cls.slices = create_slices(cls.index, cls.takes, 4)
        cls.rows = create_features(cls.index, cls.takes, cls.features, 4)
        cls.long = next(row for row in cls.rows if row["source_path"] == "kenney/tone.wav")
        cls.short = next(row for row in cls.rows if row["source_path"] == "kenney/short.wav")

    @classmethod
    def tearDownClass(cls):
        cls.temporary.cleanup()

    def write(self, name: str, value) -> Path:
        path = self.root / name
        write_json(path, value)
        return path

    def test_index_all_formats_license_hash_and_skips(self):
        files = self.catalogue["files"]
        self.assertEqual(6, len(files))
        self.assertEqual({".wav", ".flac", ".ogg", ".mp3"}, {Path(row["source_path"]).suffix for row in files})
        for row in files:
            self.assertEqual(sha256(self.sources / row["source_path"]), row["sha256"])
            self.assertGreaterEqual(row["duration"], .03)
            self.assertIn(row["licence_id"], {"CC0-1.0", "Sonniss GDC Bundle licence"})
        self.assertEqual(24, next(row["bit_depth"] for row in files if row["source_path"] == "kenney/tone.wav"))

    def test_index_and_analysis_deterministic_across_workers(self):
        index_bytes = self.index.read_bytes()
        create_index(self.sources, self.index, 1)
        self.assertEqual(index_bytes, self.index.read_bytes())
        takes = self.takes.read_bytes()
        create_slices(self.index, self.takes, 1)
        self.assertEqual(takes, self.takes.read_bytes())
        features = self.features.read_bytes()
        create_features(self.index, self.takes, self.features, 1)
        self.assertEqual(features, self.features.read_bytes())

    def test_slice_boundaries_and_identity(self):
        rows = [row for row in self.slices if row["source_path"] == "sonniss_gdc/takes.wav"]
        self.assertEqual(2, len(rows))
        for row, expected in zip(rows, [(0.1, .37), (.65, 1.02)]):
            self.assertAlmostEqual(expected[0], row["start_seconds"], places=3)
            self.assertAlmostEqual(expected[1], row["end_seconds"], places=3)
        self.assertTrue(rows[0]["take_id"].endswith("#1"))
        self.assertTrue(rows[1]["take_id"].endswith("#2"))
        self.assertEqual(rows[0]["source_sha256"][:12], rows[0]["take_id"].split("#")[0])
        self.assertEqual(1, len([row for row in self.slices if row["source_path"] == "kenney/tone.wav"]))

    def test_slice_silence_tiny_take_tail_floor_and_cap(self):
        self.assertEqual([], slice_audio(np.zeros((FIXTURE_RATE, 1)), FIXTURE_RATE))
        self.assertEqual([], slice_audio(sine(.02), FIXTURE_RATE))
        self.assertEqual([], slice_audio(sine(.035), FIXTURE_RATE))
        # A -55 dBFS tail is below the main gate but above the tail floor.
        tail = sine(5, amplitude=10 ** (-55 / 20))
        data = np.concatenate([sine(.1), tail, np.zeros((FIXTURE_RATE, 1))])
        result = slice_audio(data, FIXTURE_RATE)
        self.assertEqual(1, len(result))
        self.assertAlmostEqual(4.1, result[0][1], delta=.02)
        data = np.concatenate([sine(.1), tail[:round(.3 * FIXTURE_RATE)],
                               np.zeros((FIXTURE_RATE, 1))])
        self.assertAlmostEqual(.4, slice_audio(data, FIXTURE_RATE)[0][1], delta=.02)

    def test_features_sine_noise_bands_and_short_rms(self):
        tone = measure(sine(1), FIXTURE_RATE)
        self.assertAlmostEqual(1000, tone["centroid_hz"], delta=10)
        self.assertGreater(tone["tonality"], 100)
        self.assertAlmostEqual(20 * np.log10(.2), tone["peak_dbfs"], places=4)
        self.assertEqual(64, len(tone["envelope"]))
        noise = np.random.default_rng(FIXTURE_RANDOM_SEED).normal(0, .05, (FIXTURE_RATE, 1))
        self.assertGreater(measure(noise, FIXTURE_RATE)["tonality"], 1)
        self.assertLess(measure(noise, FIXTURE_RATE)["tonality"], 3)
        self.assertGreater(measure(sine(1, 100), FIXTURE_RATE)["low_band_ratio"], .95)
        self.assertGreater(measure(sine(1, 6000), FIXTURE_RATE)["high_band_ratio"], .95)
        short = measure(sine(.1), FIXTURE_RATE)
        self.assertEqual("short_rms_dbfs", short["loudness_method"])
        self.assertAlmostEqual(20 * np.log10(.2 / np.sqrt(2)), short["lufs"], places=4)
        silence = measure(np.zeros((FIXTURE_RATE, 1)), FIXTURE_RATE)
        self.assertIsNone(silence["lufs"])
        json.dumps(silence, allow_nan=False)

    def test_attack_decay_and_antiphase_spectrum(self):
        gain = np.concatenate((np.linspace(0, 1, 4800), np.exp(-np.arange(19200) / 3000)))
        data = sine(.5) * gain[:, None]
        row = measure(data, FIXTURE_RATE)
        self.assertGreater(row["attack_seconds"], .05)
        self.assertLess(row["attack_seconds"], .11)
        self.assertGreater(row["decay_seconds"], .15)
        stereo = np.concatenate([sine(1), -sine(1)], axis=1)
        self.assertAlmostEqual(1000, measure(stereo, FIXTURE_RATE)["centroid_hz"], delta=10)

    def test_query_all_ranges_and_sort(self):
        result = query(self.rows, {"duration": [.5, 4], "centroid_hz": [900, 1100],
                                  "low_band_ratio": [0, .01], "attack_seconds": [0, .1],
                                  "lufs": [-40, 0]}, substring="KENNEY", regex=r"tone\.(wav|mp3)$",
                       sort="duration", descending=True)
        self.assertEqual("kenney/tone.wav", result[0]["source_path"])
        self.assertEqual(2, len(result))
        self.assertEqual([], query(self.rows, {"decay_seconds": [100, 200]}))
        with self.assertRaises(LabError):
            query(self.rows, {}, regex="[")

    def test_audition_two_cues_html_audio_and_provenance(self):
        picks = {"cue_one": {"note": "<script>owner note</script>", "candidates": [
            {"take": self.long["take_id"], "label": label, "gain_db": 0, "trim": [0, 1]}
            for label in "ABCD"]},
            "cue_two": {"note": "Short synthetic cue", "candidates": [
                {"take": self.short["take_id"], "label": "B", "gain_db": 0}]}}
        picks_path = self.write("picks.json", picks)
        destination = self.root / "audition"
        entries = audition(picks_path, destination, self.features, design=FIXTURE_DESIGN)
        parser = PageParser()
        text = (destination / "index.html").read_text()
        parser.feed(text)
        state = json.loads(parser.data)
        self.assertEqual(5, len(parser.audio))
        self.assertEqual({"cue_one", "cue_two"}, {radio["name"] for radio in parser.radios})
        self.assertEqual(picks, state["picks"])
        self.assertIn("&lt;script&gt;owner note&lt;/script&gt;", text)
        self.assertIn("Copy picks", text)
        self.assertIn(PAGE_TITLE, text)
        self.assertIn(AUDITION_CSS, text)
        self.assertEqual(KEYBOARD_SHORTCUTS, state["keyboard_shortcuts"])
        self.assertEqual(["cue_one", "cue_two"], state["cue_order"])
        self.assertEqual(5, len(parser.waveforms))
        for waveform, entry in zip(parser.waveforms, entries):
            points = [tuple(map(float, point.split(","))) for point in waveform["points"].split()]
            self.assertEqual(64, len(points))
            np.testing.assert_allclose([1 - y for _, y in points], entry["envelope"], atol=1e-6)
        self.assertNotIn("http://", text)
        self.assertNotIn("https://", text)
        for entry in entries:
            self.assertTrue((destination / entry["audio_path"]).is_file())
            audio, rate = decode(destination / entry["audio_path"])
            self.assertEqual(FIXTURE_RATE, rate)
            self.assertEqual(1, audio.shape[1])
            self.assertEqual("CC0-1.0", entry["licence_id"])
            self.assertEqual(sha256(destination / entry["audio_path"]), entry["output_sha256"])
        self.assertAlmostEqual(-20, entries[0]["processing"]["output_lufs"], delta=.5)
        self.assertAlmostEqual(-14, entries[-1]["processing"]["output_peak_dbfs"], delta=.1)
        self.assertEqual([], read_json(destination / "audition.json")["design_pending"])
        if PROOF_OUT:
            PROOF_OUT.mkdir(parents=True, exist_ok=True)
            shutil.copytree(destination, PROOF_OUT / "audition", dirs_exist_ok=True)
            shutil.copytree(self.analysis, PROOF_OUT / "analysis", dirs_exist_ok=True)
            shutil.copytree(self.sources, PROOF_OUT / "sources", dirs_exist_ok=True)
            write_json(PROOF_OUT / "picks.json", picks)
            write_json(PROOF_OUT / "synthetic-design.json", FIXTURE_DESIGN)
            catalogue = read_json(PROOF_OUT / "analysis/index.json")
            catalogue["sources"] = str(PROOF_OUT / "sources")
            write_json(PROOF_OUT / "analysis/index.json", catalogue)

    def test_page_javascript_offline_export_play_and_shortcuts(self):
        # Exercise the actual inline handlers under a small DOM harness, without
        # a browser dependency or window-server access.
        if not shutil.which("node"):
            self.skipTest("node unavailable; HTML/data proof still runs")
        harness = r'''
const handlers = {}, buttons = [], elements = {}, played = [];
let copied = '', fallback = 0;
const fixtureState = {picks:{cue:{note:'note'},next:{note:'next note'}},cue_order:['cue','next'],
 entries:[...['A','B','C','D'].map(label=>({cue_id:'cue',label})),{cue_id:'next',label:'A'}]};
fixtureState.entries.forEach((entry,index)=>{
 Object.assign(entry,{candidate:{take:'hash#1',label:entry.label,trim:[0,.1]},
 audio_id:'audio-'+index,radio_id:'radio-'+index,row_id:'row-'+index});
 const row={id:entry.row_id,tagName:'ARTICLE',picked:false,closest(){return this;},
  focus(){document.activeElement=this;handlers.focusin({target:this});},
  classList:{toggle(name,checked){row.picked=checked;}}};
 elements[entry.row_id]=row;
 elements[entry.audio_id]={currentTime:4,paused:true,ended:false,
  play(){this.paused=false;played.push(entry);return Promise.resolve();},pause(){this.paused=true;}};
 const radio={tagName:'INPUT',type:'radio',closest(){return row;},value:false};
 Object.defineProperty(radio,'checked',{get(){return this.value;},set(value){
  if(value) fixtureState.entries.filter(other=>other.cue_id===entry.cue_id).forEach(other=>{
   if(elements[other.radio_id]) elements[other.radio_id].value=false;
  }); this.value=value;
 }});
 elements[entry.radio_id]=radio;
 buttons.push({dataset:{play:entry.audio_id},tagName:'BUTTON',closest(){return row;},
  addEventListener(kind,fn){this.click=fn;}});
});
elements['page-data']={get textContent(){return JSON.stringify(fixtureState);}};
elements.export={tagName:'TEXTAREA',value:'',focus(){},select(){}};
elements['copy-picks']={tagName:'BUTTON',closest(){return null;},addEventListener(kind,fn){handlers.copy=fn;}};
global.document={getElementById:id=>elements[id],querySelectorAll:query=>query==='audio'
 ?fixtureState.entries.map(entry=>elements[entry.audio_id]):buttons,
 addEventListener:(kind,fn)=>handlers[kind]=fn,execCommand:()=>{fallback++;}};
global.window={isSecureContext:false};
Object.defineProperty(global,'navigator',{value:{clipboard:{writeText:async text=>copied=text}},configurable:true});
function key(code,target=document.activeElement||{tagName:'BODY'},extra={}){
 let prevented=false;
 handlers.keydown({code,target,preventDefault:()=>{prevented=true;},...extra});
 return prevented;
}
function assert(value,message){if(!value) throw Error(message);}
'''
        assertions = r'''
(async()=>{
 assert(!key('Space') && played.length===0,'unfocused Space');
 key('KeyJ');
 const first=fixtureState.entries[0];
 key('Space');
 assert(played.length===1 && !elements[first.audio_id].paused,'Space play');
 key('Space');
 assert(elements[first.audio_id].paused && elements[first.audio_id].currentTime===0,'Space stop');
 for(let number=1;number<=4;number++){
  key('Digit'+number);
  assert(played.at(-1).label==='ABCD'[number-1],'number shortcut '+number);
  assert(document.activeElement.id===fixtureState.entries[number-1].row_id,'candidate focus');
 }
 assert(fixtureState.entries.filter(entry=>!elements[entry.audio_id].paused).length===1,'single playback');
 const fourth=fixtureState.entries[3];
 key('KeyP');assert(elements[fourth.radio_id].checked && elements[fourth.row_id].picked,'P pick');
 key('KeyP');assert(!elements[fourth.radio_id].checked,'P unpick');
 key('KeyP');key('Digit2');key('KeyP');
 assert(!elements[fourth.radio_id].checked && elements[fixtureState.entries[1].radio_id].checked,'radio group exclusivity');
 const count=played.length;
 key('KeyJ');assert(document.activeElement.id===fixtureState.entries[4].row_id,'J next cue');
 key('KeyJ');assert(document.activeElement.id===fixtureState.entries[4].row_id,'last cue boundary');
 assert(!key('Digit3') && played.length===count,'absent label');
 key('KeyK');assert(document.activeElement.id===first.row_id,'K previous cue');
 key('KeyK');assert(document.activeElement.id===first.row_id,'first cue boundary');
 assert(played.length===count,'cue navigation does not autoplay');
 assert(!key('Space',elements['copy-picks']),'native Copy picks Space');
 assert(!key('KeyJ',elements.export),'text input guard');
 assert(!key('KeyJ',document.activeElement,{repeat:true}),'repeat guard');
 assert(!key('KeyJ',document.activeElement,{ctrlKey:true}),'modifier guard');
 const next=fixtureState.entries[4];
 handlers.focusin({target:elements[next.radio_id]});
 key('Space',elements[next.radio_id]);key('KeyP');
 assert(elements[next.radio_id].checked,'focused radio playback and pick');
 buttons[2].click();key('KeyP');
 assert(played.at(-1).label==='C' && elements[fixtureState.entries[2].radio_id].checked,'Play button and last-played pick');
 await handlers.copy();
 assert(fallback===1 && JSON.parse(elements.export.value).cue.candidates[0].trim[1]===.1,'offline copy');
 assert(JSON.parse(elements.export.value).cue.candidates[0].label==='C','selected candidate export');
 assert(JSON.parse(elements.export.value).next.candidates[0].label==='A','two-cue export');
 window.isSecureContext=true; await handlers.copy();
 assert(JSON.parse(copied).cue.note==='note','clipboard export');
 console.log('AUDITION_JS offline_copy=PASS clipboard_copy=PASS Space_1_4_J_K_P=PASS focus=PASS');
})().catch(error=>{console.error(error);process.exit(1);});
'''
        harness += "\nfixtureState.keyboard_shortcuts=" + json.dumps(KEYBOARD_SHORTCUTS) + ";\n"
        result = subprocess.run(["node", "-e", harness + PAGE_SCRIPT + assertions],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(0, result.returncode, result.stderr)
        print(result.stdout.strip())

    def test_build_deterministic_bytes_loudness_manifest(self):
        approved = {category: {"category": category, "variants": [{"take": self.long["take_id"]}],
                               "loop": True} for category in CATEGORY_TARGETS}
        approved_path = self.write("approved.json", approved)
        out = self.root / "build"
        manifest = self.root / "manifest.json"
        first = build(approved_path, out, manifest, self.features, design=FIXTURE_DESIGN)
        first_bytes = manifest.read_bytes()
        hashes = {row["path"]: sha256(out / row["path"]) for row in first["outputs"]}
        # Different output directory still yields identical encodings and manifest.
        second = build(approved_path, self.root / "build_again", self.root / "manifest_again.json",
                       self.features, design=FIXTURE_DESIGN)
        self.assertEqual(first, second)
        self.assertEqual(first_bytes, (self.root / "manifest_again.json").read_bytes())
        for row in first["outputs"]:
            self.assertEqual(hashes[row["path"]], sha256(self.root / "build_again" / row["path"]))
            self.assertAlmostEqual(CATEGORY_TARGETS[row["category"]], row["processing"]["output_lufs"], delta=.5)
            for key in ("source_path", "take_start_seconds", "take_end_seconds", "licence_id",
                        "source_sha256", "output_sha256", "processing"):
                self.assertIn(key, row)
            self.assertEqual(sha256(out / row["path"]), row["output_sha256"])
            audio, rate = decode(out / row["path"])
            self.assertEqual(48000, rate)
            if row["loop"]:
                self.assertEqual(.5, row["processing"]["loop_crossfade_seconds"])
                self.assertEqual(0, row["processing"]["fade_out_ms"])
                self.assertEqual("equal_power", row["processing"]["loop_crossfade_curve"])
                self.assertEqual(3, row["processing"]["fade_in_ms"])
                self.assertEqual("before_loop_crossfade", row["processing"]["fade_in_stage"])
                self.assertAlmostEqual(2.5, row["loop_end_seconds"], places=3)
        print(f"BUILD_PROOF variants={len(first['outputs'])} deterministic=PASS loudness_within_0.5_LU=PASS manifest=PASS")
        if PROOF_OUT:
            shutil.copytree(out, PROOF_OUT / "build", dirs_exist_ok=True)
            shutil.copyfile(manifest, PROOF_OUT / "manifest.json")
            write_json(PROOF_OUT / "approved.json", approved)

    def test_short_peak_caps_and_processing_parameters(self):
        expected_targets = {"impact": -3, "body": -4, "vocal": -6, "ui": -12,
                            "card": -10, "spell": -4, "movement": -14, "status": -8,
                            "pickup": -8, "stinger": -3}
        self.assertEqual(expected_targets, SHORT_PEAK_TARGETS)
        approved = {category: {"category": category, "variants": [{"take": self.short["take_id"]}]}
                    for category in expected_targets}
        result = build(self.write("short-approved.json", approved), self.root / "short-build",
                       self.root / "short-manifest.json", self.features, design=FIXTURE_DESIGN)
        for row in result["outputs"]:
            expected = expected_targets[row["category"]]
            self.assertAlmostEqual(expected, row["processing"]["output_peak_dbfs"], delta=.1)
            self.assertEqual("short_peak_dbfs", row["processing"]["normalization"])
            self.assertEqual("short_rms_dbfs", row["processing"]["output_loudness_method"])
            self.assertEqual(3, row["processing"]["fade_in_ms"])
        processed = {"filtered": {"category": "body", "variants": [
            {"take": self.long["take_id"], "trim": [.2, 2.2], "pitch": 2,
             "lowpass_hz": 400, "gain_db": -2, "fade_out_ms": 50}]}}
        result = build(self.write("processed.json", processed), self.root / "processed-build",
                       self.root / "processed-manifest.json", self.features, design=FIXTURE_DESIGN)
        parameters = result["outputs"][0]["processing"]
        self.assertAlmostEqual(1, parameters["output_duration"], delta=.02)
        self.assertEqual(400, parameters["lowpass_hz"])
        self.assertEqual(2, parameters["pitch"])
        self.assertEqual([.2, 2.2], parameters["trim"])
        self.assertEqual(2, parameters["lowpass_order"])
        self.assertEqual("butterworth", parameters["lowpass_filter"])
        self.assertEqual("equal_power", parameters["fade_curve"])
        self.assertEqual("resample", parameters["pitch_mode"])
        self.assertAlmostEqual(-20, parameters["output_lufs"], delta=.5)
        print(f"SHORT_PEAK_PROOF categories={len(expected_targets)} targets=PASS")

    def test_stereo_policy_and_loop_seam(self):
        dual = np.concatenate([sine(1), sine(1)], axis=1)
        self.assertEqual(1, choose_channels(dual, "impact", {})[0].shape[1])
        stereo = np.concatenate([sine(1), sine(1, frequency=1300)], axis=1)
        self.assertEqual(2, choose_channels(stereo, "body", FIXTURE_DESIGN)[0].shape[1])
        self.assertEqual(2, choose_channels(stereo, "stinger", {})[0].shape[1])
        for ratio in FIXTURE_STEREO_SIDE_RATIOS:
            # Constant mid=1/side=ratio makes the exact threshold unambiguous.
            pair = np.tile([1 + ratio, 1 - ratio], (512, 1))
            result, parameters = choose_channels(pair, "body", {})
            self.assertEqual(1 if ratio < .25 else 2, result.shape[1])
            self.assertAlmostEqual(ratio, parameters["stereo_side_ratio"], places=12)
            self.assertEqual(.25, parameters["stereo_side_ratio_threshold"])
        antiphase = np.concatenate([sine(1), -sine(1)], axis=1)
        result, parameters = choose_channels(antiphase, "body", {})
        self.assertEqual(2, result.shape[1])
        self.assertIsNone(parameters["stereo_side_ratio"])
        json.dumps(parameters, allow_nan=False)
        for category in ("ambience", "stinger"):
            self.assertEqual(2, choose_channels(dual, category, {})[0].shape[1])
        loop = crossfade_loop(sine(2.3, frequency=1273), FIXTURE_RATE, FIXTURE_DESIGN)
        self.assertLess(abs(loop[-1, 0] - loop[0, 0]), .04)

    def test_equal_power_fades_linear_fade_in_and_crossfade(self):
        original = np.ones((4800, 2))
        faded = fade_in(original, FIXTURE_RATE)
        count = round(3 * FIXTURE_RATE / 1000)
        np.testing.assert_allclose(faded[:count, 0], np.linspace(0, 1, count))
        np.testing.assert_array_equal(faded[count:], original[count:])
        self.assertEqual(3, FADE_IN_MS)
        faded = fade_out(original, FIXTURE_RATE, 30)
        count = round(.03 * FIXTURE_RATE)
        np.testing.assert_allclose(faded[-count:, 0], np.sin(np.linspace(np.pi / 2, 0, count)))
        self.assertEqual(0, faded[-1, 0])
        self.assertAlmostEqual(np.sqrt(.5), faded[-count // 2, 0], delta=.001)
        np.testing.assert_array_equal(original, np.ones_like(original))
        loop = crossfade_loop(np.ones((3 * FIXTURE_RATE, 1)), FIXTURE_RATE, {})
        count = FIXTURE_RATE // 2
        self.assertAlmostEqual(np.sqrt(2), loop[-count // 2, 0], delta=.001)
        self.assertEqual(FADE_CURVE, "equal_power")

    def test_lowpass_before_normalization_and_short_boundary(self):
        # A normalized single sine cannot prove filtering; compare two bands.
        fixture = self.sources / "kenney/filter-proof.wav"
        sf.write(fixture, sine(2) + sine(2, frequency=7000), FIXTURE_RATE, subtype="PCM_24")
        try:
            analysis = self.root / "filter-analysis"
            create_index(self.sources, analysis / "index.json", 1)
            create_slices(analysis / "index.json", analysis / "takes.jsonl", 1)
            rows = create_features(analysis / "index.json", analysis / "takes.jsonl",
                                   analysis / "features.jsonl", 1)
            row = next(row for row in rows if row["source_path"] == "kenney/filter-proof.wav")
            library = TakeLibrary(analysis / "features.jsonl")
            unfiltered, rate, _ = process(library, row, {}, "body", False, {})
            filtered, _, parameters = process(library, row, {"lowpass_hz": 2000}, "body", False, {})
            self.assertGreater(measure(unfiltered, rate)["high_band_ratio"], .4)
            self.assertLess(measure(filtered, rate)["high_band_ratio"], .01)
            self.assertAlmostEqual(-18, measure(filtered, rate)["lufs"], delta=.01)
            self.assertEqual(2, parameters["lowpass_order"])
        finally:
            fixture.unlink()
        library = TakeLibrary(self.features)
        for duration, method in [(0.399, "short_peak_dbfs"), (0.4, "integrated_lufs")]:
            _, _, parameters = process(library, self.long, {"trim": [0, duration]}, "body", False, {})
            self.assertEqual(method, parameters["normalization"])
        _, _, parameters = process(library, self.long, {"trim": [0, .4]}, "ambience", False, {})
        self.assertEqual("integrated_lufs", parameters["normalization"])

    def test_multichannel_front_pair_in_audition_and_build(self):
        sources = self.root / "multichannel-sources"
        source_dir = sources / "kenney"
        source_dir.mkdir(parents=True, exist_ok=True)
        (source_dir / "LICENSE.txt").write_text("Synthetic test licence record\n")
        mid, side = sine(2), sine(2, frequency=1300, amplitude=.06)
        pair = np.concatenate((mid + side, mid - side), axis=1)
        multichannel = np.concatenate((pair, sine(2, frequency=7000, amplitude=.9),
                                       sine(2, frequency=100, amplitude=.9)), axis=1)
        sf.write(source_dir / "front.wav", pair, FIXTURE_RATE, subtype="PCM_24")
        sf.write(source_dir / "four.wav", multichannel, FIXTURE_RATE, subtype="PCM_24")
        analysis = self.root / "multichannel-analysis"
        create_index(sources, analysis / "index.json", 1)
        create_slices(analysis / "index.json", analysis / "takes.jsonl", 1)
        rows = create_features(analysis / "index.json", analysis / "takes.jsonl",
                               analysis / "features.jsonl", 1)
        picks = {"front_pair": {"note": "Synthetic front-pair comparison", "candidates": [
            {"take": row["take_id"], "label": label} for row, label in zip(rows, "AB")]}}
        entries = audition(self.write("multichannel-picks.json", picks), self.root / "multichannel-audition",
                           analysis / "features.jsonl")
        self.assertEqual(entries[0]["output_sha256"], entries[1]["output_sha256"])
        approved = {"front_pair": {"category": "body", "variants": [
            {"take": row["take_id"]} for row in rows]}}
        result = build(self.write("multichannel-approved.json", approved), self.root / "multichannel-build",
                       self.root / "multichannel-manifest.json", analysis / "features.jsonl")
        self.assertEqual(result["outputs"][0]["output_sha256"], result["outputs"][1]["output_sha256"])
        for entry in (next(entry for entry in entries if entry["processing"]["source_channels"] == 4),
                      next(entry for entry in result["outputs"] if entry["processing"]["source_channels"] == 4)):
            self.assertEqual(4, entry["processing"]["source_channels"])
            self.assertEqual("front_pair", entry["processing"]["multichannel_downmix"])
            self.assertEqual(2, entry["processing"]["channels"])
        # The same rule handles arbitrary extra channels, not only four.
        six = np.concatenate((multichannel, sine(2, 8000), sine(2, 9000)), axis=1)
        selected, parameters = choose_channels(six, "stinger", {})
        np.testing.assert_array_equal(pair, selected)
        self.assertEqual(6, parameters["source_channels"])
        print("MULTICHANNEL_PROOF audition=PASS build=PASS ignored_channels=PASS")

    def test_refuse_excluded_paths_symlinks_and_forged_provenance(self):
        excluded = self.root / "sfx-sources-excluded-2026-10-12"
        excluded.mkdir(exist_ok=True)
        forbidden = excluded / "forbidden.wav"
        sf.write(forbidden, sine(.5), FIXTURE_RATE)
        for path in (forbidden, self.root / "mixkit/anything.wav"):
            with self.assertRaisesRegex(LabError, "Excluded"):
                safe_path(path)
        with self.assertRaisesRegex(LabError, "Excluded"):
            create_index(excluded, self.root / "excluded-index.json")
        link = self.sources / "kenney/link.wav"
        link.symlink_to(forbidden)
        try:
            with self.assertRaisesRegex(LabError, "Excluded"):
                create_index(self.sources, self.root / "symlink-index.json")
        finally:
            link.unlink()
        rows = copy.deepcopy(self.rows)
        rows[0]["licence_id"] = "Wrong"
        bad = self.analysis / "bad-features.jsonl"
        write_jsonl(bad, rows)
        with self.assertRaisesRegex(LabError, "Licence mismatch"):
            TakeLibrary(bad)
        rows[0]["licence_id"] = self.rows[0]["licence_id"]
        rows[0]["source_path"] = "mixkit/anything.wav"
        write_jsonl(bad, rows)
        with self.assertRaises(LabError):
            TakeLibrary(bad)

    def test_unknown_ambiguous_modified_take_and_unsafe_cue(self):
        library = TakeLibrary(self.features)
        with self.assertRaisesRegex(LabError, "Unknown take"):
            library.get({"take": "missing#1"})
        rows = copy.deepcopy(self.rows)
        duplicate = copy.deepcopy(self.long)
        duplicate["source_path"] = "kenney/duplicate.wav"
        shutil.copyfile(self.sources / "kenney/tone.wav", self.sources / "kenney/duplicate.wav")
        rows.append(duplicate)
        path = self.analysis / "duplicate-features.jsonl"
        write_jsonl(path, rows)
        duplicate_library = TakeLibrary(path)
        with self.assertRaisesRegex(LabError, "Ambiguous take"):
            duplicate_library.get({"take": self.long["take_id"]})
        duplicate_library.get({"take": self.long["take_id"], "source_path": "kenney/duplicate.wav"})
        sf.write(self.sources / "kenney/duplicate.wav", sine(.6), FIXTURE_RATE)
        with self.assertRaisesRegex(LabError, "Source hash changed"):
            TakeLibrary(path).get({"take": self.long["take_id"], "source_path": "kenney/duplicate.wav"})
        (self.sources / "kenney/duplicate.wav").unlink()
        approved = {"../escape": {"category": "impact", "variants": [{"take": self.long["take_id"]}]}}
        with self.assertRaisesRegex(LabError, "Unsafe cue"):
            build(self.write("unsafe.json", approved), self.root / "unsafe-build",
                  self.root / "unsafe-manifest.json", self.features, design=FIXTURE_DESIGN)

    def test_approved_defaults_and_invalid_inputs(self):
        approved = {"ambience": {"category": "ambience", "variants": [{"take": self.short["take_id"]}]}}
        with self.assertRaisesRegex(LabError, "Ambience must be at least 0.4 s"):
            build(self.write("short-ambience.json", approved), self.root / "short-ambience-build",
                  self.root / "short-ambience-manifest.json", self.features)
        with self.assertRaisesRegex(LabError, "owner-approved value"):
            fade_out(sine(1), FIXTURE_RATE, 30, {"fade_curve": "linear"})
        library = TakeLibrary(self.features)
        with self.assertRaisesRegex(LabError, "outside take"):
            library.excerpt(self.long, {"trim": [-1, 1]})
        for count in (0, 5):
            with self.assertRaises(argparse.ArgumentTypeError):
                workers(count)

    def test_cli_index_slice_features_query_audition_build(self):
        destination = self.root / "cli"
        commands = [
            ["index", "--sources", str(self.sources), "--out", str(destination / "index.json")],
            ["slice", "--index", str(destination / "index.json"), "--out", str(destination / "takes.jsonl")],
            ["features", "--index", str(destination / "index.json"), "--takes", str(destination / "takes.jsonl"),
             "--out", str(destination / "features.jsonl")],
            ["index", "query", "--features", str(destination / "features.jsonl"), "--path", "tone.wav",
             "--duration", "1", "4", "--sort", "centroid_hz"]]
        picks = self.write("cli-picks.json", {"cue_one": {"note": "", "candidates": [
            {"take": self.long["take_id"], "label": "A"}]}, "cue_two": {"note": "", "candidates": [
                {"take": self.short["take_id"], "label": "B"}]}})
        approved = self.write("cli-approved.json", {"impact": {"category": "impact", "variants": [
            {"take": self.long["take_id"]}]}})
        commands += [["audition", "--picks", str(picks), "--out", str(destination / "audition"),
                      "--features", str(destination / "features.jsonl")],
                     ["build", "--approved", str(approved), "--out-dir", str(destination / "build"),
                      "--manifest", str(destination / "manifest.json"), "--features", str(destination / "features.jsonl"),
                      ]]
        for name, *arguments in commands:
            result = subprocess.run([sys.executable, str(ROOT / "tools/sfx_lab" / (name + ".py")), *arguments],
                                    capture_output=True, text=True, timeout=180)
            self.assertEqual(0, result.returncode, result.stderr)
            self.assertTrue(result.stdout.strip())


if __name__ == "__main__":
    parser = argparse.ArgumentParser(add_help=False)
    parser.add_argument("--proof-out", type=Path)
    args, remaining = parser.parse_known_args()
    if args.proof_out:
        PROOF_OUT = safe_path(args.proof_out)
    unittest.main(argv=[sys.argv[0], *remaining])
