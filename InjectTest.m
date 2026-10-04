#import <UIKit/UIKit.h>

@interface VoiceRebuildTestController : NSObject
+ (void)showTest;
@end

@implementation VoiceRebuildTestController

+ (void)showTest {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
                if (scene.activationState != UISceneActivationStateForegroundActive)
                    continue;

                if (![scene isKindOfClass:[UIWindowScene class]])
                    continue;

                for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }

                if (window)
                    break;
            }
        }

        if (!window)
            window = UIApplication.sharedApplication.keyWindow;

        if (!window)
            return;

        if ([window viewWithTag:987654])
            return;

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame = CGRectMake(
            window.bounds.size.width - 125,
            100,
            105,
            45
        );

        button.backgroundColor = UIColor.systemBlueColor;

        [button setTitle:@"语音插件"
                forState:UIControlStateNormal];

        [button setTitleColor:UIColor.whiteColor
                     forState:UIControlStateNormal];

        button.layer.cornerRadius = 10.0;
        button.clipsToBounds = YES;
        button.tag = 987654;

        [button addTarget:self
                   action:@selector(buttonPressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [window addSubview:button];

        NSLog(@"[VoiceRebuild] V0.2 injected successfully");
    });
}

+ (void)buttonPressed:(UIButton *)sender {
    UIAlertController *alert =
    [UIAlertController
     alertControllerWithTitle:@"VoiceRebuild V0.2"
     message:@"插件已经成功注入微信。\n\n下一步开始接入语音处理。"
     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
     [UIAlertAction
      actionWithTitle:@"确定"
      style:UIAlertActionStyleDefault
      handler:nil]];

    UIViewController *vc = sender.window.rootViewController;

    while (vc.presentedViewController)
        vc = vc.presentedViewController;

    [vc presentViewController:alert
                     animated:YES
                   completion:nil];
}

@end

__attribute__((constructor))
static void VoiceRebuild_Loaded(void) {
    NSLog(@"[VoiceRebuild] dylib loaded");

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [VoiceRebuildTestController showTest];
        }
    );
}
