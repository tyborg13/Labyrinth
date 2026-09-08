# Third animation pass

User inspection requested side/downward sword cuts, walking toes oriented with travel, an idle led by body bobbing like the authored sprite sheet, and a general cleanup of incorrect segmentation across both facings. The reported hand/cloak issue is one example, not the scope limit.

## Design and inspection contract

The existing standalone board inspection remains the surface for judging character identity, readable action and anatomical continuity. Front/rear action selection, paused stepping and the optional bone detail retain their hierarchy and native input paths. The third pass changes painted-part ownership and motion rather than the surrounding controls. Fresh real-renderer proof covers all five actions in both facings at 1920×1080 and 100% UI scale, with complete 512px pose sequences for source-boundary inspection and a labeled all-action feedback reel. Paused states permit detailed inspection without continuous motion.

The semantic ownership audit must examine every part on both source paintings and its behavior through the complete action range. Exact neutral reconstruction and shared weights remain necessary but cannot establish that an arm pixel belongs to an arm.

## Comparison material

`renders/pass2/` preserves the five front/rear sheets and relevant reports from reviewed commit `6bcc01b2d8b0e05729fe1d217a1006c902ba24e5`. Current third-pass proof replaces the main render outputs and records hashes of the frozen motion, masks and capture inputs.

## Motion decisions

The authored player idle uses eight row-major 1020px frames at 10fps, a 0.8-second loop. Matching source regions show roughly one source pixel of coherent head/chest/free-hand rise, with fixed boots and a delayed sword hand. The second rig pass had nearly zero integer body displacement over its two-second cycle, while cloth and limb rotations supplied most visible motion. Reference frames and bounded template-translation measurements are retained under `references/authored_idle*`; local redraws prevent treating those estimates as exact rigid transforms.

The new idle uses twenty frames at 24fps (0.833 seconds), with a 1.5px downward compression and return shared by pelvis, chest, head and free hand. It follows the original cadence and coherent bob while keeping straight source legs reachable without stretching. The sword follows slightly later and cloth movement relative to the body stays below a third of a source pixel.

Front and rear attacks have independently authored preparation and cut angles for their opposite painted sword orientations. The blade moves sideways/up during preparation, then cuts down and across more quickly before recovery. The direction check isolates the main cut rather than mistaking the windup for the hit. Block and hit retain their second-pass motion.

Walking retains the one-second stride and matching board travel. The front near boot turns inward by 1.10 radians and the rear near boot by -0.60 radians; their source alpha contours supply a sole-depth correction. During stance the angle stays constant and the planted sole travels backward exactly against forward board movement. This is rotation of painted 2D pieces, not a newly drawn perspective view of a boot.


## Final review

[The segmentation assessment](segmentation_audit.md) records the disposition of every source part and the final pixel transfers. Both source paintings remain byte-identical to the second pass. All 272 final rendered poses were reviewed for source ownership, silhouette and joint continuity. Fresh board proof covers every action in both facings at 1920×1080/100%, with 38 inspected screenshots and all 72 paired traveling frames reviewed at native scale. The controls, information hierarchy, focus indication and paused stepping continue to meet the inspection fixture's existing UI contract.

All 67 core generated assets/layouts reproduce byte-identically. Both neutral rigs reproduce their source RGBA exactly; saved/reloaded scenes match their live builders in all ten action/facing cases, including non-neutral idle. Motion and weighted-joint checks pass against the final inputs. The normal/half-speed feedback reel contains every authored frame and preserves one fixed camera crop through all actions, including the full rear sword at its extremes.

The results retain the source's stylized proportions and limits: boot rotation cannot supply new perspective artwork, the idle adapts the authored sheet's cadence/coherence rather than reproducing its frame drawings, and hidden anatomy remains unavailable. No production movement or animation routing is integrated.
