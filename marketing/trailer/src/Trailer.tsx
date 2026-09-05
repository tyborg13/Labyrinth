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

/** Cues refer to encoded source frames, after capture pre-roll removal. Later
 * combat beats trim repeated aiming lead-in; every play and result stays real.
 * `impact` locates the sound at the first authored effect, not necessarily HP
 * loss: Root Snare cracks begin65, travel68–72, and damage/light arrive73. */
export const SHOTS = {
  trap: {
    clip: "trap_combo",
    frames: 108,
    sourceIn: 0,
    rate: 1,
    commit: 44,
    impact: 65,
  },
  reward: { clip: "spell", frames: 126, sourceIn: 0, rate: 1, selection: 77 },
  umbra: {
    clip: "umbra",
    frames: 102,
    sourceIn: 0,
    rate: 1,
    commit: 44,
    impact: 61,
  },
  route: { clip: "route", frames: 45, sourceIn: 12, rate: 1 },
  shop: { clip: "merchant", frames: 114, sourceIn: 0, rate: 1, selection: 64 },
  equipment: {
    clip: "equipment",
    frames: 66,
    sourceIn: 108,
    rate: 0.8,
    selection: 126,
  },
  air: {
    clip: "air",
    frames: 81,
    sourceIn: 18,
    rate: 1,
    commit: 44,
    impact: 63,
  },
  earth: {
    clip: "earth",
    frames: 84,
    sourceIn: 18,
    rate: 1,
    commit: 44,
    impact: 65,
  },
  lightning: {
    clip: "lightning",
    frames: 85,
    sourceIn: 18,
    rate: 1,
    commit: 44,
    impact: 57,
  },
} as const;

const ORDER = [
  "trap",
  "reward",
  "umbra",
  "route",
  "shop",
  "equipment",
  "air",
  "earth",
  "lightning",
] as const;
const END_FADE = 12;
const END_FRAMES = 132;
type ShotKey = (typeof ORDER)[number];
const shotStarts = (): Record<ShotKey | "final", number> => {
  const starts = {} as Record<ShotKey | "final", number>;
  let cursor = 0;
  for (const key of ORDER) {
    starts[key] = cursor;
    cursor += SHOTS[key].frames;
  }
  starts.final = cursor - END_FADE;
  return starts;
};
export const START = shotStarts();
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
        opacity: interpolate(frame, [enterAt, enterAt + 5], [0, 1], clamp),
        transform: `translateY(${interpolate(frame, [enterAt, enterAt + 14], [14, 0], { ...clamp, easing: ease })}px)`,
      }}
    />
  );
};

/** Large, horizontally centered copy is readable at a 390px phone width. The
 * combat title clears before the real center-card play. The reward title sits
 * above the cards; the shop title clears within its first second of browsing. */
const Caption: React.FC<{
  lines: readonly [string, string][];
  exitAt?: number;
  menu?: boolean;
}> = ({ lines, exitAt = 34, menu = false }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [exitAt, exitAt + 9], [1, 0], clamp);
  return (
    <AbsoluteFill
      className={menu ? "caption-layer caption-layer-menu" : "caption-layer"}
      style={{ opacity }}
    >
      <div className="caption-scrim" />
      <div className="shot-caption">
        {lines.map(([slug, alt], index) => (
          <TitleArt
            key={slug}
            slug={slug}
            alt={alt}
            className="shot-caption-line"
            enterAt={index * 2}
          />
        ))}
      </div>
    </AbsoluteFill>
  );
};

/** Keep the exact production frame: the native HUD has a ten-pixel edge margin. */
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
          transform: `scale(${interpolate(frame, [0, END_FRAMES], [1.025, 1.05], clamp)})`,
        }}
      />
      <AbsoluteFill
        style={{
          background:
            "radial-gradient(ellipse at 50% 49%, rgba(6,4,9,.88) 0%, rgba(6,4,9,.65) 43%, rgba(6,4,9,.2) 100%)",
        }}
      />
      <div className="title-lockup">
        <TitleArt
          slug="escape"
          alt="ESCAPE"
          className="title-escape-art"
          enterAt={2}
        />
        <TitleArt
          slug="the-umbra"
          alt="THE UMBRA"
          className="title-umbra-art"
          enterAt={4}
        />
      </div>
      <div
        className="steam-cta"
        style={{ opacity: interpolate(frame, [10, 18], [0, 1], clamp) }}
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

const COMBAT_SOUNDS = [
  ["trap", "elemental/fire_attack", 0.62],
  ["umbra", "attack_ranged_bow", 0.5],
  ["air", "elemental/air_attack", 0.59],
  ["earth", "elemental/earth_attack", 0.66],
  ["lightning", "elemental/lightning_attack", 0.63],
] as const;

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
    {COMBAT_SOUNDS.map(([key, sound, volume]) => (
      <Sequence key={key} from={START[key]}>
        <Effect
          from={sourceCue(SHOTS[key], SHOTS[key].commit)}
          file="card_play_take"
          volume={0.45}
          frames={24}
        />
        <Effect
          from={sourceCue(SHOTS[key], SHOTS[key].impact)}
          file={sound}
          volume={volume}
        />
      </Sequence>
    ))}
    <Effect
      from={START.reward + sourceCue(SHOTS.reward, SHOTS.reward.selection)}
      file="reward_collect"
      volume={0.28}
      frames={30}
    />
    <Effect
      from={START.shop + sourceCue(SHOTS.shop, SHOTS.shop.selection)}
      file="reward_collect"
      volume={0.24}
      frames={30}
    />
    <Effect
      from={
        START.equipment + sourceCue(SHOTS.equipment, SHOTS.equipment.selection)
      }
      file="item_equip"
      volume={0.26}
      frames={30}
    />
  </>
);

const shotCaption = (key: ShotKey): React.ReactNode => {
  switch (key) {
    case "trap":
      return (
        <Caption
          lines={[
            ["turn-the-room", "TURN THE ROOM"],
            ["against-them", "AGAINST THEM"],
          ]}
        />
      );
    case "reward":
      return (
        <Caption
          lines={[["build-your-deck", "BUILD YOUR DECK"]]}
          menu
          exitAt={40}
        />
      );
    case "umbra":
      return <Caption lines={[["fight-the-dark", "FIGHT THE DARK"]]} />;
    case "shop":
      return (
        <Caption
          lines={[["shape-your-run", "SHAPE YOUR RUN"]]}
          menu
          exitAt={22}
        />
      );
    default:
      return null;
  }
};

/** One tactical payoff leads to reward choice, darkness, and the shop. A quick
 * elemental run then shows push, earth, and chain attacks without inert tails. */
export const EscapeTheUmbraTrailer: React.FC = () => (
  <AbsoluteFill style={{ background: "#08060a" }}>
    <TransitionSeries>
      {ORDER.map((key) => (
        <TransitionSeries.Sequence
          key={key}
          durationInFrames={SHOTS[key].frames}
          premountFor={FPS}
        >
          <Gameplay shot={SHOTS[key]}>{shotCaption(key)}</Gameplay>
        </TransitionSeries.Sequence>
      ))}
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
