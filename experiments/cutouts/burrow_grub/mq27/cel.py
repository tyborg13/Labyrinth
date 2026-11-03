"""Rebuild this unit's cel variants with the unchanged common builder, isolated."""
from unittest.mock import patch
from prepare import *
import cel_look
import cel_look_inventory
from cel_look_state import status

PROOF_OUTPUT = Path('/private/tmp/labyrinth_codex/rr-55/cel_grub')


def build():
    all_entries, classification = cel_look_inventory.inventory(PROJECT)
    prefix = 'assets/units/burrow_grub_cutout/'
    entries = [entry for entry in all_entries if entry['path'].startswith(prefix)]
    with patch.object(cel_look_inventory, 'inventory', lambda _: (entries, classification)):
        result = cel_look.build(PROJECT, PROOF_OUTPUT)
    current, reason = status(PROJECT, PROOF_OUTPUT, entries, cel_look.settings())
    record = {'ok':current,'files':len(entries),'output':str(PROOF_OUTPUT),'status':reason,
        'builder':'tools/cel_look.py build (unchanged, inventory restricted to owned Grub paths)',
        'global_cache':'Finalize with the normal common build after director native rest rebake'}
    write_json(CASE/'proof/cel.json',record)
    print('MQ27 CEL: %s (%d owned variants; common builder; isolated output)'%('PASS' if current else 'FAIL',len(entries)))
    if not current: raise CutoutError(reason)


if __name__=='__main__': build()
