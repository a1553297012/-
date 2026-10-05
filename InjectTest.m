#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Debug

static void HBShowTestAlert(void)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        @autoreleasepool {

            UIWindow *window = nil;

            if (@available(iOS 13.0, *)) {

                for (UIScene *scene in
                     [UIApplication sharedApplication].connectedScenes) {

                    if (scene.activationState ==
                        UISceneActivationStateForegroundActive) {

                        if ([scene isKindOfClass:[UIWindowScene class]]) {

                            UIWindowScene *windowScene =
                                (UIWindowScene *)scene;

                            for (UIWindow *candidate
                                 in windowScene.windows) {

                                if (candidate.isKeyWindow) {
                                    window = candidate;
                                    break;
                                }
                            }

                            if (window) {
                                break;
                            }
                        }
                    }
                }
            }

            if (!window) {
                window =
                    [UIApplication sharedApplication].keyWindow;
            }

            UIViewController *root =
                window.rootViewController;

            if (!root) {
                NSLog(@"[VoiceRebuild] ERROR: rootViewController nil");
                return;
            }

            while (root.presentedViewController) {
                root = root.presentedViewController;
            }

            UIAlertController *alert =
                [UIAlertController
                    alertControllerWithTitle:@"HB语音测试"
                    message:@"VoiceRebuildInjectTest.dylib 已成功加载！"
                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:
                [UIAlertAction
                    actionWithTitle:@"确定"
                    style:UIAlertActionStyleDefault
                    handler:nil]];

            [root presentViewController:alert
                               animated:YES
                             completion:^{
                NSLog(
                    @"[VoiceRebuild] TEST ALERT PRESENTED"
                );
            }];
        }
    });
}

#pragma mark - Constructor

__attribute__((constructor))
static void VoiceRebuildInjectTest_Loaded(void)
{
    @autoreleasepool {

        NSLog(
            @"========================================"
        );

        NSLog(
            @"[VoiceRebuild] DLL LOADED SUCCESSFULLY"
        );

        NSLog(
            @"[VoiceRebuild] TEST VERSION"
        );

        NSLog(
            @"========================================"
        );

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                3 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                HBShowTestAlert();
            }
        );
    }
}
