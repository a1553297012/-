#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void VBLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSLog(@"[VoiceBridgeProbe] %@", message);
}

static void DumpMethods(Class cls) {
    if (!cls) {
        return;
    }

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    VBLog(@"%@ methods=%u", NSStringFromClass(cls), count);

    for (unsigned int i = 0; i < count; i++) {
        SEL selector = method_getName(methods[i]);

        const char *encoding =
            method_getTypeEncoding(methods[i]);

        NSString *name =
            NSStringFromSelector(selector);

        if ([name containsString:@"Voice"] ||
            [name containsString:@"Audio"] ||
            [name containsString:@"Chat"] ||
            [name containsString:@"Account"] ||
            [name containsString:@"Send"] ||
            [name containsString:@"send"]) {

            VBLog(@"  %@ :: %s",
                  name,
                  encoding ? encoding : "");
        }
    }

    free(methods);
}

static UIWindow *VBFindKeyWindow(void) {

    UIWindow *keyWindow = nil;

    /*
     * iOS 12 兼容方式。
     * 不使用 UIWindowScene / connectedScenes。
     */

    if ([UIApplication sharedApplication].keyWindow) {
        keyWindow =
            [UIApplication sharedApplication].keyWindow;
    }

    if (!keyWindow) {

        NSArray *windows =
            [UIApplication sharedApplication].windows;

        for (UIWindow *window in windows) {

            if (window.isKeyWindow) {
                keyWindow = window;
                break;
            }
        }
    }

    return keyWindow;
}

static UIViewController *VBTopViewController(
    UIViewController *root) {

    if (!root) {
        return nil;
    }

    UIViewController *current = root;

    while (current.presentedViewController) {
        current = current.presentedViewController;
    }

    return current;
}

static void Probe(void) {

    @autoreleasepool {

        VBLog(@"================================");
        VBLog(@"VoiceBridgeProbe START");
        VBLog(@"================================");

        Class bridge =
            NSClassFromString(
                @"SHVoiceIndependentSendBridge"
            );

        Class reconstruction =
            NSClassFromString(
                @"SHVoiceReconstructionManager"
            );

        Class wrap =
            NSClassFromString(@"SHVISWrap");

        VBLog(@"SHVoiceIndependentSendBridge: %@",
              bridge ? @"FOUND" : @"NOT FOUND");

        VBLog(@"SHVoiceReconstructionManager: %@",
              reconstruction ? @"FOUND" : @"NOT FOUND");

        VBLog(@"SHVISWrap: %@",
              wrap ? @"FOUND" : @"NOT FOUND");

        if (bridge) {
            DumpMethods(bridge);
        }

        if (reconstruction) {
            DumpMethods(reconstruction);
        }

        if (wrap) {
            DumpMethods(wrap);
        }

        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                UIWindow *window =
                    VBFindKeyWindow();

                if (!window) {
                    VBLog(@"keyWindow: NOT FOUND");
                    return;
                }

                UIViewController *top =
                    VBTopViewController(
                        window.rootViewController
                    );

                VBLog(@"keyWindow: FOUND");

                VBLog(@"topViewController: %@",
                      top
                      ? NSStringFromClass(top.class)
                      : @"NOT FOUND");

                VBLog(@"SAFE PROBE ONLY");
                VBLog(@"No message will be sent.");
                VBLog(@"No voice will be sent.");

                VBLog(@"================================");
                VBLog(@"VoiceBridgeProbe END");
                VBLog(@"================================");
            }
        );
    }
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            Probe();
        }
    );
}
