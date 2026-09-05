import {Config} from "@remotion/cli/config";

// Preserve the captured room's shadow detail through compositing and encode a
// declared Rec.709 limited-range master for consistent playback/transcoding.
Config.setVideoImageFormat("png");
Config.setColorSpace("bt709");
Config.setOverwriteOutput(true);
Config.setPixelFormat("yuv420p");

// Remotion's pre-encoded H.264 path retains the matrix/range but can omit
// primaries and transfer from the bitstream. Declare them during the final mux;
// h264_metadata changes only headers, without re-encoding the picture samples.
Config.overrideFfmpegCommand(({type, args}) => {
  if (type !== "stitcher") return args;
  return [
    ...args.slice(0, -1),
    "-bsf:v",
    "h264_metadata=video_full_range_flag=0:colour_primaries=1:transfer_characteristics=1:matrix_coefficients=1",
    args[args.length - 1],
  ];
});
