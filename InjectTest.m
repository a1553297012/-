#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;
static BOOL HBHookInstalled = NO;
static BOOL HBHookAlertShown = NO;

#pragma mark - Logging

static void HBLog(NSString *format, ...)
{
    if (!format) {
        return;
    }

    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format
                               arguments:args];

    va_end(args);

    NSLog(@"[VoiceRebuild] %@", message);
}

#pragma mark - Object Logging

static void HBLogObject(id obj, NSString *name)
{
    if (!obj) {

        HBLog(@"%@ = nil", name);

        return;
    }

    HBLog(
        @"%@ class = %@",
        name,
        NSStringFromClass([obj class])
    );

    HBLog(
        @"%@ description = %@",
        name,
        obj
    );

    /*
     * 如果参数是 UIAlertController，
     * 额外记录里面的信息。
     */
    if ([obj isKindOfClass:[UIAlertController class]]) {

        UIAlertController *alert =
            (UIAlertController *)obj;

        HBLog(
            @"%@ title = %@",
            name,
            alert.title
        );

        HBLog(
            @"%@ message = %@",
            name,
            alert.message
        );

        HBLog(
            @"%@ actions count = %lu",
            name,
            (unsigned long)alert.actions.count
        );

        for (UIAlertAction *action in alert.actions) {

            HBLog(
                @"%@ action = %@",
                name,
                action.title
            );
        }
    }
}

#pragma mark - Debug Alert

static void HBShowHookSuccessAlert(void)
{
    if (HBHookAlertShown) {
        return;
    }

    HBHookAlertShown = YES;

    dispatch_async(dispatch_get_main_queue(), ^{

        @autoreleasepool {

            UIWindow *window = nil;

            /*
             * iOS 13+
             */
            if (@available(iOS 13.0, *)) {

                for (UIScene *scene
                     in [UIApplication sharedApplication].connectedScenes) {

                    if (scene.activationState !=
                        UISceneActivationStateForegroundActive) {
                        continue;
                    }

                    if (![scene
                          isKindOfClass:[UIWindowScene class]]) {
                        continue;
                    }

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

            /*
             * 兼容旧方式
             */
            if (!window) {

                window =
                    [UIApplication sharedApplication].keyWindow;
            }

            if (!window) {

                HBLog(
                    @"无法找到当前 UIWindow，"
                    @"跳过 Hook 成功弹窗"
                );

                return;
            }

            UIViewController *root =
                window.rootViewController;

            if (!root) {

                HBLog(
                    @"rootViewController = nil"
                );

                return;
            }

            /*
             * 找到最上层控制器
             */
            while (root.presentedViewController) {

                root =
                    root.presentedViewController;
            }

            UIAlertController *alert =
                [UIAlertController
                    alertControllerWithTitle:@"HB语音 Hook"
                    message:@"getNewVoiceServerList: 已成功 Hook"
                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:
                [UIAlertAction
                    actionWithTitle:@"确定"
                    style:UIAlertActionStyleDefault
                    handler:nil]];

            [root
                presentViewController:alert
                animated:YES
                completion:^{

                    HBLog(
                        @"Hook success alert presented"
                    );
                }];
        }
    });
}

#pragma mark - Hook Function

static void HBHookedGetNewVoiceServerList(
    id self,
    SEL _cmd,
    id arg
)
{
    HBLog(
        @"========================================"
    );

    HBLog(
        @"getNewVoiceServerList: CALLED"
    );

    HBLog(
        @"self class = %@",
        NSStringFromClass([self class])
    );

    HBLog(
        @"selector = %@",
        NSStringFromSelector(_cmd)
    );

    /*
     * 原始参数
     */
    HBLogObject(
        arg,
        @"ARGUMENT BEFORE"
    );

    /*
     * 调用原始方法
     */
    if (HBOriginalGetNewVoiceServerList) {

        HBLog(
            @"Calling original IMP..."
        );

        HBOriginalGetNewVoiceServerList(
            self,
            _cmd,
            arg
        );

        HBLog(
            @"Original IMP returned"
        );

    } else {

        HBLog(
            @"ERROR: original IMP is NULL"
        );
    }

    /*
     * 原方法执行之后再次查看参数
     */
    HBLogObject(
        arg,
        @"ARGUMENT AFTER"
    );

    HBLog(
        @"getNewVoiceServerList: FINISHED"
    );

    HBLog(
        @"========================================"
    );
}

#pragma mark - Install Hook

static BOOL HookVoiceController(void)
{
    if (HBHookInstalled) {

        return YES;
    }

    HBLog(
        @"开始寻找 VoiceSelectController..."
    );

    Class cls =
        NSClassFromString(
            @"VoiceSelectController"
        );

    if (!cls) {

        HBLog(
            @"VoiceSelectController 尚未出现"
        );

        return NO;
    }

    HBLog(
        @"VoiceSelectController FOUND: %@",
        cls
    );

    SEL selector =
        NSSelectorFromString(
            @"getNewVoiceServerList:"
        );

    Method method =
        class_getInstanceMethod(
            cls,
            selector
        );

    if (!method) {

        HBLog(
            @"ERROR: getNewVoiceServerList: 不存在"
        );

        return NO;
    }

    HBLog(
        @"getNewVoiceServerList: FOUND"
    );

    IMP oldIMP =
        method_getImplementation(
            method
        );

    if (!oldIMP) {

        HBLog(
            @"ERROR: original IMP = NULL"
        );

        return NO;
    }

    /*
     * 保存原始 IMP
     */
    HBOriginalGetNewVoiceServerList =
        (HBVoiceOriginalFunc)oldIMP;

    /*
     * 替换 IMP
     */
    method_setImplementation(
        method,
        (IMP)HBHookedGetNewVoiceServerList
    );

    HBHookInstalled = YES;

    HBLog(
        @"========================================"
    );

    HBLog(
        @"HOOK INSTALLED SUCCESSFULLY"
    );

    HBLog(
        @"class = %@",
        NSStringFromClass(cls)
    );

    HBLog(
        @"selector = %@",
        NSStringFromSelector(selector)
    );

    HBLog(
        @"========================================"
    );

    /*
     * 弹一次提示
     */
    HBShowHookSuccessAlert();

    return YES;
}

#pragma mark - Retry

static void HBTryInstallHook(void)
{
    if (HBHookInstalled) {
        return;
    }

    BOOL success =
        HookVoiceController();

    if (success) {

        HBLog(
            @"Hook 安装完成，停止检查"
        );

        return;
    }

    HBLog(
        @"3 秒后继续检查 VoiceSelectController..."
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            3 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{
            HBTryInstallHook();
        }
    );
}

#pragma mark - Start

static void StartVoiceHook(void)
{
    HBLog(
        @"========================================"
    );

    HBLog(
        @"VoiceRebuildInjectTest loaded"
    );

    HBLog(
        @"开始等待 VoiceSelectController..."
    );

    HBLog(
        @"========================================"
    );

    /*
     * 给微信一点初始化时间
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            5 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{
            HBTryInstallHook();
        }
    );
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
            @"[VoiceRebuild] "
            @"VoiceRebuildInjectTest DLL LOADED"
        );

        NSLog(
            @"[VoiceRebuild] "
            @"Constructor executed"
        );

        NSLog(
            @"========================================"
        );

        StartVoiceHook();
    }
}
