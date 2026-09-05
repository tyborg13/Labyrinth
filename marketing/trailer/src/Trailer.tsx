import { Audio, Video } from "@remotion/media";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
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
const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};
const ease = Easing.bezier(0.22, 1, 0.36, 1);

/** Source-frame cues are aligned to the encoded current-build captures, after pre-roll removal.
 * Keep source trims, playback speed, and sound cues together when recapturing. */
export const SHOTS = {
  trap: {
    clip: "trap_combo",
    frames: 159,
    sourceIn: 0,
    rate: 1,
    commit: 44,
    impact: 65,
  },
  umbra: {
    clip: "umbra",
    frames: 150,
    sourceIn: 0,
    rate: 1,
    commit: 44,
    impact: 61,
  },
  route: { clip: "route", frames: 96, sourceIn: 0, rate: 1 },
  relic: { clip: "relic", frames: 99, sourceIn: 0, rate: 1, selection: 60 },
  pickup: { clip: "equipment", frames: 60, sourceIn: 18, rate: 1 },
  equipment: {
    clip: "equipment",
    frames: 81,
    sourceIn: 108,
    rate: 0.8,
    selection: 126,
  },
  aoe: {
    clip: "aoe",
    frames: 159,
    sourceIn: 0,
    rate: 1,
    commit: 44,
    impact: 61,
  },
} as const;

const CHOICE_FADE = 6;
const END_FADE = 12;
const END_FRAMES = 153;
export const START = {
  trap: 0,
  umbra: SHOTS.trap.frames,
  route: SHOTS.trap.frames + SHOTS.umbra.frames,
  relic:
    SHOTS.trap.frames + SHOTS.umbra.frames + SHOTS.route.frames - CHOICE_FADE,
  pickup:
    SHOTS.trap.frames +
    SHOTS.umbra.frames +
    SHOTS.route.frames -
    CHOICE_FADE +
    SHOTS.relic.frames,
  equipment:
    SHOTS.trap.frames +
    SHOTS.umbra.frames +
    SHOTS.route.frames -
    CHOICE_FADE +
    SHOTS.relic.frames +
    SHOTS.pickup.frames,
  aoe:
    SHOTS.trap.frames +
    SHOTS.umbra.frames +
    SHOTS.route.frames -
    CHOICE_FADE +
    SHOTS.relic.frames +
    SHOTS.pickup.frames +
    SHOTS.equipment.frames,
  final:
    SHOTS.trap.frames +
    SHOTS.umbra.frames +
    SHOTS.route.frames -
    CHOICE_FADE +
    SHOTS.relic.frames +
    SHOTS.pickup.frames +
    SHOTS.equipment.frames +
    SHOTS.aoe.frames -
    END_FADE,
} as const;
export const TRAILER_DURATION = START.final + END_FRAMES;

type Shot = { clip: string; frames: number; sourceIn: number; rate: number };
const sourceCue = (shot: Shot, sourceFrame: number): number =>
  Math.round((sourceFrame - shot.sourceIn) / shot.rate);

const TitleArt: React.FC<{
  slug: string;
  alt: string;
  className?: string;
  enterAt?: number;
}> = ({ slug, alt, className = "", enterAt = 0 }) => {
  const frame = useCurrentFrame();
  return (
    <Img
      src={staticFile(`title-cards/${slug}.png`)}
      alt={alt}
      className={className}
      style={{
        opacity: interpolate(frame, [enterAt, enterAt + 10], [0, 1], clamp),
        transform: `translateY(${interpolate(frame, [enterAt, enterAt + 20], [12, 0], { ...clamp, easing: ease })}px)`,
      }}
    />
  );
};

const Caption: React.FC<{
  lines: readonly [string, string][];
  exitAt: number;
  right?: boolean;
}> = ({ lines, exitAt, right = false }) => {
  const frame = useCurrentFrame();
  return (
    <div
      className={`shot-caption${right ? " shot-caption-right" : ""}`}
      style={{
        opacity: interpolate(frame, [exitAt, exitAt + 10], [1, 0], clamp),
      }}
    >
      {lines.map(([slug, alt], index) => (
        <TitleArt
          key={slug}
          slug={slug}
          alt={alt}
          className="shot-caption-line"
          enterAt={3 + index * 3}
        />
      ))}
    </div>
  );
};

/** The native HUD has a ten-pixel edge margin. Keep the exact production frame:
 * even a small global push crops room text and moves control edges out of view. */
const Gameplay: React.FC<{ shot: Shot; children?: React.ReactNode }> = ({
  shot,
  children,
}) => (
  <AbsoluteFill style={{ background: "#08060a", overflow: "hidden" }}>
    <Video
      src={staticFile(`footage/${shot.clip}.mp4`)}
      trimBefore={shot.sourceIn}
      playbackRate={shot.rate}
      muted
      objectFit="contain"
      style={{ width: "100%", height: "100%" }}
    />
    {children}
  </AbsoluteFill>
);

const EndCard: React.FC = () => {
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{ background: "#08060a" }}>
      <Img
        src={staticFile("game-assets/art/ui/main_menu_umbra_dragon.png")}
        className="end-art"
        style={{
          transform: `scale(${interpolate(frame, [0, END_FRAMES], [1.025, 1.055], clamp)})`,
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "linear-gradient(90deg, rgba(6,4,9,.96) 0%, rgba(6,4,9,.85) 35%, rgba(6,4,9,.28) 64%, rgba(6,4,9,.02) 100%)",
        }}
      />
      <div className="title-lockup">
        <TitleArt
          slug="escape"
          alt="ESCAPE"
          className="title-escape-art"
          enterAt={3}
        />
        <TitleArt
          slug="the-umbra"
          alt="THE UMBRA"
          className="title-umbra-art"
          enterAt={6}
        />
      </div>
      <div
        className="steam-cta"
        style={{ opacity: interpolate(frame, [14, 24], [0, 1], clamp) }}
      >
        <Img
          src={staticFile("title-cards/wishlist-on.png")}
          alt="WISHLIST ON"
          className="steam-cta-copy"
        />
        <Img
          src={staticFile("branding/steam-logo-inverse-transparent.png")}
          alt="Steam"
          className="steam-logo"
        />
      </div>
    </AbsoluteFill>
  );
};

const Effect: React.FC<{
  from: number;
  file: string;
  volume: number;
  frames?: number;
}> = ({ from, file, volume, frames = 42 }) => (
  <Sequence from={from} durationInFrames={frames} premountFor={FPS}>
    <Audio
      src={staticFile(`game-assets/audio/sfx/${file}.wav`)}
      volume={volume}
    />
  </Sequence>
);

const Soundtrack: React.FC = () => (
  <>
    <Audio
      src={staticFile("game-assets/audio/music/zekarion_boss.wav")}
      trimBefore={FPS * 5}
      volume={(frame) =>
        interpolate(
          frame,
          [0, 6, TRAILER_DURATION - 24, TRAILER_DURATION],
          [0.38, 0.46, 0.46, 0],
          clamp,
        )
      }
    />
    <Effect
      from={START.trap + sourceCue(SHOTS.trap, SHOTS.trap.commit)}
      file="card_play_take"
      volume={0.5}
      frames={24}
    />
    <Effect
      from={START.trap + sourceCue(SHOTS.trap, SHOTS.trap.impact)}
      file="elemental/fire_attack"
      volume={0.62}
    />
    <Effect
      from={START.umbra + sourceCue(SHOTS.umbra, SHOTS.umbra.commit)}
      file="card_play_take"
      volume={0.42}
      frames={24}
    />
    <Effect
      from={START.umbra + sourceCue(SHOTS.umbra, SHOTS.umbra.impact)}
      file="attack_ranged_bow"
      volume={0.5}
    />
    <Effect
      from={
        START.equipment + sourceCue(SHOTS.equipment, SHOTS.equipment.selection)
      }
      file="item_equip"
      volume={0.26}
      frames={30}
    />
    <Effect
      from={START.aoe + sourceCue(SHOTS.aoe, SHOTS.aoe.commit)}
      file="card_play_take"
      volume={0.45}
      frames={24}
    />
    <Effect
      from={START.aoe + sourceCue(SHOTS.aoe, SHOTS.aoe.impact)}
      file="elemental/fire_attack"
      volume={0.66}
    />
  </>
);

/** A complete tactical payoff opens the trailer. Darkness, choices, and a bigger
 * payoff build on that promise; the title and wishlist remain legible together. */
export const EscapeTheUmbraTrailer: React.FC = () => (
  <AbsoluteFill style={{ background: "#08060a" }}>
    <TransitionSeries>
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.trap.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.trap}>
          <Caption
            lines={[
              ["turn-the-room", "TURN THE ROOM"],
              ["against-them", "AGAINST THEM"],
            ]}
            exitAt={40}
          />
        </Gameplay>
      </TransitionSeries.Sequence>
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.umbra.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.umbra}>
          <Caption lines={[["fight-the-dark", "FIGHT THE DARK"]]} exitAt={40} />
        </Gameplay>
      </TransitionSeries.Sequence>
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.route.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.route}>
          <Caption lines={[["go-deeper", "GO DEEPER"]]} exitAt={76} right />
        </Gameplay>
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: CHOICE_FADE })}
      />
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.relic.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.relic} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.pickup.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.pickup} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.equipment.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.equipment} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Sequence
        durationInFrames={SHOTS.aoe.frames}
        premountFor={FPS}
      >
        <Gameplay shot={SHOTS.aoe} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        presentation={fade()}
        timing={linearTiming({ durationInFrames: END_FADE })}
      />
      <TransitionSeries.Sequence
        durationInFrames={END_FRAMES}
        premountFor={FPS}
      >
        <EndCard />
      </TransitionSeries.Sequence>
    </TransitionSeries>
    <Soundtrack />
  </AbsoluteFill>
);
