import {Composition} from "remotion";
import {EscapeTheUmbraTrailer, TRAILER_DURATION} from "./Trailer";

export const TrailerComposition: React.FC = () => {
  return (
    <Composition
      id="EscapeTheUmbraTrailer"
      component={EscapeTheUmbraTrailer}
      durationInFrames={TRAILER_DURATION}
      fps={30}
      width={1920}
      height={1080}
    />
  );
};
