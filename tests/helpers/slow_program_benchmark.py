#!/usr/bin/env python3
"""Serial, scratch-only measurements for the test-05 assertion-preserving pass.

No production sources are changed. Each snapshot has its own copied tests and
scripts, shares only read-only assets/imports, and launches through the task
runner. Three ordinary runs supply wall medians; an additional instrumented run
records executed assertion messages and non-overlapping statement phases.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import re
import shutil
import statistics
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PROGRAMS = (
    "event_rules_test", "suites/full_scene_interaction_program",
    "suites/full_scene_controls_program", "section_map_v2_test",
    "suites/encounter_placement_0_program", "section_transition_test",
    "event_view_test", "suites/encounter_placement_1_program", "brs02_test",
    "special_encounter_test",
)
PARTS = {
    "event_rules_test": ("event_rules_test", "suites/event_preview_matrix_program"),
    "suites/full_scene_interaction_program": (
        "suites/full_scene_interaction_program", "suites/full_scene_interaction_followup_program"),
    "suites/full_scene_controls_program": (
        "suites/full_scene_controls_program", "suites/full_scene_empower_feedback_program"),
    "section_map_v2_test": ("section_map_v2_test", "suites/section_map_v2_followup_program"),
    "suites/encounter_placement_0_program": (
        "suites/encounter_placement_0_program", "suites/encounter_placement_0_followup_program"),
    "suites/encounter_placement_1_program": (
        "suites/encounter_placement_1_program", "suites/encounter_placement_1_followup_program"),
    "brs02_test": ("brs02_test", "suites/brs02_reduced_program"),
    "special_encounter_test": ("special_encounter_test", "suites/special_encounter_followup_program"),
}
REPEATS = 3
TIMEOUT_SECONDS = 900
PROFILE = 'preload("res://tests/helpers/slow_program_profile.gd")'
LIVE_ARROW_MESSAGE_PREFIX = 'Targeting arrow remains visible and ends on the hero (visible: '

PROFILE_SOURCE = '''extends Node
static var messages: Dictionary = {}
static var failures: Array[String]
static var phases: Dictionary = {}
static var stack: Array[Dictionary]
static var dispatch: int = 0
static var functions: Dictionary = {}
class Scope extends RefCounted:
	var label: String
	var started: int
	func _notification(what: int) -> void:
		if what == NOTIFICATION_PREDELETE:
			var profile = preload("res://tests/helpers/slow_program_profile.gd")
			profile.functions[label] = int(profile.functions.get(label, 0)) + Time.get_ticks_usec() - started
static func scope(label: String) -> RefCounted:
	var result := Scope.new()
	result.label = label
	result.started = Time.get_ticks_usec()
	return result
static func enter(phase: String) -> void:
	stack.append({"phase": phase, "started": Time.get_ticks_usec(), "children": 0})
static func leave() -> void:
	var entry: Dictionary = stack.pop_back()
	var elapsed: int = Time.get_ticks_usec() - int(entry["started"])
	phases[entry["phase"]] = int(phases.get(entry["phase"], 0)) + elapsed - int(entry["children"])
	if not stack.is_empty(): stack.back()["children"] += elapsed
static func record(ok: bool, message: String) -> void:
	if dispatch > 0: return
	messages[message] = int(messages.get(message, 0)) + 1
	if not ok: failures.append(message)
static func forward(callback: Callable, ok: bool, message: String) -> void:
	record(ok, message)
	dispatch += 1
	callback.call(ok, message)
	dispatch -= 1
static func check(ok: bool, message: String = "") -> void:
	record(ok, message)
	assert(ok, message)
func _exit_tree() -> void:
	var count: int = 0
	for value: int in messages.values(): count += value
	var result: Dictionary = {"assertion_count": count, "messages": messages, "failures": failures, "phase_usec": phases, "function_usec": functions}
	var file := FileAccess.open(OS.get_environment("TEST05_PROFILE_OUTPUT"), FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\\t"))
	print("TEST05 ASSERTIONS: %d; unique messages: %d; failures: %d" % [count, messages.size(), failures.size()])
'''


def code_only(source: str) -> str:
    """Mask GDScript literals/comments while preserving offsets and newlines."""
    result = list(source)
    index = 0
    while index < len(source):
        char = source[index]
        if char == '#':
            end = source.find('\n', index)
            if end < 0: end = len(source)
        elif char in ('"', "'"):
            quote = char * (3 if source.startswith(char * 3, index) else 1)
            end = index + len(quote)
            while end < len(source):
                if source[end] == "\\":
                    end += 2
                elif source.startswith(quote, end):
                    end += len(quote)
                    break
                else:
                    end += 1
        else:
            index += 1
            continue
        for offset in range(index, min(end, len(source))):
            if result[offset] != '\n': result[offset] = ' '
        index = end
    return ''.join(result)


def instrument(source: str, name: str) -> str:
    lines = source.splitlines(keepends=True)
    masked = code_only(source).splitlines(keepends=True)
    result: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        clean = masked[index]
        # Record at callback sinks, including direct calls, without counting
        # forwarded callbacks twice. Inline closures are covered by forward.
        sink = re.match(r'^(\s*)(?:static )?func (_assert|_expect)\((\w+): bool, message: String\) -> void:', clean)
        function = re.match(r'^(\s*)(?:static )?func (\w+)\(.*\) -> [\w\[\]]+:\s*$', clean)
        if function:
            result.append(line)
            indent, method = function.groups()
            if method.startswith(('_test_', '_run', 'run', 'fixture', '_event_state', '_exhaustive', '_selection', '_effects', '_omens', '_reachable', 'placement_seed_range')):
                result.append(f'{indent}\tvar __test05_scope: RefCounted = {PROFILE}.scope({json.dumps(name + ":" + method)})\n')
            if sink:
                result.append(f'{sink[1]}\t{PROFILE}.record({sink[3]}, message)\n')
            index += 1
            continue
        # Only actual statements, not source strings, comments or declarations.
        if not clean.strip() or not line.startswith(('\t', ' ')):
            result.append(line)
            index += 1
            continue
        statement = line
        balance = sum(clean.count(c) for c in '([{') - sum(clean.count(c) for c in ')]}')
        end = index + 1
        while balance > 0 and end < len(lines):
            statement += lines[end]
            more = masked[end]
            balance += sum(more.count(c) for c in '([{') - sum(more.count(c) for c in ')]}')
            end += 1
        stripped = clean.strip()
        phase = None
        if (re.match(r'(?:var |await |[\w.]+\(|[\w.]+\s*=)', stripped) or (stripped.startswith('for ') and re.search(r':\s*await ', clean))) and not stripped.startswith(('return ', 'if ', 'elif ', 'else:', 'while ', 'func ', 'static ', 'var source', 'source ')) and 'func(' not in statement:
            if '.instantiate(' in statement or '.add_child(' in statement or re.search(r'\bload\("res://scenes/', statement):
                phase = 'scene_loads'
            elif re.search(r'create_new_run\(|create_combat\(|generate_room\(|_base_grid\(|_apply_template\(|expand_entry\(|Graph\.(?:initialize|_initialize_revision_\d|_section_layout_v\d|_fallback_layout)\(|Factory.build\(', statement):
                phase = 'fixture_builds'
            elif re.match(r'(?:expect.call|_expect|_assert|assert)\(', stripped):
                phase = 'assertions'
            elif 'await ' in stripped and ('process_frame' in stripped or 'physics_frame' in stripped or 'create_timer' in stripped or 'frame_post_draw' in stripped or '._animate' in stripped or '.finish_enemies(' in stripped or '._on_pass_turn_pressed(' in stripped):
                phase = 'frame_waits'
        # The callback recorder retains the original boolean evaluation and
        # original failure transport. Intrinsic assert still calls assert.
        statement_mask = ''.join(masked[index:end])
        replacements = []
        for pattern, replacement in ((r'\bexpect\.call\(', PROFILE + '.forward(expect, '), (r'(?<![\w.])assert\(', PROFILE + '.check(')):
            replacements.extend((match.start(), match.end(), replacement) for match in re.finditer(pattern, statement_mask))
        for begin, finish, replacement in sorted(replacements, reverse=True):
            statement = statement[:begin] + replacement + statement[finish:]
        if phase:
            indent = re.match(r'^\s*', line).group().replace('\n', '')
            result.append(f'{indent}{PROFILE}.enter("{phase}")\n')
            result.append(statement)
            result.append(f'{indent}{PROFILE}.leave()\n')
        else:
            result.append(statement)
        index = end
    return ''.join(result)


def prepare(destination: Path, tests_source: Path, *, profile: bool) -> None:
    destination.mkdir(parents=True, exist_ok=False)
    for item in ROOT.iterdir():
        if item.name in ('.git', 'tests', 'scripts'):
            continue
        (destination / item.name).symlink_to(item, target_is_directory=item.is_dir())
    shutil.copytree(ROOT / 'scripts', destination / 'scripts')
    shutil.copytree(tests_source, destination / 'tests')
    if profile:
        for path in (destination / 'tests').rglob('*.gd'):
            path.write_text(instrument(path.read_text(), str(path.relative_to(destination))))
        (destination / 'tests/helpers/slow_program_profile.gd').write_text(PROFILE_SOURCE)


def run_one(project: Path, program: str, log: Path, profile_output: Path | None,
            user_args: list[str] | None = None) -> dict:
    import os
    env = os.environ.copy()
    entry = 'res://tests/' + program + '.gd'
    if profile_output:
        env['TEST05_PROFILE_OUTPUT'] = str(profile_output)
        bootstrap = log.with_suffix('.gd')
        bootstrap.write_text(f'extends "{entry}"\nfunc _initialize() -> void:\n\troot.add_child({PROFILE}.new())\n\tsuper._initialize()\n')
        entry = str(bootstrap)
    reports = log.parent / 'placement-reports'
    reports.mkdir(exist_ok=True)
    command = ['python3', str(ROOT / 'tools/godot_task_runner.py'), '--task-id', 'test-05', '--timeout', str(TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', str(project), '--script', entry, '--', '--placement-report-directory=' + str(reports)]
    command.extend(user_args or [])
    started = time.monotonic()
    with log.open('w') as output:
        completed = subprocess.run(command, cwd=project, env=env, stdout=output, stderr=subprocess.STDOUT)
    elapsed = time.monotonic() - started
    result = {'wall_seconds': elapsed, 'exit_code': completed.returncode, 'log': str(log)}
    print(f'{program}: {elapsed:.3f}s exit={completed.returncode} {log}', flush=True)
    return result


def assertion_calls(source: str) -> Counter:
    """Retain boolean and message expressions, ignoring indentation changes."""
    masked = code_only(source)
    calls: Counter = Counter()
    for match in re.finditer(r'\bexpect\.call\(|(?<![\w.])(?:_assert|_expect|assert)\(', masked):
        prefix = masked[masked.rfind('\n', 0, match.start()) + 1:match.start()].strip()
        if prefix in ('func', 'static func'):
            continue
        depth, end = 1, match.end()
        while depth and end < len(masked):
            depth += int(masked[end] == '(') - int(masked[end] == ')')
            end += 1
        calls[re.sub(r'\s+', ' ', source[match.start():end]).strip()] += 1
    return calls


def authored_messages(profile: dict) -> dict:
    # This existing message embeds the board's live tween coordinates. Even
    # unchanged repeat runs differ in those diagnostic values. Preserve the
    # actual assertions, their source expressions and all raw evidence; compare
    # the authored format here, retaining the visibility value and call count.
    result: Counter = Counter()
    for message, count in profile['messages'].items():
        identity = message
        if message.startswith(LIVE_ARROW_MESSAGE_PREFIX):
            identity = re.sub(r'(endpoint|hero): \([-+.\deE]+, [-+.\deE]+\)', r'\1: <live position>', message)
        result[identity] += count
    return dict(result)


def assertion_equivalence(original: dict, current: dict) -> dict:
    old, new = authored_messages(original), authored_messages(current)
    return {
        'before_count': original['assertion_count'], 'after_count': current['assertion_count'],
        'same_message_set': old.keys() == new.keys(),
        'same_message_frequencies': old == new,
        'raw_message_set_equal': original['messages'].keys() == current['messages'].keys(),
        'raw_message_frequencies_equal': original['messages'] == current['messages'],
        'removed_messages': sorted(old.keys() - new.keys()),
        'added_messages': sorted(new.keys() - old.keys()),
        'raw_removed_messages': sorted(original['messages'].keys() - current['messages'].keys()),
        'raw_added_messages': sorted(current['messages'].keys() - original['messages'].keys()),
        'changed_frequencies': {
            message: [old[message], new[message]]
            for message in old.keys() & new.keys() if old[message] != new[message]
        },
    }


def compare(output: Path, baseline_tests: Path) -> None:
    before = json.loads((output / 'before/summary.json').read_text())
    after = json.loads((output / 'after/summary.json').read_text())
    report: dict = {'programs': {}, 'assertion_expressions': {}}
    for program in before.keys() & after.keys():
        original, current = before[program]['profile'], after[program]['profile']
        result = assertion_equivalence(original, current)
        report['programs'][program] = result
        print('ASSERTION EQUIVALENCE %s: %d -> %d; message set=%s; frequencies=%s' % (
            program, result['before_count'], result['after_count'], result['same_message_set'], result['same_message_frequencies']))
    for original in baseline_tests.rglob('*.gd'):
        current = ROOT / 'tests' / original.relative_to(baseline_tests)
        if current.exists() and current.read_text() != original.read_text():
            old, new = assertion_calls(original.read_text()), assertion_calls(current.read_text())
            report['assertion_expressions'][str(current.relative_to(ROOT))] = {
                'same': old == new, 'before_sites': sum(old.values()), 'after_sites': sum(new.values())}
    (output / 'assertion-equivalence.json').write_text(json.dumps(report, indent=2) + '\n')
    assert all(value['before_count'] == value['after_count'] and value['same_message_set'] and value['same_message_frequencies'] for value in report['programs'].values()), 'Executed assertions changed; inspect assertion-equivalence.json'
    assert all(value['same'] for value in report['assertion_expressions'].values()), 'Assertion expressions changed; inspect assertion-equivalence.json'


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--snapshot', choices=('before', 'after'), required=True)
    parser.add_argument('--baseline-tests', type=Path)
    parser.add_argument('--program', choices=PROGRAMS, action='append')
    parser.add_argument('--compare-only', action='store_true')
    parser.add_argument('--reuse-profiles', action='store_true', help='reuse successful profiles after a comparison-only tooling fix; requires identical ordinary GDScript sources')
    args = parser.parse_args()
    if args.compare_only:
        compare(args.output_dir.resolve(), args.baseline_tests or args.output_dir / 'baseline-tests')
        return
    directory = args.output_dir.resolve() / args.snapshot
    directory.mkdir(parents=True, exist_ok=True)
    tests_source = args.baseline_tests or ROOT / 'tests'
    ordinary, profiled = directory / 'ordinary', directory / 'profiled'
    for project, enabled in ((ordinary, False), (profiled, True)):
        if not project.exists(): prepare(project, tests_source, profile=enabled)
    summary_path = directory / 'summary.json'
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    registry = {entry['path']: entry for entry in json.loads((ROOT / 'tests/headless_test_programs.json').read_text())}
    if args.reuse_profiles:
        for folder in ('tests', 'scripts'):
            for source in (ROOT / folder).rglob('*.gd'):
                assert source.read_bytes() == (ordinary / source.relative_to(ROOT)).read_bytes(), source
    for program in args.program or PROGRAMS:
        if program in summary and not args.program:
            print(f'{program}: reusing completed measurements in {summary_path}', flush=True)
            continue
        parts = PARTS.get(program, (program,)) if args.snapshot == 'after' else (program,)
        measured: dict[str, dict] = {}
        for part in parts:
            slug = part.replace('/', '-')
            profile_output = directory / f'{slug}-profile.json'
            user_args = registry['tests/' + part + '.gd'].get('args', []) if args.snapshot == 'after' else []
            profile_log = directory / f'{slug}-profile.log'
            profile_run = None
            if args.reuse_profiles and profile_output.exists():
                for output_log in args.output_dir.glob('*benchmark*.log'):
                    matches = re.findall(re.escape(part) + r': ([0-9.]+)s exit=0 ' + re.escape(str(profile_log)), output_log.read_text())
                    if matches:
                        profile_run = {'wall_seconds': float(matches[-1]), 'exit_code': 0, 'log': str(profile_log)}
                        print(part + ': reusing successful profile ' + str(profile_output), flush=True)
                        break
                assert profile_run is not None, 'No successful profile timing found for ' + part
            if profile_run is None:
                profile_run = run_one(profiled, part, profile_log, profile_output, user_args)
            if profile_run['exit_code']:
                raise SystemExit('Profile failed; inspect its log before measuring')
            measured[part] = {'profile_run': profile_run, 'profile': json.loads(profile_output.read_text())}
        combined: dict = {'assertion_count': 0, 'messages': {}, 'failures': [], 'phase_usec': {}, 'function_usec': {}}
        for part in measured.values():
            profile = part['profile']
            combined['assertion_count'] += profile['assertion_count']
            combined['failures'].extend(profile['failures'])
            for field in ('messages', 'phase_usec', 'function_usec'):
                for key, value in profile[field].items(): combined[field][key] = combined[field].get(key, 0) + value
        if args.snapshot == 'after':
            original = json.loads((args.output_dir / 'before/summary.json').read_text())[program]['profile']
            equivalence = assertion_equivalence(original, combined)
            (directory / (program.replace('/', '-') + '-assertions.json')).write_text(json.dumps(equivalence, indent=2) + '\n')
            assert equivalence['before_count'] == equivalence['after_count'] and equivalence['same_message_frequencies'], equivalence
            suffix = '; live-coordinate diagnostics retained separately' if not equivalence['raw_message_frequencies_equal'] else ''
            print('ASSERTION EQUIVALENCE %s: PASS (%d assertions; identical authored message frequencies%s)' % (program, combined['assertion_count'], suffix), flush=True)
        for part, result in measured.items():
            slug = part.replace('/', '-')
            user_args = registry['tests/' + part + '.gd'].get('args', []) if args.snapshot == 'after' else []
            runs = [run_one(ordinary, part, directory / f'{slug}-{index}.log', None, user_args) for index in range(REPEATS)]
            result.update(runs=runs, median_seconds=statistics.median(run['wall_seconds'] for run in runs))
            if any(run['exit_code'] for run in runs):
                raise SystemExit('Measurement failed; inspect logs before continuing')
        summary[program] = dict(measured[program])
        summary[program]['parts'] = measured
        summary[program]['median_seconds'] = max(part['median_seconds'] for part in measured.values())
        summary[program]['serial_median_seconds'] = sum(part['median_seconds'] for part in measured.values())
        summary[program]['profile'] = combined
        summary_path.write_text(json.dumps(summary, indent=2) + '\n')


if __name__ == '__main__':
    main()
