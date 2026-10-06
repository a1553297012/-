#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void VBLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *s = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    NSLog(@"[VoiceBridgeProbe] %@", s);
}

static void DumpMethods(Class cls) {
    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    VBLog(@"%@ methods=%u", NSStringFromClass(cls), count);

    for (unsigned int i = 0; i < count; i++) {
        SEL sel = method_getName(methods[i]);
        const char *enc = method_getTypeEncoding(methods[i]);

        NSString *name = NSStringFromSelector(sel);

        if ([name containsString:@"Voice"] ||
            [name containsString:@"Audio"] ||
            [name containsString:@"Chat"] ||
            [name containsString:@"Account"] ||
            [name containsString:@"sendConverted"]) {

            VBLog(@"  %@ :: %s", name, enc ?: "");
        }
    }

    free(methods);
}

static void Probe(void) {
    @autoreleasepool {

        Class bridge = NSClassFromString(@"SHVoiceIndependentSendBridge");
        Class recon  = NSClassFromString(@"SHVoiceReconstructionManager");
        Class wrap   = NSClassFromString(@"SHVISWrap");

        VBLog(@"=== VoiceBridgeProbe start ===");

        VBLog(@"SHVoiceIndependentSendBridge = %@",
              bridge ? @"FOUND" : @"NOT FOUND");

        VBLog(@"SHVoiceReconstructionManager = %@",
              recon ? @"FOUND" : @"NOT FOUND");

        VBLog(@"SHVISWrap = %@",
              wrap ? @"FOUND" : @"NOT FOUND");

        if (bridge) DumpMethods(bridge);
        if (recon)  DumpMethods(recon);
        if (wrap)   DumpMethods(wrap);

        dispatch_async(dispatch_get_main_queue(), ^{

            UIWindow *keyWindow = nil;

            for (UIWindowScene *scene in
                 UIApplication.sharedApplication.connectedScenes) {

                if (scene.activationState ==
                    UISceneActivationStateForegroundActive) {

                    for (UIWindow *window in scene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                }

                if (keyWindow) break;
            }

            UIViewController *vc = keyWindow.rootViewController;

            while (vc.presentedViewController) {
                vc = vc.presentedViewController;
            }

            VBLog(@"topViewController=%@",
                  NSStringFromClass(vc.class));

            VBLog(@"SAFE PROBE ONLY: no voice/message will be sent.");
        });
    }
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        Probe();
    });
}
