#import <UIKit/UIKit.h>

__attribute__((constructor))
static void TestLoaded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"测试成功"
                                            message:@"VoiceRebuildInjectTest 已加载到微信"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction actionWithTitle:@"确定"
                                  style:UIAlertActionStyleDefault
                                handler:nil]];

        UIWindow *window = nil;

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (scene.activationState ==
                UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {

                for (UIWindow *w in
                     ((UIWindowScene *)scene).windows) {

                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }

            if (window) break;
        }

        UIViewController *vc = window.rootViewController;

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        [vc presentViewController:alert
                          animated:YES
                        completion:nil];
    });
}
