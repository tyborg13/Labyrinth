"""On-demand director-rule boundary checks; not a permanent suite module."""
import numpy as np
from build import CASE
from cloth_rags import accepted,RagComponentPolicy
from cutout_pipeline.cases import write_json
from build import CASE

PROOF_SIZE=32


def fixture(size=6,gap=8,logical='cloak',foreign=False):
    main=np.zeros((PROOF_SIZE,PROOF_SIZE,4),np.uint8);rag=main.copy();plate=main.copy()
    main[4:12,4:9]=255
    rag[5:5+size,8+gap]=255
    if foreign:plate[5,8+gap]=255
    parts=[{'name':'cloth_body','logical_part':logical,'z_index':0},{'name':'cloth_rag','logical_part':logical,'z_index':1},{'name':'plate','logical_part':'leg_near','z_index':2}]
    return {'facing':'front','parts':parts},[(parts[0],main,None),(parts[1],rag,None),(parts[2],plate,None)]


def run():
    checks=0
    for size,gap,logical,foreign,clip,expected in [
        (6,8,'cloak',False,'move',1),(6,8,'tabard',False,'peal',1),
        (7,8,'cloak',False,'move',0),(6,9,'cloak',False,'move',0),
        (6,8,'leg_near',False,'move',0),(6,8,'staff',False,'move',0),
        (6,8,'head',False,'move',0),(6,8,'cloak',True,'move',0),
        (6,8,'cloak',False,'idle',0),(6,8,'tabard',False,'hit',0)]:
        layout,layers=fixture(size,gap,logical,foreign);masks,records=accepted(layout,layers,clip)
        assert len(masks)==expected,(size,gap,logical,foreign,clip,records);checks+=1
    from cpu_native_superset import pocket_report
    hole={'view':'front','clip':'death','frame':0,'pockets':[{'bbox':[1,1,3,4],'pixel_count':6}]}
    cpu={'errors':[{'view':'front','clip':'death','frame':0,'kind':'joint_hole','source_space':{'bbox':[1,1,3,4],'pixel_count':5}}]}
    assert pocket_report(cpu,[hole])['ok'];checks+=1
    assert not pocket_report({'errors':[]},[hole])['ok'];checks+=1
    write_json(CASE/'proof/feedback2/rule_checks.json',{'ok':True,'checks':checks,'native_pixels':False})
    print('RR56 CLOTH RULE CHECKS: PASS (%d checks; size/distance boundaries, non-cloth, mixed paint, idle and hit)'%checks)

if __name__=='__main__':run()
