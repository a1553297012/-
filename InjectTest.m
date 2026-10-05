#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void VTWrite(NSString *text) {
    NSString *path = @"/var/mobile/VoiceTrace.log";

    NSString *line =
    [NSString stringWithFormat:@"%@\n", text];

    NSFileHandle *file =
    [NSFileHandle fileHandleForWritingAtPath:path];

    if (!file) {
        [line writeToFile:path
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];
        return;
    }

    [file seekToEndOfFile];

    [file writeData:
        [line dataUsingEncoding:NSUTF8StringEncoding]];

    [file closeFile];
}

static BOOL VTIsInteresting(NSString *url) {
    NSString *s = url.lowercaseString;

    return
    [s containsString:@"voice"] ||
    [s containsString:@"model"] ||
    [s containsString:@"senhang"] ||
    [s containsString:@"silk"] ||
    [s containsString:@"speech"] ||
    [s containsString:@"audio"] ||
    [s containsString:@"pcm"] ||
    [s containsString:@"ovmodel"];
}

static void VTShowURL(NSString *url) {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIAlertController *a =
        [UIAlertController
         alertControllerWithTitle:@"VoiceTrace"
         message:url
         preferredStyle:UIAlertControllerStyleAlert];

        [a addAction:
         [UIAlertAction
          actionWithTitle:@"确定"
          style:UIAlertActionStyleDefault
          handler:nil]];

        UIWindow *window =
        [UIApplication sharedApplication].keyWindow;

        UIViewController *vc =
        window.rootViewController;

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        if (vc) {
            [vc presentViewController:a
                              animated:YES
                            completion:nil];
        }
    });
}

#pragma mark - NSURLSession

@interface NSURLSession (VoiceTrace)

- (NSURLSessionDataTask *)
vt_dataTaskWithRequest:(NSURLRequest *)request
completionHandler:(void (^)(NSData *,
                            NSURLResponse *,
                            NSError *))completionHandler;

@end

@implementation NSURLSession (VoiceTrace)

- (NSURLSessionDataTask *)
vt_dataTaskWithRequest:(NSURLRequest *)request
completionHandler:(void (^)(NSData *,
                            NSURLResponse *,
                            NSError *))completionHandler {

    NSString *url =
    request.URL.absoluteString ?: @"";

    VTWrite([NSString stringWithFormat:
             @"[REQUEST] %@", url]);

    if (VTIsInteresting(url)) {
        VTWrite(@"[INTERESTING]");
        VTShowURL(url);
    }

    return
    [self vt_dataTaskWithRequest:request
               completionHandler:completionHandler];
}

@end

#pragma mark - Download

@interface NSURLSession (VoiceTraceDownload)

- (NSURLSessionDownloadTask *)
vt_downloadTaskWithRequest:(NSURLRequest *)request
completionHandler:(void (^)(NSURL *,
                            NSURLResponse *,
                            NSError *))completionHandler;

@end

@implementation NSURLSession (VoiceTraceDownload)

- (NSURLSessionDownloadTask *)
vt_downloadTaskWithRequest:(NSURLRequest *)request
completionHandler:(void (^)(NSURL *,
                            NSURLResponse *,
                            NSError *))completionHandler {

    NSString *url =
    request.URL.absoluteString ?: @"";

    VTWrite([NSString stringWithFormat:
             @"[DOWNLOAD] %@", url]);

    if (VTIsInteresting(url)) {
        VTWrite(@"[INTERESTING DOWNLOAD]");
        VTShowURL(url);
    }

    return
    [self vt_downloadTaskWithRequest:request
                   completionHandler:completionHandler];
}

@end

#pragma mark - Hook

static void VTHook(Class cls,
                   SEL original,
                   SEL replacement) {

    Method a =
    class_getInstanceMethod(cls, original);

    Method b =
    class_getInstanceMethod(cls, replacement);

    if (a && b) {
        method_exchangeImplementations(a, b);
    }
}

__attribute__((constructor))
static void VoiceTraceLoaded(void) {

    @autoreleasepool {

        VTWrite(@"======================");
        VTWrite(@"VoiceTrace LOADED");
        VTWrite(@"======================");

        VTHook(
            [NSURLSession class],
            @selector(dataTaskWithRequest:completionHandler:),
            @selector(vt_dataTaskWithRequest:completionHandler:)
        );

        VTHook(
            [NSURLSession class],
            @selector(downloadTaskWithRequest:completionHandler:),
            @selector(vt_downloadTaskWithRequest:completionHandler:)
        );

        VTWrite(@"VoiceTrace READY");
    }
}
