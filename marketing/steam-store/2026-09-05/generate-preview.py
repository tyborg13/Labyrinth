#!/usr/bin/env python3
"""Build the local Steam description preview and reviewable upload instructions."""
from __future__ import annotations

import argparse
import hashlib
import re
import html
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--resolve-steam', action='store_true', help='Resolve only UI-observed Steam references whose uploaded hashes match the current assets')
    args = parser.parse_args()
    # This generated upload file is valid only after a successful resolution
    # against the current copy, media bytes and observed Steam references.
    (ROOT / 'description.bbcode.txt').unlink(missing_ok=True)
    copy = json.loads((ROOT / 'copy.json').read_text())
    media = json.loads((ROOT / 'media-manifest.json').read_text())
    banner_manifest = json.loads((ROOT / 'banners/manifest.json').read_text())
    loops = {entry['file']: entry for entry in media['loops']}
    assert len(copy['short_description']) <= 300
    assert len(copy['sections']) == len(banner_manifest['outputs']) == 4
    assert len(media['screenshots']) == 8 and len(loops) == 5
    for entry in media['screenshots'] + media['loops']:
        path = ROOT / entry['file']
        assert hashlib.sha256(path.read_bytes()).hexdigest() == entry['sha256'], path
    description = [copy['intro']]
    bbcode = [copy['intro']]
    sections_html = []
    uploads = []
    layout = []
    for section, banner in zip(copy['sections'], banner_manifest['outputs']):
        assert section['heading'] == banner['heading']
        sid = section['id']
        banner_file = 'banners/' + banner['stem'] + '.png'
        banner_path = ROOT / banner_file
        assert hashlib.sha256(banner_path.read_bytes()).hexdigest() == banner['png_sha256']
        banner_placeholder = '{{STEAM_IMAGE_URL_BANNER_' + sid.upper() + '}}'
        banner_entry = {
            'id': 'banner_' + sid, 'kind': 'image', 'file': banner_file,
            'width': 1170, 'height': 176, 'alt_text': section['heading'].title(),
            'sha256': banner['png_sha256'], 'bytes': banner_path.stat().st_size,
            'placeholder': banner_placeholder, 'replacement': 'Steam-hosted image URL',
            'contains_english_heading': True,
        }
        uploads.append(banner_entry)
        blocks = [{'kind': 'banner', 'asset_id': banner_entry['id']}, {'kind': 'text', 'text': section['body']}]
        description.extend(['## ' + section['heading'], section['body']])
        bbcode.extend(['[img]' + banner_placeholder + '[/img]', section['body']])
        section_html = [f'<section aria-labelledby="{sid}-heading">',
                        f'<h2 id="{sid}-heading"><img src="{html.escape(banner_file)}" width="1170" height="176" alt="{html.escape(section["heading"])}"></h2>',
                        '<p>' + html.escape(section['body']) + '</p>']
        for file in section['media']:
            loop = loops[file]
            aid = 'loop_' + Path(file).stem.replace('-', '_')
            placeholder = '{{STEAM_VIDEO_EMBED_' + aid.upper() + '}}'
            uploads.append({
                'id': aid, 'kind': 'silent_animation', 'file': file,
                'width': loop['width'], 'height': loop['height'], 'duration_seconds': loop['duration_seconds'],
                'alt_text': loop['alt'], 'sha256': loop['sha256'], 'bytes': loop['bytes'],
                'placeholder': placeholder, 'replacement': 'Complete video embed markup returned by the Steam custom-asset UI',
                'muted': True, 'loop': True,
            })
            blocks.append({'kind': 'loop', 'asset_id': aid})
            bbcode.append(placeholder)
            section_html.append(
                f'<video autoplay muted loop playsinline controls preload="metadata" width="{loop["width"]}" height="{loop["height"]}" aria-label="{html.escape(loop["alt"])}">'
                f'<source src="{html.escape(file)}" type="video/mp4">'
                f'{html.escape(loop["alt"])}</video>'
            )
        section_html.append('</section>')
        sections_html.append('\n'.join(section_html))
        layout.append({'section_id': sid, 'heading': section['heading'], 'blocks': blocks})
    assert len(uploads) == 9
    assert {e['file'] for e in uploads if e['kind'] == 'silent_animation'} == set(loops)
    total_bytes = sum(e['bytes'] for e in uploads)
    (ROOT / 'description.md').write_text('\n\n'.join(description) + '\n')
    (ROOT / 'short-description.txt').write_text(copy['short_description'] + '\n')
    (ROOT / 'description.bbcode.template.txt').write_text('\n\n'.join(bbcode) + '\n')
    page = '''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Escape the Umbra — Store Description Preview</title>
<style>
:root{color-scheme:dark;background:#1b2838;color:#c6d4df;font-family:Arial,Helvetica,sans-serif;font-size:14px}
*{box-sizing:border-box}body{margin:0;padding:32px 16px 64px}.store-column{width:100%;max-width:780px;margin:0 auto}
.summary{margin:0 0 36px}.summary h1{font-size:26px;font-weight:400;color:#fff;margin:0 0 14px}.summary p{max-width:650px}
.about-title{font-size:18px;font-weight:400;letter-spacing:1px;color:#fff;margin:0 0 18px;padding-bottom:8px;border-bottom:1px solid #44627b}
p{line-height:1.6;margin:0 0 18px}section{margin:28px 0}h2{font-size:20px;margin:0 0 14px}h2 img{width:100%;height:auto;display:block}
video{display:block;width:100%;height:auto;aspect-ratio:16/9;background:#000;margin:0 0 20px}
@media(max-width:500px){body{padding:20px 16px 40px}.summary{margin-bottom:28px}.summary h1{font-size:24px}section{margin:24px 0}}
</style></head><body><main class="store-column">
<section class="summary" aria-labelledby="game-title"><h1 id="game-title">Escape the Umbra</h1><p>''' + html.escape(copy['short_description']) + '''</p></section>
<article aria-labelledby="about-title"><h2 class="about-title" id="about-title">ABOUT THIS GAME</h2><p>''' + html.escape(copy['intro']) + '''</p>
''' + '\n'.join(sections_html) + '''
</article></main></body></html>
'''
    (ROOT / 'preview.html').write_text(page)
    plan = {
        'schema': 1, 'app_id': 4530510, 'language': 'english',
        'short_description_file': 'short-description.txt', 'short_description_characters': len(copy['short_description']),
        'about_template_file': 'description.bbcode.template.txt', 'local_preview': 'preview.html',
        'placeholder_policy': 'Replace every {{STEAM_*}} token with the exact corresponding custom asset reference from Steamworks before saving final public copy. Image tokens accept URLs; video tokens accept complete Steam-generated embed markup. No guessed video BBCode is provided.',
        'gallery': [dict(order=i, file=e['file'], alt_text=e['alt'], sha256=e['sha256'], width=e['width'], height=e['height']) for i, e in enumerate(media['screenshots'], 1)],
        'description_asset_uploads': uploads, 'about_section_order': layout,
        'description_asset_total_bytes': total_bytes,
        'final_ui_checks': ['All eight gallery frames are in the specified order.', 'All four banners and five loops load in the English About This Game section.', 'Every media item has its supplied alt text; banner heading images use the English localization group.', 'No {{STEAM_*}} placeholders remain in the final saved description.', 'Steam preview plays the animations silently and retains expected color, framing and mobile readability.'],
    }
    (ROOT / 'upload-plan.json').write_text(json.dumps(plan, indent=2, ensure_ascii=False) + '\n')
    if args.resolve_steam:
        refs = json.loads((ROOT / 'steam-asset-refs.json').read_text())
        resolved = '\n\n'.join(bbcode) + '\n'
        for entry in uploads:
            token = entry['placeholder']
            value = refs.get('mapping', {}).get(token)
            assert value, f'Missing UI-observed Steam reference: {token}'
            assert refs.get('uploaded_sha256', {}).get(token) == entry['sha256'], f'Uploaded asset hash is missing or stale: {entry["file"]}'
            expression = r'\{STEAM_APP_IMAGE\}/extras/[A-Za-z0-9][A-Za-z0-9_.-]*'
            if entry['kind'] == 'silent_animation':
                expression = r'\[img\]' + expression + r'\[/img\]'
            assert re.fullmatch(expression, value), f'Unexpected Steam asset markup: {token}'
            resolved = resolved.replace(token, value)
        assert '{{STEAM_' not in resolved, 'Unresolved Steam media placeholder'
        (ROOT / 'description.bbcode.txt').write_text(resolved)
    print(json.dumps({'gallery': 8, 'banners': 4, 'loops': 5, 'description_asset_bytes': total_bytes, 'short_description_characters': len(copy['short_description'])}))


if __name__ == '__main__':
    main()
