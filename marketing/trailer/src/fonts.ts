import {loadFont} from "@remotion/fonts";
import {staticFile} from "remotion";

export const HEADER_FONT = "Umbra Crumble Header";
export const BODY_FONT = "Umbra Crumble";
export const PIXEL_FONT = "Umbra Pixel";

void Promise.all([
  loadFont({
    family: HEADER_FONT,
    url: staticFile("game-fonts/LabyrinthCrumble-Header.ttf"),
    weight: "700",
    display: "block",
  }),
  loadFont({
    family: BODY_FONT,
    url: staticFile("game-fonts/LabyrinthCrumble-Regular.ttf"),
    weight: "400",
    display: "block",
  }),
  loadFont({
    family: PIXEL_FONT,
    url: staticFile("game-fonts/PressStart2P-Regular.ttf"),
    weight: "400",
    display: "block",
  }),
]);
