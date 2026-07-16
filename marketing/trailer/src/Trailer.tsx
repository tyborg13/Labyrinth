import {Audio, Video} from "@remotion/media";
import {TransitionSeries, linearTiming} from "@remotion/transitions";
import {fade} from "@remotion/transitions/fade";
import type {ReactNode} from "react";
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
const TRANSITION = 8;
const PROGRESSION_TRANSITION = 5;

const PROGRESSION_CLIP = {
  merchant: 60,
  relic: 78,
  spell: 78,
  equipment: 126,
} as const;

const PROGRESSION_START = {
  merchant: 0,
  relic: PROGRESSION_CLIP.merchant - PROGRESSION_TRANSITION,
  spell:
    PROGRESSION_CLIP.merchant +
    PROGRESSION_CLIP.relic -
    PROGRESSION_TRANSITION * 2,
  equipment:
    PROGRESSION_CLIP.merchant +
    PROGRESSION_CLIP.relic +
    PROGRESSION_CLIP.spell -
    PROGRESSION_TRANSITION * 3,
} as const;

const PROGRESSION_DURATION =
  PROGRESSION_START.equipment + PROGRESSION_CLIP.equipment;

const SCENE = {
  opening: 90,
  route: 100,
  prebattle: 108,
  trap: 136,
  aoe: 145,
  umbra: 155,
  progression: PROGRESSION_DURATION,
  final: 180,
} as const;

const START = {
  opening: 0,
  route: SCENE.opening - TRANSITION,
  prebattle: SCENE.opening + SCENE.route - TRANSITION * 2,
  trap:
    SCENE.opening + SCENE.route + SCENE.prebattle - TRANSITION * 3,
  aoe:
    SCENE.opening +
    SCENE.route +
    SCENE.prebattle +
    SCENE.trap -
    TRANSITION * 4,
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

const fadeTiming = linearTiming({durationInFrames: TRANSITION});
const progressionFadeTiming = linearTiming({
  durationInFrames: PROGRESSION_TRANSITION,
});

const Vignette: React.FC = () => (
  <AbsoluteFill
    style={{
      pointerEvents: "none",
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

const EmberField: React.FC<{opacity?: number}> = ({opacity = 1}) => {
  const frame = useCurrentFrame();
  const particles = Array.from({length: 24}, (_, index) => ({
    x: (index * 79 + 17) % 100,
    y:
      112 -
      ((frame * (0.09 + (index % 5) * 0.025) + (index * 23) % 120) %
        130),
    size: 2 + (index % 4),
    alpha: 0.22 + ((index * 19) % 55) / 100,
  }));

  return (
    <AbsoluteFill style={{pointerEvents: "none", opacity}}>
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

const EditorialFrame: React.FC<{children: ReactNode}> = ({children}) => (
  <AbsoluteFill style={{backgroundColor: PALETTE.ink, overflow: "hidden"}}>
    {children}
    <Vignette />
    <FilmGrain />
  </AbsoluteFill>
);

const CrumbledRule: React.FC = () => (
  <div className="crumbled-rule" aria-hidden="true">
    <span />
    <span />
    <span />
    <span />
  </div>
);

const TITLE_CARD: Record<string, string> = {
  "PLAN YOUR DESCENT": "plan-your-descent",
  "READ THE ROOM": "read-the-room",
  "USE THE LABYRINTH": "use-the-labyrinth",
  "BUILD THE PERFECT TURN": "build-the-perfect-turn",
  "BRING LIGHT INTO THE UMBRA": "bring-light-into-the-umbra",
  "GROW STRONGER": "grow-stronger",
};

const TitleArt: React.FC<{
  slug: string;
  alt: string;
  className: string;
}> = ({slug, alt, className}) => (
  <Img
    src={staticFile(`title-cards/${slug}.png`)}
    className={className}
    alt={alt}
  />
);

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
          opacity: interpolate(frame, [0, 10, 76, 90], [0, 1, 1, 0.76], clamp),
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
          opacity: interpolate(frame, [11, 20, 72, 84], [0, 1, 1, 0], clamp),
          translate: `0 ${interpolate(frame, [11, 25], [38, 0], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          })}px`,
        }}
      >
        <TitleArt
          slug="this-prison"
          alt="THIS PRISON"
          className="opening-line-art"
        />
        <TitleArt
          slug="has-no-exit"
          alt="HAS NO EXIT"
          className="opening-line-art opening-accent-art"
        />
        <CrumbledRule />
      </div>
      <EmberField opacity={0.58} />
    </EditorialFrame>
  );
};

type CopyPlacement = "left" | "right" | "center";

type CameraCue = {
  impactFrame: number;
  focusX: number;
  focusY: number;
  hitZoom: number;
  settleZoom: number;
  shake: number;
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
};

const GameplayTitle: React.FC<{
  headline: string;
  copyExitFrame: number;
  placement: CopyPlacement;
  accent: "ember" | "violet" | "gold";
}> = ({headline, copyExitFrame, placement, accent}) => {
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
          [10, 18, copyExitFrame, copyExitFrame + 12],
          [0, 1, 1, 0],
          clamp,
        ),
        translate: `0 ${interpolate(frame, [10, 24], [32, 0], {
          ...clamp,
          easing: Easing.bezier(0.16, 1, 0.3, 1),
        })}px`,
        color: accentColor,
      }}
    >
      <TitleArt
        slug={TITLE_CARD[headline]}
        alt={headline}
        className="gameplay-headline-art"
      />
      <CrumbledRule />
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
}) => {
  const frame = useCurrentFrame();
  const scale = camera
    ? interpolate(
        frame,
        [
          0,
          camera.impactFrame - 28,
          camera.impactFrame - 4,
          camera.impactFrame + 2,
          camera.impactFrame + 12,
          camera.impactFrame + 34,
          duration,
        ],
        [
          zoom,
          zoom + 0.014,
          camera.hitZoom - 0.035,
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
  const shakeEnvelope = camera
    ? interpolate(
        frame,
        [camera.impactFrame - 2, camera.impactFrame + 2, camera.impactFrame + 18],
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
  const impactLight = camera
    ? interpolate(
        frame,
        [camera.impactFrame - 2, camera.impactFrame + 1, camera.impactFrame + 10],
        [1, 1.2, 1],
        clamp,
      )
    : 1;

  return (
    <EditorialFrame>
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
            translate: `${shakeX}px ${shakeY}px`,
            transformOrigin: camera
              ? `${camera.focusX}% ${camera.focusY}%`
              : "50% 50%",
            filter: `brightness(${impactLight}) saturate(${1.03 + (impactLight - 1) * 0.8})`,
          }}
        />
      </Sequence>
      <AbsoluteFill
        style={{
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
  clip: "merchant" | "relic" | "spell" | "equipment";
  duration: number;
  playbackRate: number;
  focus: string;
}> = ({clip, duration, playbackRate, focus}) => {
  const frame = useCurrentFrame();
  return (
    <EditorialFrame>
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
            scale: interpolate(frame, [0, duration], [1.012, 1.042], {
              ...clamp,
              easing: Easing.bezier(0.45, 0, 0.55, 1),
            }),
            transformOrigin: focus,
          }}
        />
      </Sequence>
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(180deg, rgba(5,3,7,.20), transparent 28%, transparent 70%, rgba(5,3,7,.36))",
        }}
      />
    </EditorialFrame>
  );
};

const ProgressionScene: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{backgroundColor: PALETTE.ink, overflow: "hidden"}}>
      <TransitionSeries>
        <TransitionSeries.Sequence
          durationInFrames={PROGRESSION_CLIP.merchant}
        >
          <ProgressionClip
            clip="merchant"
            duration={PROGRESSION_CLIP.merchant}
            playbackRate={1.25}
            focus="50% 62%"
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
            playbackRate={1.35}
            focus="50% 64%"
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
            playbackRate={1.35}
            focus="50% 66%"
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
            playbackRate={1.35}
            focus="50% 54%"
          />
        </TransitionSeries.Sequence>
      </TransitionSeries>
      <div
        className="progression-copy"
        style={{
          opacity: interpolate(frame, [7, 15, 48, 60], [0, 1, 1, 0], clamp),
          translate: `0 ${interpolate(frame, [7, 20], [28, 0], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          })}px`,
        }}
      >
        <TitleArt
          slug={TITLE_CARD["GROW STRONGER"]}
          alt="GROW STRONGER"
          className="gameplay-headline-art"
        />
        <CrumbledRule />
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
          scale: interpolate(frame, [0, SCENE.final], [1.075, 1.018], {
            ...clamp,
            easing: Easing.bezier(0.45, 0, 0.55, 1),
          }),
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(4,3,6,.97) 0%, rgba(4,3,6,.82) 34%, rgba(4,3,6,.20) 66%, transparent 100%)",
        }}
      />
      <div
        className="dragon-objective"
        style={{
          opacity: interpolate(frame, [10, 20, 66, 78], [0, 1, 1, 0], clamp),
          translate: `0 ${interpolate(frame, [10, 24], [30, 0], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          })}px`,
        }}
      >
        <TitleArt
          slug="shadow-dragon-waits-below"
          alt="THE SHADOW DRAGON WAITS BELOW"
          className="dragon-objective-art"
        />
        <CrumbledRule />
      </div>
      <div
        className="title-lockup"
        style={{
          opacity: interpolate(frame, [76, 94], [0, 1], clamp),
          translate: `0 ${interpolate(frame, [76, 98], [44, 0], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          })}px`,
          scale: interpolate(frame, [76, 102], [0.95, 1], {
            ...clamp,
            easing: Easing.bezier(0.16, 1, 0.3, 1),
          }),
        }}
      >
        <TitleArt slug="escape" alt="ESCAPE" className="title-escape-art" />
        <TitleArt
          slug="the-umbra"
          alt="THE UMBRA"
          className="title-umbra-art"
        />
      </div>
      <div
        className="steam-cta"
        style={{opacity: interpolate(frame, [112, 132], [0, 1], clamp)}}
      >
        <div className="steam-cta-copy">
          <TitleArt
            slug="wishlist-now-on"
            alt="WISHLIST NOW ON"
            className="steam-cta-art"
          />
          <CrumbledRule />
        </div>
        <Img
          src={staticFile("branding/steam-logo-inverse-transparent.png")}
          className="steam-logo"
          alt="Steam"
        />
      </div>
      <EmberField opacity={0.8} />
    </EditorialFrame>
  );
};

const ImpactFlash: React.FC<{from: number; color: string}> = ({from, color}) => (
  <Sequence from={from} durationInFrames={16} premountFor={8}>
    <ImpactFlashContents color={color} />
  </Sequence>
);

const ImpactFlashContents: React.FC<{color: string}> = ({color}) => {
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
    <Sequence from={START.trap + 68} durationInFrames={34} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/attack_melee_sword_first.wav")}
        volume={0.54}
      />
    </Sequence>
    <Sequence from={START.aoe + 75} durationInFrames={34} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/action_block.wav")}
        volume={0.42}
      />
    </Sequence>
    <Sequence from={START.umbra + 106} durationInFrames={34} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/attack_ranged_bow.wav")}
        volume={0.46}
      />
    </Sequence>
    {[36, 92, 165, 236].map((offset) => (
      <Sequence
        key={offset}
        from={START.progression + offset}
        durationInFrames={34}
        premountFor={FPS}
      >
        <Audio
          src={staticFile("game-assets/audio/sfx/ember_collect.wav")}
          volume={0.24}
        />
      </Sequence>
    ))}
  </>
);

export const EscapeTheUmbraTrailer: React.FC = () => (
  <AbsoluteFill style={{backgroundColor: PALETTE.ink}}>
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
          copyExitFrame={80}
          accent="gold"
          zoom={1.018}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.prebattle}>
        <GameplayScene
          clip="prebattle"
          duration={SCENE.prebattle}
          headline="READ THE ROOM"
          copyExitFrame={72}
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
          copyExitFrame={52}
          accent="ember"
          camera={{
            impactFrame: 71,
            focusX: 51,
            focusY: 47,
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
          copyExitFrame={56}
          accent="gold"
          camera={{
            impactFrame: 78,
            focusX: 50,
            focusY: 47,
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
          copyExitFrame={58}
          accent="violet"
          camera={{
            impactFrame: 70,
            focusX: 51,
            focusY: 44,
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
    <ImpactFlash from={START.trap + 71} color="rgba(255,112,45,.78)" />
    <ImpactFlash from={START.aoe + 78} color="rgba(255,232,96,.72)" />
    <ImpactFlash from={START.umbra + 70} color="rgba(198,151,255,.48)" />
    <Soundtrack />
  </AbsoluteFill>
);
