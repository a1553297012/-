#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void HBShow(NSString *text) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive &&
                    [scene isKindOfClass:[UIWindowScene class]]) {
                    for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                        if (w.isKeyWindow) {
                            window = w;
                            break;
                        }
                    }
                }
                if (window) break;
            }
        }

        if (!window) {
            window = [UIApplication sharedApplication].keyWindow;
        }

        if (!window) return;

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"HB语音拦截"
                                            message:text
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction actionWithTitle:@"确定"
                                  style:UIAlertActionStyleDefault
                                handler:nil]];

        UIViewController *vc = window.rootViewController;

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        [vc presentViewController:alert animated:YES completion:nil];
    });
}

static void HookVoiceController(void) {

    Class cls = NSClassFromString(@"VoiceSelectController");

    if (!cls) {
        NSLog(@"[VoiceRebuild] VoiceSelectController not found");
        return;
    }

    SEL sel = NSSelectorFromString(@"getNewVoiceServerList:");

    Method method = class_getInstanceMethod(cls, sel);

    if (!method) {
        NSLog(@"[VoiceRebuild] getNewVoiceServerList: not found");
        return;
    }

    IMP oldIMP = method_getImplementation(method);

    typedef void (*VoiceFunc)(id, SEL, id);

    VoiceFunc original = (VoiceFunc)oldIMP;

    IMP newIMP = imp_implementationWithBlock(^void(id self, id arg) {

        NSLog(@"[VoiceRebuild] ===== HB VOICE SERVER =====");
        NSLog(@"[VoiceRebuild] argument = %@", arg);

        NSString *info =
        [NSString stringWithFormat:
         @"方法：getNewVoiceServerList:\n\n参数：\n%@",
         arg];

        HBShow(info);

        original(self, sel, arg);
    });

    method_setImplementation(method, newIMP);

    NSLog(@"[VoiceRebuild] Hook installed!");
}

__attribute__((constructor))
static void VoiceRebuildInjectTest_Loaded(void) {

    @autoreleasepool {

        NSLog(@"[VoiceRebuild] loaded");

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC),
            dispatch_get_main_queue(),
            ^{
                HookVoiceController();
            }
        );
    }
}
