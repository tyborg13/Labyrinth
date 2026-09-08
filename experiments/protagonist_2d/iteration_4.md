# Fourth animation pass

The user requested a nearly upright overhead sword preparation followed by a down/across cut into the space ahead, walking feet that do not curl toward knees, idle bob without inward knee buckling, a guard across the body where possible, significantly faster walking, and closure of front shoulder/cloak and leg gaps. Every review action must appear on the actual combat board.

## Motion and attachment decisions

The 24-pose walk now runs at 36fps instead of 24fps: 0.667 seconds per stride, with matched board travel 50% faster. Near boots use more moderate planted angles and relax in flight. Actual opaque boot contours determine rotated sole depth; lift peaks at about 7.43 source pixels. This preserves directional intent without forcing the painted toes to match a 2D travel vector at every phase. Both near toes stay at least 30 source pixels from their knees, with toe-to-knee angles above 80 degrees throughout.

Idle keeps its accepted 20-pose bob but counter-translates each thigh against the 1.5-pixel hip translation before any leg IK. Legs therefore retain their rest angles and global joint positions while the torso moves vertically. The sleeve emerging beneath the front cloak shares the exact cape weight field at its concealed shoulder before blending to the arm over 12 pixels. The painted arm remains assigned to the arm; no arm pixels are left on the cloak to hide a gap. Local hip/ankle weights reduce folded leg texture while keeping endpoints attached.

Attack raises each blade almost vertically, holds briefly, then cuts fast through the space ahead. The strike extends roughly 152 front / 170 rear source pixels ahead of the torso; the blade tip remains roughly 59 / 63 pixels above the nearest boot at the cut endpoint. The front guard crosses the upper body. Rear guard uses a high diagonal partly occluded by the head. The front wrist enters guard with the arm to avoid folding its short sleeve. Hit remains the established recoil.

## Inspection surface and proof

The existing CombatBoardView remains the primary surface. Front/rear and action selection, pointer/native keyboard controls, pause/frame-step and detail-only bones retain the established UiSkin/UiTypography hierarchy. The final 1920×1080, 100% scale Metal/Mobile capture contains 40 native screenshots and 368 lossless motion frames across all five actions in both views. Its 416 pose/travel checks passed. Direct runtime/capture and production dependencies were hashed before and after capture without change.

The primary `renders/board/videos/all_animations_board.mp4` reel pairs actual board frames using one fixed crop and native pixel scale. Every action appears twice normally and once at half speed. Walk includes all three captured gait cycles in each repetition. The 72fps encode duplicates authored frames exactly, preserving both 24fps actions and 36fps walk; no pose interpolation or per-frame camera fitting occurs. Full inspection-surface clips are also retained.

Visual review inspected all 272 fixed-canvas action poses, native board regions in all 40 screenshots, full-surface control/detail/reference states, and all 72 paired travel poses. Shoulder, arm, knee and ankle attachments remain continuous; sword preparation and strike stay in frame; the front guard reads across the chest; boots relax without pointing into knees. The UI rubric passes for hierarchy, typography, feedback, input and pause/step examination. Numeric triangle checks still report small leg texture folds at some extreme poses, which were judged against the rendered results rather than hidden by the report.

Other checks: 257 sampled phases per clip/facing pass the expanded motion contract; all 14 weighted meshes pass source/weight/endpoint checks; both neutral references render with zero differing RGBA pixels; all ten saved-scene motion comparisons are pixel-identical; 67 core generated assets/layouts reproduce byte-for-byte. Fourteen board MP4s pass exact dimensions, timing and full decoding. Historical pass-three sheets/reports/reel are retained in `renders/pass3`.

## Limits

The source paintings and exclusive cutout ownership are unchanged from pass three. Boot turns remain 2D rotations, and the rear painting is a separate interpretation of hidden anatomy. The production static shadow is reused; animation selection, tile movement and combat routing remain outside this study. A production Continue save is not applicable: the verified standalone `inspection.tscn` opens the relevant actions directly. No balance, icon registry or gameplay event changes occur.
