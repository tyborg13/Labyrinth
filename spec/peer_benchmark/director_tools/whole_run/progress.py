from pathlib import Path
import json

BASE=Path('/private/tmp/labyrinth_codex/perf-65')
print('\n'.join((BASE/'whole-session.log').read_text().splitlines()[-6:]))
for folder in sorted(BASE.glob('whole-*-*')):
    path=folder/'trace.jsonl'
    if not path.is_file() or (folder/'summary.json').exists():continue
    with path.open('rb') as stream:
        stream.seek(max(0,path.stat().st_size-20000))
        lines=stream.read().decode(errors='replace').splitlines()
    for line in reversed(lines):
        try:record=json.loads(line)
        except ValueError:continue
        if record.get('event')=='decision':
            row=record['data'];context=row['context']
            print(folder.name,'decision',row['decision'],'section',context['section'],
                  'depth',context['room_metadata'].get('depth'),context['room_kind'])
            break
