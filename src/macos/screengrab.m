#include "../screengrab.h"
#include "../endian.h"
#include <stdlib.h> /* malloc() */

#include <ApplicationServices/ApplicationServices.h>
#import <Cocoa/Cocoa.h>
#import <ScreenCaptureKit/ScreenCaptureKit.h>
#import <CoreGraphics/CoreGraphics.h>

static double getPixelDensity() {
    @autoreleasepool
    {
        NSScreen * mainScreen = [NSScreen
        mainScreen];
        if (mainScreen) {
            return mainScreen.backingScaleFactor;
        } else {
            return 1.0;
        }
    }
}

MMBitmapRef copyMMBitmapFromDisplayInRect(MMRect rect) {

    CGDirectDisplayID displayID = CGMainDisplayID();
    CGRect cgRect = CGRectMake(rect.origin.x,rect.origin.y,rect.size.width,rect.size.height);
    SCContentFilter *contentFilter = [SCContentFilter filterWithDisplay:displayID];
    SCStreamConfiguration *streamConfig = [[SCStreamConfiguration alloc] init];
    streamConfig.width = cgRect.size.width;  // 设置截图宽度
    streamConfig.height = cgRect.size.height; // 设置截图高度

    // 创建 SCStream
    SCStream *stream = [[SCStream alloc] initWithFilter:contentFilter configuration:streamConfig delegate:nil];
    // 用于存储截图的 CGImageRef
    __block CGImageRef image = NULL;

    // 使用信号量等待截图完成
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

    // 开始截图
    [stream startCaptureWithCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"截图失败: %@", error);
        } else {
            // 获取截图
            [stream captureImageWithCompletionHandler:^(CGImageRef image, NSError *error) {
                if (image) {
                    // 裁剪截图到指定区域
                    image = CGImageCreateWithImageInRect(image, cgRect);
                    CGImageRelease(image); // 释放原始截图
                } else {
                    NSLog(@"获取截图失败: %@", error);
                }
                dispatch_semaphore_signal(semaphore); // 通知截图完成
            }];
        }
    }];

    // 等待截图完成
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);

    // 停止截图
    [stream stopCaptureWithCompletionHandler:^(NSError *error) {
        if (error) {
            NSLog(@"停止截图失败: %@", error);
        }
    }];


    if (!image) { return NULL; }

    CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(image));

    if (!imageData) { return NULL; }

    long bufferSize = CFDataGetLength(imageData);
    size_t bytesPerPixel = (size_t) (CGImageGetBitsPerPixel(image) / 8);
    double pixelDensity = getPixelDensity();
    long expectedBufferSize = rect.size.width * pixelDensity * rect.size.height * pixelDensity * bytesPerPixel;

    if (expectedBufferSize < bufferSize) {
        size_t reportedByteWidth = CGImageGetBytesPerRow(image);
        size_t expectedByteWidth = expectedBufferSize / (rect.size.height * pixelDensity);

        uint8_t *buffer = malloc(expectedBufferSize);

        const uint8_t *dataPointer = CFDataGetBytePtr(imageData);
        size_t parts = bufferSize / reportedByteWidth;

        for (size_t idx = 0; idx < parts - 1; ++idx) {
            memcpy(buffer + (idx * expectedByteWidth),
                   dataPointer + (idx * reportedByteWidth),
                   expectedByteWidth
            );
        }

        MMBitmapRef bitmap = createMMBitmap(buffer,
                                            rect.size.width * pixelDensity,
                                            rect.size.height * pixelDensity,
                                            expectedByteWidth,
                                            CGImageGetBitsPerPixel(image),
                                            CGImageGetBitsPerPixel(image) / 8);

        CFRelease(imageData);
        CGImageRelease(image);

        return bitmap;
    } else {
        uint8_t *buffer = malloc(bufferSize);
        CFDataGetBytes(imageData, CFRangeMake(0, bufferSize), buffer);
        MMBitmapRef bitmap = createMMBitmap(buffer,
                                            CGImageGetWidth(image),
                                            CGImageGetHeight(image),
                                            CGImageGetBytesPerRow(image),
                                            CGImageGetBitsPerPixel(image),
                                            CGImageGetBitsPerPixel(image) / 8);

        CFRelease(imageData);

        CGImageRelease(image);

        return bitmap;
    }
}

// MMBitmapRef copyMMBitmapFromDisplayInRect(MMRect rect) {

//     CGDirectDisplayID displayID = CGMainDisplayID();

//     CGImageRef image = CGDisplayCreateImageForRect(displayID,
//                                                    CGRectMake(
//                                                            rect.origin.x,
//                                                            rect.origin.y,
//                                                            rect.size.width,
//                                                            rect.size.height
//                                                    )
//     );

//     if (!image) { return NULL; }

//     CFDataRef imageData = CGDataProviderCopyData(CGImageGetDataProvider(image));

//     if (!imageData) { return NULL; }

//     long bufferSize = CFDataGetLength(imageData);
//     size_t bytesPerPixel = (size_t) (CGImageGetBitsPerPixel(image) / 8);
//     double pixelDensity = getPixelDensity();
//     long expectedBufferSize = rect.size.width * pixelDensity * rect.size.height * pixelDensity * bytesPerPixel;

//     if (expectedBufferSize < bufferSize) {
//         size_t reportedByteWidth = CGImageGetBytesPerRow(image);
//         size_t expectedByteWidth = expectedBufferSize / (rect.size.height * pixelDensity);

//         uint8_t *buffer = malloc(expectedBufferSize);

//         const uint8_t *dataPointer = CFDataGetBytePtr(imageData);
//         size_t parts = bufferSize / reportedByteWidth;

//         for (size_t idx = 0; idx < parts - 1; ++idx) {
//             memcpy(buffer + (idx * expectedByteWidth),
//                    dataPointer + (idx * reportedByteWidth),
//                    expectedByteWidth
//             );
//         }

//         MMBitmapRef bitmap = createMMBitmap(buffer,
//                                             rect.size.width * pixelDensity,
//                                             rect.size.height * pixelDensity,
//                                             expectedByteWidth,
//                                             CGImageGetBitsPerPixel(image),
//                                             CGImageGetBitsPerPixel(image) / 8);

//         CFRelease(imageData);
//         CGImageRelease(image);

//         return bitmap;
//     } else {
//         uint8_t *buffer = malloc(bufferSize);
//         CFDataGetBytes(imageData, CFRangeMake(0, bufferSize), buffer);
//         MMBitmapRef bitmap = createMMBitmap(buffer,
//                                             CGImageGetWidth(image),
//                                             CGImageGetHeight(image),
//                                             CGImageGetBytesPerRow(image),
//                                             CGImageGetBitsPerPixel(image),
//                                             CGImageGetBitsPerPixel(image) / 8);

//         CFRelease(imageData);

//         CGImageRelease(image);

//         return bitmap;
//     }
// }