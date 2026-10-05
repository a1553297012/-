#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;

static BOOL HBHookInstalled = NO;
static BOOL HBHookAlertShown = NO;
static BOOL HBMethodCalledAlertShown = NO;

#pragma mark - Log

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

#pragma mark - Find Current ViewController

static UIViewController *HBTopViewController(void)
{
    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene
             in [UIApplication sharedApplication].connectedScenes) {

            if (scene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            if (![scene isKindOfClass:[UIWindowScene class]]) {
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

    if (!window) {

        window =
            [UIApplication sharedApplication].keyWindow;
    }

    if (!window) {
        return nil;
    }

    UIViewController *vc =
        window.rootViewController;

    if (!vc) {
        return nil;
    }

    while (vc.presentedViewController) {

        vc =
            vc.presentedViewController;
    }

    return vc;
}

#pragma mark - Hook Success Alert

static void HBShowHookSuccessAlert(void)
{
    if (HBHookAlertShown) {
        return;
    }

    HBHookAlertShown = YES;

    dispatch_async(dispatch_get_main_queue(), ^{

        @autoreleasepool {

            UIViewController *vc =
                HBTopViewController();

            if (!vc) {

                HBLog(
                    @"无法找到当前 ViewController"
                );

                return;
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

            [vc presentViewController:alert
                             animated:YES
                           completion:^{

                HBLog(
                    @"Hook success alert presented"
                );
            }];
        }
    });
}

#pragma mark - Method Called Alert

static void HBShowMethodCalledAlert(id arg)
{
    if (HBMethodCalledAlertShown) {
        return;
    }

    HBMethodCalledAlertShown = YES;

    NSString *argumentClass =
        arg
        ? NSStringFromClass([arg class])
        : @"nil";

    NSString *argumentDescription =
        arg
        ? [NSString stringWithFormat:@"%@", arg]
        : @"nil";

    /*
     * 防止参数 description 太长把弹窗撑爆
     */
    if (argumentDescription.length > 500) {

        argumentDescription =
            [argumentDescription
                substringToIndex:500];
    }

    NSString *message =
        [NSString stringWithFormat:
            @"getNewVoiceServerList: 被调用\n\n"
             "参数类型：%@\n\n"
             "参数内容：%@",
            argumentClass,
            argumentDescription];

    dispatch_async(dispatch_get_main_queue(), ^{

        @autoreleasepool {

            UIViewController *vc =
                HBTopViewController();

            if (!vc) {

                HBLog(
                    @"方法被调用，但无法找到 ViewController"
                );

                return;
            }

            UIAlertController *alert =
                [UIAlertController
                    alertControllerWithTitle:@"HB语音"
                    message:message
                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:
                [UIAlertAction
                    actionWithTitle:@"确定"
                    style:UIAlertActionStyleDefault
                    handler:nil]];

            [vc presentViewController:alert
                             animated:YES
                           completion:^{

                HBLog(
                    @"Method called alert presented"
                );
            }];
        }
    });
}

#pragma mark - Object Log

static void HBLogObject(id obj, NSString *name)
{
    if (!obj) {

        HBLog(
            @"%@ = nil",
            name
        );

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
     * 如果参数是 UIAlertController
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

        for (UIAlertAction *action
             in alert.actions) {

            HBLog(
                @"%@ action = %@",
                name,
                action.title
            );
        }
    }
}

#pragma mark - Hooked Method

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
     * 第一次调用时弹窗
     */
    HBShowMethodCalledAlert(arg);

    /*
     * 记录调用前参数
     */
    HBLogObject(
        arg,
        @"ARGUMENT BEFORE"
    );

    /*
     * 调用原始 IMP
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
     * 原方法执行之后
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
     * 弹出 Hook 成功提示
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
            @"Hook 安装完成"
        );

        return;
    }

    HBLog(
        @"3 秒后继续检查..."
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
     * 微信启动 5 秒后开始寻找类
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
