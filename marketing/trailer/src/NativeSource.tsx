import {Video} from "@remotion/media";
import {getInputProps, Img, staticFile, useCurrentFrame} from "remotion";

/** Optional native RGB source path. The approved edit, source frame numbers,
 * camera keys and soundtrack gains are shared with the ordinary MP4 preview. */
const nativeRoot = (): string | null => {
  const root = getInputProps().nativeSourceRoot;
  return typeof root === "string" && root.length > 0 ? root : null;
};

export const gameplayAudioPath = (clip: string): string => {
  const root = nativeRoot();
  return staticFile(root ? `${root}/${clip}.wav` : `footage/${clip}.mp4`);
};

export const NativeGameplay: React.FC<{clip: string; sourceIn: number}> = ({clip, sourceIn}) => {
  const frame = useCurrentFrame() + sourceIn;
  const root = nativeRoot();
  if (root) {
    return <Img
      src={staticFile(`${root}/${clip}/frame${String(frame).padStart(8, "0")}.png`)}
      style={{width: "100%", height: "100%", objectFit: "contain"}}
    />;
  }
  return <Video
    src={staticFile(`footage/${clip}.mp4`)}
    trimBefore={sourceIn}
    muted
    objectFit="contain"
    style={{width: "100%", height: "100%"}}
  />;
};
