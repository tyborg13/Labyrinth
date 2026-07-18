import { Audio, Video } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import type { ReactNode } from "react";
import {
  AbsoluteFill,
  Easing,
  Img,
  Sequence,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";

const FPS = 30;
const TRANSITION = 12;
const PROGRESSION_TRANSITION = 8;

const PROGRESSION_CLIP = {
  merchant: 104,
  relic: 110,
  spell: 120,
  magicEquip: 120,
  equipment: 174,
} as const;

const PROGRESSION_START = {
  merchant: 0,
  relic: PROGRESSION_CLIP.merchant - PROGRESSION_TRANSITION,
  spell:
    PROGRESSION_CLIP.merchant +
    PROGRESSION_CLIP.relic -
    PROGRESSION_TRANSITION * 2,
  magicEquip:
    PROGRESSION_CLIP.merchant +
    PROGRESSION_CLIP.relic +
    PROGRESSION_CLIP.spell -
    PROGRESSION_TRANSITION * 3,
  equipment:
    PROGRESSION_CLIP.merchant +
    PROGRESSION_CLIP.relic +
    PROGRESSION_CLIP.spell +
    PROGRESSION_CLIP.magicEquip -
    PROGRESSION_TRANSITION * 4,
} as const;

const PROGRESSION_DURATION =
  PROGRESSION_START.equipment + PROGRESSION_CLIP.equipment;

const SCENE = {
  opening: 120,
  route: 132,
  prebattle: 144,
  trap: 168,
  aoe: 168,
  umbra: 180,
  progression: PROGRESSION_DURATION,
  final: 300,
} as const;

const START = {
  opening: 0,
  route: SCENE.opening - TRANSITION,
  prebattle: SCENE.opening + SCENE.route - TRANSITION * 2,
  trap: SCENE.opening + SCENE.route + SCENE.prebattle - TRANSITION * 3,
  aoe:
    SCENE.opening + SCENE.route + SCENE.prebattle + SCENE.trap - TRANSITION * 4,
  umbra:
    SCENE.opening +
    SCENE.route +
    SCENE.prebattle +
    SCENE.trap +
    SCENE.aoe -
    TRANSITION * 5,
  progression:
    SCENE.opening +
    SCENE.route +
    SCENE.prebattle +
    SCENE.trap +
    SCENE.aoe +
    SCENE.umbra -
    TRANSITION * 6,
  final:
    SCENE.opening +
    SCENE.route +
    SCENE.prebattle +
    SCENE.trap +
    SCENE.aoe +
    SCENE.umbra +
    SCENE.progression -
    TRANSITION * 7,
} as const;

export const TRAILER_DURATION = START.final + SCENE.final;

const PALETTE = {
  ink: "#08060a",
  ember: "#f19a3e",
  gold: "#e4c36a",
  parchment: "#fff0c8",
  violet: "#b689ff",
} as const;

const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};

const fadeTiming = linearTiming({ durationInFrames: TRANSITION });
const progressionFadeTiming = linearTiming({
  durationInFrames: PROGRESSION_TRANSITION,
});

const Vignette: React.FC<{ opacity?: number }> = ({ opacity = 1 }) => (
  <AbsoluteFill
    style={{
      pointerEvents: "none",
      opacity,
      boxShadow: "inset 0 0 210px 72px rgba(0,0,0,0.70)",
      background:
        "linear-gradient(180deg, rgba(5,3,7,0.30), transparent 25%, transparent 70%, rgba(5,3,7,0.52))",
    }}
  />
);

const FilmGrain: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        opacity: 0.075,
        mixBlendMode: "screen",
        backgroundImage:
          "radial-gradient(circle at 20% 30%, rgba(255,255,255,.30) 0 1px, transparent 1.5px), radial-gradient(circle at 75% 65%, rgba(255,194,112,.24) 0 1px, transparent 1.5px)",
        backgroundSize: "43px 47px, 61px 59px",
        backgroundPosition: `${(frame * 17) % 96}px ${(frame * 11) % 96}px, ${-(frame * 11) % 96}px ${(frame * 17) % 96}px`,
      }}
    />
  );
};

const EmberField: React.FC<{ opacity?: number }> = ({ opacity = 1 }) => {
  const frame = useCurrentFrame();
  const particles = Array.from({ length: 24 }, (_, index) => ({
    x: (index * 79 + 17) % 100,
    y:
      112 -
      ((frame * (0.09 + (index % 5) * 0.025) + ((index * 23) % 120)) % 130),
    size: 2 + (index % 4),
    alpha: 0.22 + ((index * 19) % 55) / 100,
  }));

  return (
    <AbsoluteFill style={{ pointerEvents: "none", opacity }}>
      {particles.map((particle, index) => (
        <div
          key={index}
          style={{
            position: "absolute",
            left: `${particle.x}%`,
            top: `${particle.y}%`,
            width: particle.size,
            height: particle.size * 2.4,
            borderRadius: 999,
            background: PALETTE.ember,
            opacity: particle.alpha,
            boxShadow: `0 0 ${particle.size * 4}px ${PALETTE.ember}`,
            rotate: index % 2 === 0 ? "-14deg" : "11deg",
          }}
        />
      ))}
    </AbsoluteFill>
  );
};

const EditorialFrame: React.FC<{
  children: ReactNode;
  vignetteOpacity?: number;
}> = ({ children, vignetteOpacity = 1 }) => (
  <AbsoluteFill style={{ backgroundColor: PALETTE.ink, overflow: "hidden" }}>
    {children}
    <Vignette opacity={vignetteOpacity} />
    <FilmGrain />
  </AbsoluteFill>
);

const CrumbledRule: React.FC<{ enterAt?: number }> = ({ enterAt = 0 }) => {
  const frame = useCurrentFrame();
  return (
    <div
      className="crumbled-rule"
      aria-hidden="true"
      style={{
        opacity: interpolate(frame, [enterAt, enterAt + 10], [0, 1], clamp),
        translate: `${interpolate(frame, [enterAt, enterAt + 14], [-24, 0], {
          ...clamp,
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        })}px 0`,
      }}
    >
      <span />
      <span />
      <span />
      <span />
    </div>
  );
};

const TITLE_CARD: Record<string, string> = {
  "PLAN YOUR DESCENT": "plan-your-descent",
  "READ THE ROOM": "read-the-room",
  "USE THE LABYRINTH": "use-the-labyrinth",
  "BUILD THE PERFECT TURN": "build-the-perfect-turn",
  "BRING LIGHT INTO THE UMBRA": "bring-light-into-the-umbra",
  "GROW STRONGER": "grow-stronger",
};

const CRUMB_BANDS = 7;

const CrumbleTitleArt: React.FC<{
  slug: string;
  alt: string;
  className: string;
  enterAt: number;
  shedAt: number;
}> = ({ slug, alt, className, enterAt, shedAt }) => {
  const frame = useCurrentFrame();
  return (
    <span
      className={`crumble-title-art ${className}`}
      style={{
        opacity: interpolate(frame, [enterAt, enterAt + 10], [0, 1], clamp),
        translate: `0 ${interpolate(frame, [enterAt, enterAt + 16], [34, 0], {
          ...clamp,
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        })}px`,
        scale: interpolate(frame, [enterAt, enterAt + 18], [0.975, 1], {
          ...clamp,
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        }),
      }}
    >
      <Img
        src={staticFile(`title-cards/${slug}.png`)}
        className="crumble-title-base"
        alt={alt}
      />
      {Array.from({ length: CRUMB_BANDS }, (_, index) => {
        const delay = index % 3;
        const shed = interpolate(
          frame,
          [shedAt + delay, shedAt + 24 + delay],
          [0, 1],
          {
            ...clamp,
            easing: Easing.in(Easing.cubic),
          },
        );
        const left = (index / CRUMB_BANDS) * 100;
        const right = 100 - ((index + 1) / CRUMB_BANDS) * 100;
        return (
          <Img
            key={index}
            src={staticFile(`title-cards/${slug}-fill.png`)}
            className="crumble-title-fill"
            alt=""
            aria-hidden="true"
            style={{
              clipPath: `inset(0 ${right}% 0 ${left}%)`,
              opacity: interpolate(
                frame,
                [shedAt + delay, shedAt + 7 + delay, shedAt + 24 + delay],
                [1, 1, 0],
                clamp,
              ),
              translate: `${(index - 3) * 3.5 * shed}px ${shed * (54 + (index % 4) * 13)}px`,
              rotate: `${(index % 2 === 0 ? -1 : 1) * shed * (1.5 + index * 0.22)}deg`,
            }}
          />
        );
      })}
    </span>
  );
};

const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <EditorialFrame>
      <Img
        src={staticFile("game-assets/art/ui/main_menu_umbra_dragon.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          opacity: interpolate(
            frame,
            [0, 12, 104, 120],
            [0, 1, 1, 0.76],
            clamp,
          ),
          scale: interpolate(frame, [0, SCENE.opening], [1.025, 1.095], {
            ...clamp,
            easing: Easing.bezier(0.22, 0.8, 0.36, 1),
          }),
          translate: "1.5% 0",
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(5,3,7,.96) 0%, rgba(5,3,7,.76) 30%, rgba(5,3,7,.13) 62%, transparent 100%)",
        }}
      />
      <div
        className="opening-copy"
        style={{
          opacity: interpolate(frame, [96, 112], [1, 0], clamp),
        }}
      >
        <CrumbleTitleArt
          slug="this-prison"
          alt="THIS PRISON"
          className="opening-line-art"
          enterAt={8}
          shedAt={29}
        />
        <CrumbleTitleArt
          slug="has-no-exit"
          alt="HAS NO EXIT"
          className="opening-line-art opening-accent-art"
          enterAt={14}
          shedAt={35}
        />
        <CrumbledRule enterAt={48} />
      </div>
      <EmberField opacity={0.58} />
    </EditorialFrame>
  );
};

type CopyPlacement = "left" | "right" | "center";

type CameraCue = {
  cardFrame: number;
  impactFrame: number;
  cardFocusX: number;
  cardFocusY: number;
  actionFocusX: number;
  actionFocusY: number;
  cardZoom: number;
  hitZoom: number;
  settleZoom: number;
  shake: number;
};

type FocusTrack = {
  frames: number[];
  scales: number[];
  translateX: number[];
  translateY: number[];
};

type SelectionCameraCue = {
  approachStart: number;
  approachEnd: number;
  selectionFrame: number;
  pullbackStart: number;
  pullbackEnd: number;
  startScale: number;
  focusScale: number;
  endScale: number;
  focusX: number;
  focusY: number;
  endX?: number;
  endY?: number;
  shake: number;
};

type ActionFollowCameraCue = {
  approachStart: number;
  approachEnd: number;
  followStart: number;
  followEnd: number;
  pullbackStart: number;
  pullbackEnd: number;
  startScale: number;
  focusScale: number;
  endScale: number;
  sourceOriginX: number;
  sourceOriginY: number;
  destinationOriginX: number;
  destinationOriginY: number;
  focusX: number;
  focusY: number;
  endX: number;
  endY: number;
};

type GameplaySceneProps = {
  clip: string;
  duration: number;
  headline: string;
  copyExitFrame: number;
  placement?: CopyPlacement;
  zoom?: number;
  accent?: "ember" | "violet" | "gold";
  camera?: CameraCue;
  focusTrack?: FocusTrack;
  vignetteOpacity?: number;
};

const GameplayTitle: React.FC<{
  headline: string;
  copyExitFrame: number;
  placement: CopyPlacement;
  accent: "ember" | "violet" | "gold";
}> = ({ headline, copyExitFrame, placement, accent }) => {
  const frame = useCurrentFrame();
  const accentColor =
    accent === "violet"
      ? PALETTE.violet
      : accent === "gold"
        ? PALETTE.gold
        : PALETTE.ember;

  return (
    <div
      className={`gameplay-copy gameplay-copy-${placement}`}
      style={{
        opacity: interpolate(
          frame,
          [copyExitFrame, copyExitFrame + 14],
          [1, 0],
          clamp,
        ),
        color: accentColor,
      }}
    >
      <CrumbleTitleArt
        slug={TITLE_CARD[headline]}
        alt={headline}
        className="gameplay-headline-art"
        enterAt={8}
        shedAt={29}
      />
      <CrumbledRule enterAt={44} />
    </div>
  );
};

const GameplayScene: React.FC<GameplaySceneProps> = ({
  clip,
  duration,
  headline,
  copyExitFrame,
  placement = "left",
  zoom = 1.025,
  accent = "ember",
  camera,
  focusTrack,
  vignetteOpacity = 1,
}) => {
  const frame = useCurrentFrame();
  const scale = focusTrack
    ? interpolate(frame, focusTrack.frames, focusTrack.scales, {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      })
    : camera
    ? interpolate(
        frame,
        [
          0,
          camera.cardFrame - 24,
          camera.cardFrame - 5,
          camera.cardFrame + 5,
          camera.impactFrame - 4,
          camera.impactFrame + 2,
          camera.impactFrame + 12,
          camera.impactFrame + 34,
          duration,
        ],
        [
          zoom,
          zoom + 0.014,
          camera.cardZoom,
          camera.cardZoom + 0.012,
          camera.cardZoom - 0.026,
          camera.hitZoom + 0.018,
          camera.hitZoom - 0.008,
          camera.settleZoom,
          camera.settleZoom + 0.012,
        ],
        clamp,
      )
    : interpolate(frame, [0, duration], [zoom, zoom + 0.026], {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      });
  const focusX = camera
    ? interpolate(
        frame,
        [0, camera.cardFrame + 8, camera.impactFrame + 2],
        [camera.cardFocusX, camera.cardFocusX, camera.actionFocusX],
        clamp,
      )
    : 50;
  const focusY = camera
    ? interpolate(
        frame,
        [0, camera.cardFrame + 8, camera.impactFrame + 2],
        [camera.cardFocusY, camera.cardFocusY, camera.actionFocusY],
        clamp,
      )
    : 50;
  const shakeEnvelope = camera
    ? interpolate(
        frame,
        [
          camera.impactFrame - 2,
          camera.impactFrame + 2,
          camera.impactFrame + 18,
        ],
        [0, 1, 0],
        clamp,
      )
    : 0;
  const shakeX = camera
    ? Math.sin(frame * 2.83) * camera.shake * shakeEnvelope
    : 0;
  const shakeY = camera
    ? Math.cos(frame * 3.47) * camera.shake * 0.62 * shakeEnvelope
    : 0;
  const panX = focusTrack
    ? interpolate(frame, focusTrack.frames, focusTrack.translateX, {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      })
    : 0;
  const panY = focusTrack
    ? interpolate(frame, focusTrack.frames, focusTrack.translateY, {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      })
    : 0;
  const impactLight = camera
    ? interpolate(
        frame,
        [
          camera.impactFrame - 2,
          camera.impactFrame + 1,
          camera.impactFrame + 10,
        ],
        [1, 1.2, 1],
        clamp,
      )
    : 1;

  return (
    <EditorialFrame vignetteOpacity={vignetteOpacity}>
      <Sequence durationInFrames={duration} premountFor={FPS}>
        <Video
          src={staticFile(`footage/${clip}.mp4`)}
          trimBefore={0}
          muted
          objectFit="cover"
          style={{
            width: "100%",
            height: "100%",
            scale,
            translate: `${panX + shakeX}px ${panY + shakeY}px`,
            transformOrigin: `${focusX}% ${focusY}%`,
            filter: `brightness(${impactLight}) saturate(${1.03 + (impactLight - 1) * 0.8})`,
          }}
        />
      </Sequence>
      <AbsoluteFill
        style={{
          opacity: interpolate(
            frame,
            [copyExitFrame, copyExitFrame + 14],
            [1, 0.18],
            clamp,
          ),
          background:
            placement === "right"
              ? "linear-gradient(180deg, transparent 50%, rgba(5,3,7,.12) 66%, rgba(5,3,7,.84) 100%), linear-gradient(90deg, transparent 45%, rgba(5,3,7,.34) 100%)"
              : placement === "center"
                ? "linear-gradient(180deg, rgba(5,3,7,.18), transparent 34%, transparent 58%, rgba(5,3,7,.76))"
                : "linear-gradient(180deg, transparent 48%, rgba(5,3,7,.12) 64%, rgba(5,3,7,.86) 100%), linear-gradient(90deg, rgba(5,3,7,.36), transparent 44%)",
        }}
      />
      <GameplayTitle
        headline={headline}
        copyExitFrame={copyExitFrame}
        placement={placement}
        accent={accent}
      />
    </EditorialFrame>
  );
};

const ProgressionClip: React.FC<{
  clip: "merchant" | "relic" | "spell" | "magic_equip" | "equipment";
  duration: number;
  playbackRate: number;
  focusTrack?: FocusTrack;
  selectionCamera?: SelectionCameraCue;
  actionFollowCamera?: ActionFollowCameraCue;
}> = ({
  clip,
  duration,
  playbackRate,
  focusTrack,
  selectionCamera,
  actionFollowCamera,
}) => {
  const frame = useCurrentFrame();
  const approach = selectionCamera
    ? interpolate(
        frame,
        [selectionCamera.approachStart, selectionCamera.approachEnd],
        [0, 1],
        {
          ...clamp,
          easing: Easing.bezier(0.45, 0, 0.55, 1),
        },
      )
    : 0;
  const pullback = selectionCamera
    ? interpolate(
        frame,
        [selectionCamera.pullbackStart, selectionCamera.pullbackEnd],
        [0, 1],
        {
          ...clamp,
          easing: Easing.bezier(0.45, 0, 0.55, 1),
        },
      )
    : 0;
  const selectionImpact = selectionCamera
    ? interpolate(
        frame,
        [
          selectionCamera.selectionFrame - 2,
          selectionCamera.selectionFrame + 1,
          selectionCamera.selectionFrame + 12,
        ],
        [0, 1, 0],
        clamp,
      )
    : 0;
  const trackedScale = focusTrack
    ? interpolate(frame, focusTrack.frames, focusTrack.scales, {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      })
    : 1;
  const trackedX = focusTrack
    ? interpolate(frame, focusTrack.frames, focusTrack.translateX, {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      })
    : 0;
  const trackedY = focusTrack
    ? interpolate(frame, focusTrack.frames, focusTrack.translateY, {
        ...clamp,
        easing: Easing.bezier(0.45, 0, 0.55, 1),
      })
    : 0;
  const followApproach = actionFollowCamera
    ? interpolate(
        frame,
        [actionFollowCamera.approachStart, actionFollowCamera.approachEnd],
        [0, 1],
        {
          ...clamp,
          easing: Easing.bezier(0.45, 0, 0.55, 1),
        },
      )
    : 0;
  const followMove = actionFollowCamera
    ? interpolate(
        frame,
        [actionFollowCamera.followStart, actionFollowCamera.followEnd],
        [0, 1],
        {
          ...clamp,
          easing: Easing.bezier(0.45, 0, 0.55, 1),
        },
      )
    : 0;
  const followPullback = actionFollowCamera
    ? interpolate(
        frame,
        [actionFollowCamera.pullbackStart, actionFollowCamera.pullbackEnd],
        [0, 1],
        {
          ...clamp,
          easing: Easing.bezier(0.45, 0, 0.55, 1),
        },
      )
    : 0;
  const cameraScale = actionFollowCamera
    ? actionFollowCamera.startScale +
      (actionFollowCamera.focusScale - actionFollowCamera.startScale) *
        followApproach +
      (actionFollowCamera.endScale - actionFollowCamera.focusScale) *
        followPullback
    : selectionCamera
    ? selectionCamera.startScale +
      (selectionCamera.focusScale - selectionCamera.startScale) * approach +
      (selectionCamera.endScale - selectionCamera.focusScale) * pullback +
      selectionImpact * 0.012
    : trackedScale;
  const cameraX = actionFollowCamera
    ? actionFollowCamera.focusX * followMove +
      (actionFollowCamera.endX - actionFollowCamera.focusX) * followPullback
    : selectionCamera
    ? selectionCamera.focusX * approach +
      ((selectionCamera.endX ?? 0) - selectionCamera.focusX) * pullback +
      Math.sin(frame * 2.7) * selectionCamera.shake * selectionImpact
    : trackedX;
  const cameraY = actionFollowCamera
    ? actionFollowCamera.focusY * followMove +
      (actionFollowCamera.endY - actionFollowCamera.focusY) * followPullback
    : selectionCamera
    ? selectionCamera.focusY * approach +
      ((selectionCamera.endY ?? -20) - selectionCamera.focusY) * pullback +
      Math.cos(frame * 3.2) * selectionCamera.shake * 0.58 * selectionImpact
    : trackedY;
  const cameraOriginX = actionFollowCamera
    ? actionFollowCamera.sourceOriginX +
      (actionFollowCamera.destinationOriginX -
        actionFollowCamera.sourceOriginX) *
        followMove
    : 50;
  const cameraOriginY = actionFollowCamera
    ? actionFollowCamera.sourceOriginY +
      (actionFollowCamera.destinationOriginY -
        actionFollowCamera.sourceOriginY) *
        followMove
    : selectionCamera
      ? 0
      : 50;
  return (
    <EditorialFrame vignetteOpacity={0.12}>
      <Sequence durationInFrames={duration} premountFor={FPS}>
        <Video
          src={staticFile(`footage/${clip}.mp4`)}
          trimBefore={0}
          playbackRate={playbackRate}
          muted
          objectFit="cover"
          style={{
            width: "100%",
            height: "100%",
            scale: cameraScale,
            translate: `${cameraX}px ${cameraY}px`,
            transformOrigin: `${cameraOriginX}% ${cameraOriginY}%`,
            filter: `brightness(${1 + selectionImpact * 0.09}) saturate(${1.02 + selectionImpact * 0.08})`,
          }}
        />
      </Sequence>
      <AbsoluteFill
        style={{
          background: "linear-gradient(180deg, rgba(5,3,7,.10), transparent 26%)",
        }}
      />
    </EditorialFrame>
  );
};

const ProgressionScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ backgroundColor: PALETTE.ink, overflow: "hidden" }}>
      <TransitionSeries>
        <TransitionSeries.Sequence durationInFrames={PROGRESSION_CLIP.merchant}>
          <ProgressionClip
            clip="merchant"
            duration={PROGRESSION_CLIP.merchant}
            playbackRate={0.84}
            selectionCamera={{
              approachStart: 2,
              approachEnd: 28,
              selectionFrame: 52,
              pullbackStart: 60,
              pullbackEnd: 88,
              startScale: 1.01,
              focusScale: 1.24,
              endScale: 1.03,
              focusX: 0,
              focusY: -250,
              shake: 7,
            }}
          />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={progressionFadeTiming}
        />
        <TransitionSeries.Sequence durationInFrames={PROGRESSION_CLIP.relic}>
          <ProgressionClip
            clip="relic"
            duration={PROGRESSION_CLIP.relic}
            playbackRate={0.62}
            selectionCamera={{
              approachStart: 2,
              approachEnd: 28,
              selectionFrame: 55,
              pullbackStart: 63,
              pullbackEnd: 91,
              startScale: 1.01,
              focusScale: 1.25,
              endScale: 1.03,
              focusX: 200,
              focusY: -270,
              shake: 6,
            }}
          />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={progressionFadeTiming}
        />
        <TransitionSeries.Sequence durationInFrames={PROGRESSION_CLIP.spell}>
          <ProgressionClip
            clip="spell"
            duration={PROGRESSION_CLIP.spell}
            playbackRate={0.62}
            selectionCamera={{
              approachStart: 2,
              approachEnd: 30,
              selectionFrame: 65,
              pullbackStart: 73,
              pullbackEnd: 101,
              startScale: 1.01,
              focusScale: 1.22,
              endScale: 1.03,
              focusX: -80,
              focusY: -230,
              shake: 6,
            }}
          />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={progressionFadeTiming}
        />
        <TransitionSeries.Sequence
          durationInFrames={PROGRESSION_CLIP.magicEquip}
        >
          <ProgressionClip
            clip="magic_equip"
            duration={PROGRESSION_CLIP.magicEquip}
            playbackRate={1}
            actionFollowCamera={{
              approachStart: 4,
              approachEnd: 24,
              followStart: 38,
              followEnd: 70,
              pullbackStart: 92,
              pullbackEnd: 116,
              startScale: 1.025,
              focusScale: 1.13,
              endScale: 1.05,
              sourceOriginX: 44,
              sourceOriginY: 44,
              destinationOriginX: 30,
              destinationOriginY: 60,
              focusX: 70,
              focusY: -24,
              endX: 15,
              endY: -6,
            }}
          />
        </TransitionSeries.Sequence>
        <TransitionSeries.Transition
          presentation={fade()}
          timing={progressionFadeTiming}
        />
        <TransitionSeries.Sequence
          durationInFrames={PROGRESSION_CLIP.equipment}
        >
          <ProgressionClip
            clip="equipment"
            duration={PROGRESSION_CLIP.equipment}
            playbackRate={1}
            actionFollowCamera={{
              approachStart: 92,
              approachEnd: 116,
              followStart: 116,
              followEnd: 140,
              pullbackStart: 150,
              pullbackEnd: 172,
              startScale: 1.025,
              focusScale: 1.12,
              endScale: 1.06,
              sourceOriginX: 45,
              sourceOriginY: 67,
              destinationOriginX: 30,
              destinationOriginY: 69,
              focusX: 75,
              focusY: -15,
              endX: 15,
              endY: -4,
            }}
          />
        </TransitionSeries.Sequence>
      </TransitionSeries>
      <div
        className="progression-copy"
        style={{
          opacity: interpolate(frame, [72, 84], [1, 0], clamp),
        }}
      >
        <CrumbleTitleArt
          slug={TITLE_CARD["GROW STRONGER"]}
          alt="GROW STRONGER"
          className="gameplay-headline-art"
          enterAt={7}
          shedAt={28}
        />
        <CrumbledRule enterAt={43} />
      </div>
    </AbsoluteFill>
  );
};

const FinalScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <EditorialFrame>
      <Img
        src={staticFile("game-assets/art/ui/main_menu_umbra_dragon.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          scale: interpolate(
            frame,
            [0, 178, 179, SCENE.final],
            [1.075, 1.105, 1.035, 1.018],
            {
              ...clamp,
              easing: Easing.bezier(0.45, 0, 0.55, 1),
            },
          ),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(4,3,6,.97) 0%, rgba(4,3,6,.82) 34%, rgba(4,3,6,.20) 66%, transparent 100%)",
        }}
      />
      <div
        className="dragon-question"
        style={{
          opacity: interpolate(frame, [72, 84], [1, 0], clamp),
        }}
      >
        <CrumbleTitleArt
          slug="will-you-let-the-shadow-consume-you"
          alt="WILL YOU LET THE SHADOW CONSUME YOU?"
          className="dragon-question-art"
          enterAt={8}
          shedAt={29}
        />
        <CrumbledRule enterAt={44} />
      </div>
      <div
        className="dragon-choice"
        style={{
          opacity: interpolate(frame, [166, 178], [1, 0], clamp),
        }}
      >
        <CrumbleTitleArt
          slug="or-will-you"
          alt="OR WILL YOU..."
          className="dragon-choice-art"
          enterAt={88}
          shedAt={109}
        />
      </div>
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(4,3,6,.98) 0%, rgba(4,3,6,.88) 38%, rgba(4,3,6,.30) 70%, rgba(4,3,6,.08) 100%)",
          opacity: interpolate(frame, [178, 179], [0, 1], clamp),
        }}
      />
      <div className="title-lockup">
        <CrumbleTitleArt
          slug="escape"
          alt="ESCAPE"
          className="title-escape-art"
          enterAt={180}
          shedAt={202}
        />
        <CrumbleTitleArt
          slug="the-umbra"
          alt="THE UMBRA"
          className="title-umbra-art"
          enterAt={186}
          shedAt={208}
        />
      </div>
      <div className="steam-cta">
        <div className="steam-cta-copy">
          <CrumbleTitleArt
            slug="wishlist-on"
            alt="WISHLIST ON"
            className="steam-cta-art"
            enterAt={248}
            shedAt={269}
          />
        </div>
        <Img
          src={staticFile("branding/steam-logo-inverse-transparent.png")}
          className="steam-logo"
          alt="Steam"
          style={{
            opacity: interpolate(frame, [254, 270], [0, 1], clamp),
            translate: `${interpolate(frame, [254, 274], [22, 0], {
              ...clamp,
              easing: Easing.bezier(0.16, 1, 0.3, 1),
            })}px 0`,
          }}
        />
      </div>
      <EmberField opacity={0.8} />
    </EditorialFrame>
  );
};

const ImpactFlash: React.FC<{ from: number; color: string }> = ({
  from,
  color,
}) => (
  <Sequence from={from} durationInFrames={16} premountFor={8}>
    <ImpactFlashContents color={color} />
  </Sequence>
);

const ImpactFlashContents: React.FC<{ color: string }> = ({ color }) => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        opacity: interpolate(frame, [0, 2, 7, 16], [0, 0.46, 0.11, 0], clamp),
        scale: interpolate(frame, [0, 16], [0.72, 1.38], clamp),
        background: `radial-gradient(circle at 52% 48%, ${color}, transparent 56%)`,
        mixBlendMode: "screen",
      }}
    />
  );
};

const Soundtrack: React.FC = () => (
  <>
    <Sequence durationInFrames={TRAILER_DURATION} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/music/zekarion_boss.wav")}
        trimBefore={5 * FPS}
        volume={(frame) =>
          interpolate(
            frame,
            [0, 28, TRAILER_DURATION - 64, TRAILER_DURATION - 8],
            [0, 0.5, 0.5, 0],
            clamp,
          )
        }
      />
    </Sequence>
    <Sequence from={START.trap + 125} durationInFrames={34} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/attack_melee_sword_first.wav")}
        volume={0.54}
      />
    </Sequence>
    <Sequence from={START.aoe + 110} durationInFrames={34} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/action_block.wav")}
        volume={0.42}
      />
    </Sequence>
    <Sequence from={START.umbra + 105} durationInFrames={34} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/attack_ranged_bow.wav")}
        volume={0.46}
      />
    </Sequence>
  </>
);

export const EscapeTheUmbraTrailer: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: PALETTE.ink }}>
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={SCENE.opening}>
        <OpeningScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.route}>
        <GameplayScene
          clip="route"
          duration={SCENE.route}
          headline="PLAN YOUR DESCENT"
          copyExitFrame={76}
          placement="right"
          accent="gold"
          zoom={1}
          vignetteOpacity={0.55}
          focusTrack={{
            frames: [0, 24, 58, 95, 132],
            scales: [1, 1, 1.03, 1.06, 1.06],
            translateX: [0, 70, 150, 250, 260],
            translateY: [0, -20, -65, -140, -150],
          }}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.prebattle}>
        <GameplayScene
          clip="prebattle"
          duration={SCENE.prebattle}
          headline="READ THE ROOM"
          copyExitFrame={110}
          accent="gold"
          zoom={1.025}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.trap}>
        <GameplayScene
          clip="trap_combo"
          duration={SCENE.trap}
          headline="USE THE LABYRINTH"
          copyExitFrame={54}
          accent="ember"
          camera={{
            cardFrame: 90,
            impactFrame: 125,
            cardFocusX: 50,
            cardFocusY: 59,
            actionFocusX: 51,
            actionFocusY: 44,
            cardZoom: 1.19,
            hitZoom: 1.2,
            settleZoom: 1.145,
            shake: 13,
          }}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.aoe}>
        <GameplayScene
          clip="aoe"
          duration={SCENE.aoe}
          headline="BUILD THE PERFECT TURN"
          copyExitFrame={60}
          accent="gold"
          camera={{
            cardFrame: 90,
            impactFrame: 110,
            cardFocusX: 50,
            cardFocusY: 59,
            actionFocusX: 51,
            actionFocusY: 44,
            cardZoom: 1.2,
            hitZoom: 1.21,
            settleZoom: 1.15,
            shake: 11,
          }}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.umbra}>
        <GameplayScene
          clip="umbra"
          duration={SCENE.umbra}
          headline="BRING LIGHT INTO THE UMBRA"
          copyExitFrame={62}
          accent="violet"
          camera={{
            cardFrame: 90,
            impactFrame: 105,
            cardFocusX: 50,
            cardFocusY: 59,
            actionFocusX: 51,
            actionFocusY: 42,
            cardZoom: 1.18,
            hitZoom: 1.17,
            settleZoom: 1.12,
            shake: 7,
          }}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.progression}>
        <ProgressionScene />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.final}>
        <FinalScene />
      </TransitionSeries.Sequence>
    </TransitionSeries>
    <ImpactFlash from={START.trap + 125} color="rgba(255,112,45,.78)" />
    <ImpactFlash from={START.aoe + 110} color="rgba(255,164,62,.72)" />
    <ImpactFlash from={START.umbra + 105} color="rgba(198,151,255,.48)" />
    <Soundtrack />
  </AbsoluteFill>
);
