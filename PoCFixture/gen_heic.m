// SPDX-License-Identifier: GPL-3.0-only
// Build: clang -fobjc-arc -framework Foundation -framework ImageIO \
//              -framework CoreGraphics -o gen_heic gen_heic.m
// Run:   ./gen_heic output.heic
//

#import <Foundation/Foundation.h>
#import <ImageIO/ImageIO.h>

static CGImageRef makeFrame(size_t height, uint32_t bgra) {
    const size_t width = 256;
    const size_t rowBytes = width * 4; // One 32-bit BGRA pixel per column.
    uint8_t *pixels = malloc(rowBytes * height);
    if (!pixels) return NULL;
    // Fill the entire frame with one color; the second frame uses a different marker.
    for (size_t i = 0; i < width * height; i++)
        memcpy(pixels + i * 4, &bgra, 4);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    // Turn the raw pixels into a CGImage that ImageIO can encode into the HEIC.
    CGContextRef context = CGBitmapContextCreate(
        pixels, width, height, 8, rowBytes, colorSpace,
        kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Little);
    CGImageRef image = context ? CGBitmapContextCreateImage(context) : NULL;
    // CGBitmapContextCreateImage retains its own image data, so these can be released.
    if (context) CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    return image;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 2) {
            fprintf(stderr, "usage: %s output.heic\n", argv[0]);
            return 1;
        }

        NSString *path = [NSString stringWithUTF8String:argv[1]];
        if (!path) { fprintf(stderr, "invalid output path\n"); return 1; }
        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
            fprintf(stderr, "output already exists: %s\n", argv[1]);
            return 1;
        }

        // public.heic is a collection here: ImageIO will write two images into one file.
        CGImageDestinationRef destination = CGImageDestinationCreateWithURL(
            (__bridge CFURLRef)[NSURL fileURLWithPath:path], CFSTR("public.heic"), 2, NULL);
        if (!destination) {
            fprintf(stderr, "could not create HEIC destination\n");
            return 1;
        }

        const size_t heights[] = {16, 48};
        const uint32_t colors[] = {0xFF202020u, 0xFFADBEEFu};
        NSDictionary *options = @{
            (__bridge NSString *)kCGImageDestinationLossyCompressionQuality: @1.0
        };
        for (size_t i = 0; i < 2; i++) {
            CGImageRef frame = makeFrame(heights[i], colors[i]);
            if (!frame) {
                fprintf(stderr, "could not create frame %zu\n", i);
                CFRelease(destination);
                return 1;
            }
            // The order matters: frame 0 establishes the size used for later frames.
            CGImageDestinationAddImage(destination, frame, (__bridge CFDictionaryRef)options);
            CGImageRelease(frame);
        }

        BOOL ok = CGImageDestinationFinalize(destination);
        CFRelease(destination);
        if (!ok) {
            fprintf(stderr, "could not finalize HEIC\n");
            return 1;
        }
        printf("wrote %s\n", argv[1]);
    }
    return 0;
}
