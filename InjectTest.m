#import <UIKit/UIKit.h>

__attribute__((constructor))
static void TestLoaded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{

        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"测试成功"
                                            message:@"VoiceRebuildInjectTest 已加载"
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction actionWithTitle:@"确定"
                                  style:UIAlertActionStyleDefault
                                handler:nil]];

        UIWindow *window =
        [UIApplication sharedApplication].keyWindow;

        UIViewController *vc = window.rootViewController;

        while (vc.presentedViewController) {
            vc = vc.presentedViewController;
        }

        if (vc) {
            [vc presentViewController:alert
                              animated:YES
                            completion:nil];
        }
    });
}
