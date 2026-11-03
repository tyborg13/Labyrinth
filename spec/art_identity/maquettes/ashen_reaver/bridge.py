"""Director bridge with a strict response deadline including queue time."""
import json
from pathlib import Path
import time
from spec.art_identity.maquettes.blender import bridge_client
from spec.art_identity.maquettes.blender.curate_delivery import write

EXECUTION_DEFAULTS={'job_timeout_s':110,'response_timeout_s':120,'poll_s':1}


def job(script,args,output,name):
    output=Path(output);output.mkdir(parents=True,exist_ok=True)
    identifier=bridge_client.submit(Path(script).resolve(),[str(a) for a in args],timeout_s=EXECUTION_DEFAULTS['job_timeout_s'])
    print('MQ16_BRIDGE_SUBMITTED: '+name+'; '+identifier,flush=True)
    root=Path(bridge_client.BRIDGE_DEFAULTS['root'])/'done'
    deadline=time.monotonic()+EXECUTION_DEFAULTS['response_timeout_s']
    while not (root/(identifier+'.json')).is_file():
        if time.monotonic()>=deadline:raise TimeoutError('No bridge answer within 120s; stop: '+identifier)
        time.sleep(EXECUTION_DEFAULTS['poll_s'])
    result=json.loads((root/(identifier+'.json')).read_text());result.update(id=identifier,timeout_s=110,response_timeout_s=120)
    log=root/(identifier+'.log')
    (output/(name+'.log')).write_text(log.read_text() if log.is_file() else str(result))
    write(output/(name+'.json'),result)
    print('MQ16_BRIDGE_RESULT: '+name+'; exit='+str(result['exit'])+'; seconds='+str(result.get('seconds',0)),flush=True)
    if result['exit']:raise ValueError('Bridge job failed: '+str(output/(name+'.log')))
    return result
