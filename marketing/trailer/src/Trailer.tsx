import {Audio, Video} from "@remotion/media";
import {TransitionSeries, linearTiming} from "@remotion/transitions";
import {fade} from "@remotion/transitions/fade";
import type {CSSProperties, ReactNode} from "react";
import {
  AbsoluteFill,
  Img,
  Sequence,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
} from "remotion";

const FPS = 30;
const TRANSITION = 12;

const SCENE = {
  opening: 105,
  route: 195,
  prebattle: 210,
  trap: 180,
  aoe: 210,
  umbra: 210,
  reward: 175,
  final: 225,
} as const;

const START = {
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
  reward:
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
    SCENE.reward -
    TRANSITION * 7,
} as const;

export const TRAILER_DURATION = START.final + SCENE.final;

const PALETTE = {
  ink: "#0b080d",
  ember: "#f19a3e",
  gold: "#d7b85c",
  violet: "#a97cff",
} as const;

const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};

const fadeTiming = linearTiming({durationInFrames: TRANSITION});

const Vignette: React.FC = () => (
  <AbsoluteFill
    style={{
      pointerEvents: "none",
      boxShadow: "inset 0 0 220px 80px rgba(0,0,0,0.76)",
      background:
        "linear-gradient(180deg, rgba(7,4,9,0.42) 0%, transparent 24%, transparent 70%, rgba(6,3,8,0.62) 100%)",
    }}
  />
);

const FilmGrain: React.FC = () => {
  const frame = useCurrentFrame();
  const driftX = (frame * 17) % 96;
  const driftY = (frame * 11) % 96;

  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        opacity: 0.11,
        mixBlendMode: "screen",
        backgroundImage:
          "radial-gradient(circle at 20% 30%, rgba(255,255,255,.32) 0 1px, transparent 1.5px), radial-gradient(circle at 75% 65%, rgba(255,194,112,.26) 0 1px, transparent 1.5px)",
        backgroundSize: "43px 47px, 61px 59px",
        backgroundPosition: `${driftX}px ${driftY}px, ${-driftY}px ${driftX}px`,
      }}
    />
  );
};

const EmberField: React.FC<{opacity?: number}> = ({opacity = 1}) => {
  const frame = useCurrentFrame();
  const particles = Array.from({length: 24}, (_, index) => {
    const x = (index * 79 + 17) % 100;
    const phase = (index * 23) % 120;
    const y = 112 - ((frame * (0.09 + (index % 5) * 0.025) + phase) % 130);
    const size = 2 + (index % 4);
    const alpha = 0.22 + ((index * 19) % 55) / 100;
    return {x, y, size, alpha};
  });

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
            transform: `rotate(${index % 2 === 0 ? -14 : 11}deg)`,
          }}
        />
      ))}
    </AbsoluteFill>
  );
};

const EditorialFrame: React.FC<{children: ReactNode}> = ({children}) => (
  <AbsoluteFill style={{backgroundColor: PALETTE.ink}}>
    {children}
    <Vignette />
    <FilmGrain />
    <div className="edge-line edge-line-top" />
    <div className="edge-line edge-line-bottom" />
  </AbsoluteFill>
);

const RevealLine: React.FC<{
  children: ReactNode;
  from: number;
  style?: CSSProperties;
}> = ({children, from, style}) => {
  const frame = useCurrentFrame();
  const progress = spring({
    frame: frame - from,
    fps: FPS,
    config: {damping: 170, stiffness: 120, mass: 0.8},
    durationInFrames: 26,
  });
  const opacity = interpolate(frame, [from, from + 10], [0, 1], clamp);

  return (
    <div
      style={{
        opacity,
        transform: `translateY(${interpolate(progress, [0, 1], [34, 0])}px)`,
        ...style,
      }}
    >
      {children}
    </div>
  );
};

const OpeningScene: React.FC = () => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, SCENE.opening], [1.02, 1.085], clamp);
  const artOpacity = interpolate(frame, [0, 12, 92, 105], [0, 1, 1, 0.65], clamp);

  return (
    <EditorialFrame>
      <Img
        src={staticFile("game-assets/art/ui/main_menu_umbra_dragon.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          opacity: artOpacity,
          transform: `scale(${scale}) translateX(1.5%)`,
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(6,4,8,.94) 0%, rgba(6,4,8,.76) 31%, rgba(6,4,8,.16) 59%, rgba(6,4,8,.06) 100%)",
        }}
      />
      <div className="opening-copy">
        <RevealLine from={12}>
          <div className="eyebrow">THE WAY OUT IS BELOW</div>
        </RevealLine>
        <RevealLine from={27}>
          <div className="hook-line">THIS PRISON</div>
        </RevealLine>
        <RevealLine from={46}>
          <div className="hook-line hook-accent">HAS NO EXIT.</div>
        </RevealLine>
        <RevealLine from={67}>
          <div className="opening-sub">Only a way deeper.</div>
        </RevealLine>
      </div>
      <EmberField opacity={0.62} />
    </EditorialFrame>
  );
};

type CopyPlacement = "left" | "right" | "center";

type GameplaySceneProps = {
  clip: string;
  duration: number;
  trimBefore: number;
  eyebrow: string;
  headline: string;
  subline: string;
  placement?: CopyPlacement;
  zoom?: number;
  accent?: "ember" | "violet" | "gold";
};

const GameplayCopy: React.FC<{
  eyebrow: string;
  headline: string;
  subline: string;
  placement: CopyPlacement;
  accent: "ember" | "violet" | "gold";
}> = ({eyebrow, headline, subline, placement, accent}) => {
  const frame = useCurrentFrame();
  const enter = spring({
    frame: frame - 16,
    fps: FPS,
    config: {damping: 180, stiffness: 130, mass: 0.8},
    durationInFrames: 28,
  });
  const leave = interpolate(frame, [145, 172], [1, 0], clamp);
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
        opacity: enter * leave,
        transform: `translateY(${interpolate(enter, [0, 1], [30, 0])}px)`,
        borderColor: accentColor,
      }}
    >
      <div className="gameplay-eyebrow" style={{color: accentColor}}>
        {eyebrow}
      </div>
      <div className="gameplay-headline">{headline}</div>
      <div className="gameplay-subline">{subline}</div>
    </div>
  );
};

const GameplayScene: React.FC<GameplaySceneProps> = ({
  clip,
  duration,
  trimBefore,
  eyebrow,
  headline,
  subline,
  placement = "left",
  zoom = 1.04,
  accent = "ember",
}) => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, duration], [zoom, zoom + 0.025], clamp);

  return (
    <EditorialFrame>
      <Sequence durationInFrames={duration} premountFor={FPS}>
        <Video
          src={staticFile(`footage/${clip}.mp4`)}
          trimBefore={trimBefore}
          muted
          objectFit="cover"
          style={{
            width: "100%",
            height: "100%",
            transform: `scale(${scale})`,
          }}
        />
      </Sequence>
      <AbsoluteFill
        style={{
          background:
            placement === "right"
              ? "linear-gradient(90deg, transparent 40%, rgba(7,4,9,.18) 62%, rgba(7,4,9,.74) 100%)"
              : placement === "center"
                ? "linear-gradient(180deg, rgba(7,4,9,.30), transparent 34%, transparent 64%, rgba(7,4,9,.68))"
                : "linear-gradient(90deg, rgba(7,4,9,.72) 0%, rgba(7,4,9,.18) 33%, transparent 58%)",
        }}
      />
      <Sequence durationInFrames={duration} premountFor={FPS}>
        <GameplayCopy
          eyebrow={eyebrow}
          headline={headline}
          subline={subline}
          placement={placement}
          accent={accent}
        />
      </Sequence>
      <div className="gameplay-marker">
        <span>ESCAPE THE UMBRA</span>
        <span className="marker-dot">◆</span>
        <span>GAMEPLAY</span>
        <span className="marker-frame">{String(Math.min(frame, 999)).padStart(3, "0")}</span>
      </div>
    </EditorialFrame>
  );
};

const FinalScene: React.FC = () => {
  const frame = useCurrentFrame();
  const scale = interpolate(frame, [0, SCENE.final], [1.07, 1.015], clamp);
  const titleProgress = spring({
    frame: frame - 72,
    fps: FPS,
    config: {damping: 180, stiffness: 95, mass: 0.9},
    durationInFrames: 34,
  });
  const ctaOpacity = interpolate(frame, [132, 154], [0, 1], clamp);

  return (
    <EditorialFrame>
      <Img
        src={staticFile("game-assets/art/ui/main_menu_umbra_dragon.png")}
        style={{
          width: "100%",
          height: "100%",
          objectFit: "cover",
          transform: `scale(${scale})`,
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(5,3,8,.96) 0%, rgba(5,3,8,.84) 35%, rgba(5,3,8,.24) 61%, rgba(5,3,8,.06) 100%)",
        }}
      />
      <div className="final-copy">
        <RevealLine from={16}>
          <div className="final-promise">DEEP IN THE SHADOW</div>
        </RevealLine>
        <RevealLine from={34}>
          <div className="final-dragon">A DRAGON GUARDS THE ONLY WAY OUT.</div>
        </RevealLine>
        <div
          className="title-lockup"
          style={{
            opacity: titleProgress,
            transform: `translateY(${interpolate(titleProgress, [0, 1], [42, 0])}px) scale(${interpolate(titleProgress, [0, 1], [0.96, 1])})`,
          }}
        >
          <div className="title-escape">ESCAPE</div>
          <div className="title-umbra">THE UMBRA</div>
        </div>
        <div className="final-loop" style={{opacity: ctaOpacity}}>
          DESCEND&nbsp;&nbsp;◆&nbsp;&nbsp;FIGHT&nbsp;&nbsp;◆&nbsp;&nbsp;BUILD&nbsp;&nbsp;◆&nbsp;&nbsp;REPEAT
        </div>
        <div className="steam-cta" style={{opacity: ctaOpacity}}>
          WISHLIST ON STEAM
        </div>
      </div>
      <EmberField opacity={0.82} />
    </EditorialFrame>
  );
};

const ImpactFlash: React.FC<{from: number; color: string}> = ({from, color}) => (
  <Sequence from={from} durationInFrames={18} premountFor={8}>
    <ImpactFlashContents color={color} />
  </Sequence>
);

const ImpactFlashContents: React.FC<{color: string}> = ({color}) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 2, 8, 18], [0, 0.5, 0.13, 0], clamp);
  const scale = interpolate(frame, [0, 18], [0.72, 1.35], clamp);
  return (
    <AbsoluteFill
      style={{
        pointerEvents: "none",
        opacity,
        transform: `scale(${scale})`,
        background: `radial-gradient(circle at 52% 48%, ${color} 0%, transparent 56%)`,
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
            [0, 32, TRAILER_DURATION - 72, TRAILER_DURATION - 8],
            [0, 0.48, 0.48, 0],
            clamp,
          )
        }
      />
    </Sequence>
    <Sequence from={START.trap + 88} durationInFrames={36} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/attack_melee_sword_first.wav")}
        volume={0.48}
      />
    </Sequence>
    <Sequence from={START.aoe + 83} durationInFrames={36} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/action_block.wav")}
        volume={0.36}
      />
    </Sequence>
    <Sequence from={START.umbra + 112} durationInFrames={36} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/attack_ranged_bow.wav")}
        volume={0.42}
      />
    </Sequence>
    <Sequence from={START.reward + 42} durationInFrames={45} premountFor={FPS}>
      <Audio
        src={staticFile("game-assets/audio/sfx/ember_collect.wav")}
        volume={0.34}
      />
    </Sequence>
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
          trimBefore={18}
          eyebrow="DESCEND"
          headline="CHOOSE THE WAY DOWN"
          subline="Every door commits the route."
          accent="gold"
          zoom={1.015}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.prebattle}>
        <GameplayScene
          clip="prebattle"
          duration={SCENE.prebattle}
          trimBefore={30}
          eyebrow="PLAN"
          headline="READ THE ROOM"
          subline="Inspect threats. Change equipment. Enter on your terms."
          accent="gold"
          zoom={1.025}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.trap}>
        <GameplayScene
          clip="trap_combo"
          duration={SCENE.trap}
          trimBefore={10}
          eyebrow="CONTROL"
          headline="TURN THE LABYRINTH AGAINST THEM"
          subline="Push. Pull. Trigger the room."
          accent="ember"
          zoom={1.065}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.aoe}>
        <GameplayScene
          clip="aoe"
          duration={SCENE.aoe}
          trimBefore={20}
          eyebrow="COMBINE"
          headline="BUILD THE PERFECT TURN"
          subline="Raise intensity. Line them up. Erase the board."
          accent="gold"
          zoom={1.06}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.umbra}>
        <GameplayScene
          clip="umbra"
          duration={SCENE.umbra}
          trimBefore={10}
          eyebrow="REVEAL"
          headline="CARRY LIGHT INTO THE UMBRA"
          subline="What you cannot see can still kill you."
          accent="violet"
          zoom={1.065}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.reward}>
        <GameplayScene
          clip="reward"
          duration={SCENE.reward}
          trimBefore={8}
          eyebrow="ADAPT"
          headline="TAKE POWER. REBUILD."
          subline="Claim cards. Sharpen the next descent."
          accent="ember"
          zoom={1.035}
        />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition presentation={fade()} timing={fadeTiming} />
      <TransitionSeries.Sequence durationInFrames={SCENE.final}>
        <FinalScene />
      </TransitionSeries.Sequence>
    </TransitionSeries>
    <ImpactFlash from={START.trap + 94} color="rgba(255,112,45,.78)" />
    <ImpactFlash from={START.aoe + 87} color="rgba(255,232,96,.72)" />
    <ImpactFlash from={START.umbra + 89} color="rgba(198,151,255,.48)" />
    <Soundtrack />
  </AbsoluteFill>
);
