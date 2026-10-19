"""Run from the reviewed checkout. No repository files are changed."""
import sys,tempfile
from pathlib import Path
import numpy as np
from PIL import Image
sys.path.insert(0,str(Path.cwd()/'tools'))
from humanoid_cutout.rest_space import DetachedSource,pockets
from humanoid_cutout.gates import clean_metrics
from humanoid_cutout.native_exceptions import frame_errors
paint=np.zeros((32,32,4),dtype=np.uint8)
paint[10:24,10:24]=[70,60,90,255]
paint[8:10,15]=[5,5,5,255]  # Original connected sleeve tip and bridge.
checks=np.zeros_like(paint)
checks[paint[...,3]>0]=[255,0,0,255]
part={'name':'sleeve','logical_part':'sleeve','offset':[0,0],'z_index':0}
with tempfile.TemporaryDirectory(prefix='rr20-review-detached-') as folder:
 case=Path(folder)
 Image.fromarray(paint).save(case/'rest.png')
 Image.fromarray(checks).save(case/'checks.png')
 layout={'rest_source':'rest.png','parts':[part],'joint_meshes':[{'name':'sleeve'}],
         'proof_layers':{'sleeve':{'mask':'checks.png','mask_offset':[0,0]}}}
 approved=DetachedSource(case,layout)
 assert len(approved.references)==0
 # Mutate presented skin, leaving immutable source/checks untouched.
 damaged=paint.copy()
 damaged[9,15]=0
 layers=[(part,damaged,checks)]
 source=approved.report(layers,{})
 space=pockets(layers)
 metrics=clean_metrics(layers)
 metrics.update(source['metrics'])
 errors=frame_errors(('front','bolt',1),metrics,[{k:p[k] for k in ('bbox','pixel_count')} for p in space['failures']])
 print('Approved detached source components:',len(approved.references))
 print('Provenance passes:',source['source_components'])
 print('Metrics:',metrics)
 print('Final frame errors:',errors)
 assert not errors
 assert metrics['stray_components']==0 and metrics['exempt_outline_components']==1
 print('SURVIVED: newly detached skin fragment has no source provenance')
