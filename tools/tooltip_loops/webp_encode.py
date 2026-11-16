"""Offline libwebp near-lossless encoder, using the existing Pillow libwebp.

ABI declarations follow libwebp src/webp/encode.h (encoder ABI 0x0210).
No encoder is loaded by the game; it uses Godot's buffer decoder.
"""
import ctypes as C
import ctypes.util
from pathlib import Path
from PIL import _webp

ABI_VERSION = 0x0210
ENCODER_METHOD = 6  # Offline compression effort; pixels are gated independently.
ENCODER_QUALITY = 100.0


class Config(C.Structure):
    _fields_ = [(name, C.c_float if name in ("quality", "target_PSNR") else C.c_int)
                for name in ("lossless quality method image_hint target_size target_PSNR "
                             "segments sns_strength filter_strength filter_sharpness filter_type "
                             "autofilter alpha_compression alpha_filtering alpha_quality pass_ "
                             "show_compressed preprocessing partitions partition_limit emulate_jpeg_size "
                             "thread_level low_memory near_lossless exact use_delta_palette "
                             "use_sharp_yuv qmin qmax").split()]


class Picture(C.Structure):
    _fields_ = [
        ("use_argb", C.c_int), ("colorspace", C.c_int), ("width", C.c_int), ("height", C.c_int),
        ("y", C.c_void_p), ("u", C.c_void_p), ("v", C.c_void_p),
        ("y_stride", C.c_int), ("uv_stride", C.c_int), ("a", C.c_void_p),
        ("a_stride", C.c_int), ("pad1", C.c_uint32 * 2), ("argb", C.c_void_p),
        ("argb_stride", C.c_int), ("pad2", C.c_uint32 * 3),
        ("writer", C.c_void_p), ("custom_ptr", C.c_void_p),
        ("extra_info_type", C.c_int), ("extra_info", C.c_void_p), ("stats", C.c_void_p),
        ("error_code", C.c_int), ("progress_hook", C.c_void_p), ("user_data", C.c_void_p),
        ("pad3", C.c_uint32 * 3), ("pad4", C.c_void_p), ("pad5", C.c_void_p),
        ("pad6", C.c_uint32 * 8), ("memory_", C.c_void_p), ("memory_argb_", C.c_void_p),
        ("pad7", C.c_void_p * 2)]


class Writer(C.Structure):
    _fields_ = [("mem", C.c_void_p), ("size", C.c_size_t), ("max_size", C.c_size_t),
                ("pad", C.c_uint32 * 1)]


class Encoder:
    def __init__(self, library=None):
        bundled = Path(_webp.__file__).parent / ".dylibs" / "libwebp.7.dylib"
        location = library or (str(bundled) if bundled.is_file() else C.util.find_library("webp"))
        # Linux Pillow wheels keep libwebp in a sibling pillow.libs directory.
        if not location:
            candidates = sorted(Path(_webp.__file__).parent.parent.glob("pillow.libs/libwebp-*.so*"))
            location = str(candidates[0]) if candidates else None
        if not location:
            raise RuntimeError("libwebp not found; supply --libwebp (no runtime dependency added)")
        self.lib = C.CDLL(location)
        signatures = {
            "WebPConfigInitInternal": ([C.POINTER(Config), C.c_int, C.c_float, C.c_int], C.c_int),
            "WebPValidateConfig": ([C.POINTER(Config)], C.c_int),
            "WebPPictureInitInternal": ([C.POINTER(Picture), C.c_int], C.c_int),
            "WebPPictureImportRGB": ([C.POINTER(Picture), C.c_char_p, C.c_int], C.c_int),
            "WebPEncode": ([C.POINTER(Config), C.POINTER(Picture)], C.c_int),
            "WebPPictureFree": ([C.POINTER(Picture)], None),
            "WebPMemoryWriterInit": ([C.POINTER(Writer)], None),
            "WebPMemoryWriterClear": ([C.POINTER(Writer)], None),
            "WebPGetEncoderVersion": ([], C.c_int),
        }
        for name, (arguments, result) in signatures.items():
            function = getattr(self.lib, name)
            function.argtypes, function.restype = arguments, result
        self.version = self.lib.WebPGetEncoderVersion()

    def encode(self, rgb, width, height, level):
        config, picture, writer = Config(), Picture(), Writer()
        if not self.lib.WebPConfigInitInternal(C.byref(config), 0, ENCODER_QUALITY, ABI_VERSION):
            raise RuntimeError("Incompatible libwebp config ABI")
        if not self.lib.WebPPictureInitInternal(C.byref(picture), ABI_VERSION):
            raise RuntimeError("Incompatible libwebp picture ABI")
        config.lossless, config.near_lossless = 1, level
        config.method, config.exact = ENCODER_METHOD, 1
        if not self.lib.WebPValidateConfig(C.byref(config)):
            raise RuntimeError("Invalid libwebp config")
        picture.use_argb, picture.width, picture.height = 1, width, height
        self.lib.WebPMemoryWriterInit(C.byref(writer))
        picture.writer = C.cast(self.lib.WebPMemoryWrite, C.c_void_p).value
        picture.custom_ptr = C.cast(C.pointer(writer), C.c_void_p).value
        try:
            if not self.lib.WebPPictureImportRGB(C.byref(picture), rgb, width * 3):
                raise RuntimeError("WebP RGB import failed")
            if not self.lib.WebPEncode(C.byref(config), C.byref(picture)):
                raise RuntimeError("WebP encode failed: %d" % picture.error_code)
            return C.string_at(writer.mem, writer.size)
        finally:
            self.lib.WebPPictureFree(C.byref(picture))
            self.lib.WebPMemoryWriterClear(C.byref(writer))
