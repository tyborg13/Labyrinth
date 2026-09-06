import { Audio } from "@remotion/media";
import { NativeGameplay, gameplayAudioPath } from "./NativeSource";
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
// Uniform gain preserves the native SFX/music balance with measured peak headroom.
const MASTER_GAIN = 1.5;
const clamp = {
  extrapolateLeft: "clamp" as const,
  extrapolateRight: "clamp" as const,
};
const ease = Easing.bezier(0.22, 1, 0.36, 1);

/** All cues are encoded-source frames, after measured capture pre-roll removal.
 * Actions stay at natural speed. Camera keys change framing, never game timing. */
export const ORDER = [
  "setup",
  "reward",
  "route",
  "shop",
  "equipment",
  "storm",
] as const;
export type ShotKey = (typeof ORDER)[number];
export type CameraKey = { frame: number; scale: number; x: number; y: number };
export type Shot = {
  clip: string;
  frames: number;
  sourceIn: number;
  audioTail: number;
  cues?: Readonly<Record<string, number>>;
  camera?: readonly CameraKey[];
};
export const SHOTS: Record<ShotKey, Shot> = {
  setup: { clip: "push_bloom", frames: 352, sourceIn: 0, audioTail: 0 },
  reward: { clip: "spell", frames: 138, sourceIn: 0, audioTail: 90 },
  route: { clip: "route", frames: 42, sourceIn: 8, audioTail: 0 },
  shop: { clip: "merchant", frames: 126, sourceIn: 0, audioTail: 90 },
  equipment: {
    clip: "equipment",
    frames: 93,
    sourceIn: 97,
    audioTail: 0,
    camera: [
      { frame: 97, scale: 1.08, x: 0, y: 0 },
      { frame: 190, scale: 1.08, x: 0, y: 0 },
    ],
  },
  storm: {
    clip: "root_chain",
    frames: 348,
    sourceIn: 0,
    audioTail: 15,
    camera: [
      { frame: 0, scale: 1, x: 0, y: 0 },
      { frame: 244, scale: 1, x: 0, y: 0 },
      { frame: 265, scale: 1.6, x: 0, y: 235 },
      { frame: 348, scale: 1.6, x: 0, y: 235 },
    ],
  },
};
export const END_FADE = 12;
export const END_FRAMES = 132;
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

/** The board stays stable while the player positions. A few authored camera
 * keys can bring a decisive consequence closer after its card/target is clear. */
const Gameplay: React.FC<{ shot: Shot; children?: React.ReactNode }> = ({
  shot,
  children,
}) => {
  const frame = useCurrentFrame() + shot.sourceIn;
  const keys = shot.camera;
  const cameraValue = (property: "scale" | "x" | "y", fallback: number) =>
    keys && keys.length > 1
      ? interpolate(
          frame,
          keys.map((key) => key.frame),
          keys.map((key) => key[property]),
          { ...clamp, easing: Easing.inOut(Easing.cubic) },
        )
      : fallback;
  return (
    <AbsoluteFill style={{ background: "#08060a", overflow: "hidden" }}>
      <AbsoluteFill
        style={{
          transform: `translate(${cameraValue("x", 0)}px, ${cameraValue("y", 0)}px) scale(${cameraValue("scale", 1)})`,
        }}
      >
        <NativeGameplay clip={shot.clip} sourceIn={shot.sourceIn} />
      </AbsoluteFill>
      {children}
    </AbsoluteFill>
  );
};

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

/** Native captured SFX share the video's exact source trim and clock. Only
 * music was muted in capture. Short natural tails can continue over a cut;
 * no attack, card or purchase sound is reconstructed from an asset table. */
const SourceSound: React.FC<{ shot: Shot }> = ({ shot }) => {
  const frame = useCurrentFrame();
  const frames = shot.frames + shot.audioTail;
  const volume = interpolate(
    frame,
    [0, 2, frames - 8, frames],
    [0, MASTER_GAIN, MASTER_GAIN, 0],
    clamp,
  );
  return (
    <Audio
      src={gameplayAudioPath(shot.clip)}
      trimBefore={shot.sourceIn}
      volume={volume}
    />
  );
};
const Soundtrack: React.FC = () => (
  <>
    <Audio
      src={staticFile("game-assets/audio/music/zekarion_boss.wav")}
      trimBefore={FPS * 5}
      volume={(frame) =>
        MASTER_GAIN *
        interpolate(
          frame,
          [0, 8, TRAILER_DURATION - 30, TRAILER_DURATION],
          [0.32, 0.4, 0.4, 0],
          clamp,
        )
      }
    />
    {ORDER.map((key) => (
      <Sequence
        key={key}
        from={START[key]}
        durationInFrames={SHOTS[key].frames + SHOTS[key].audioTail}
        premountFor={FPS}
      >
        <SourceSound shot={SHOTS[key]} />
      </Sequence>
    ))}
  </>
);

const shotCaption = (key: ShotKey): React.ReactNode => {
  switch (key) {
    case "setup":
      return (
        <Caption
          lines={[
            ["every-move", "EVERY MOVE"],
            ["sets-up-the-next", "SETS UP THE NEXT"],
          ]}
          exitAt={34}
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
    case "shop":
      return (
        <Caption
          lines={[["shape-your-run", "SHAPE YOUR RUN"]]}
          menu
          exitAt={26}
        />
      );
    case "storm":
      return (
        <Caption lines={[["fight-the-dark", "FIGHT THE DARK"]]} exitAt={34} />
      );
    default:
      return null;
  }
};

/** Two continuous tactical stories surround the run-building decisions. */
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
