#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;

static BOOL HBHookInstalled = NO;
static BOOL HBDetailAlertShown = NO;

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

    NSLog(
        @"[VoiceRebuild] %@",
        message
    );
}

#pragma mark - Top ViewController

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

            if (![scene isKindOfClass:
                    [UIWindowScene class]]) {

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

#pragma mark - Safe String

static NSString *HBSafeString(id obj)
{
    if (!obj) {
        return @"nil";
    }

    @try {

        return [NSString stringWithFormat:@"%@", obj];

    } @catch (...) {

        return @"<无法读取 description>";
    }
}

#pragma mark - UIAlertController Analysis

static NSString *HBAlertDetail( UIAlertController *alert )
{
    if (!alert) {
        return @"UIAlertController = nil";
    }

    NSMutableString *result =
        [NSMutableString string];

    [result appendString:
        @"========== UIAlertController ==========\n"];

    [result appendFormat:
        @"class: %@\n",
        NSStringFromClass([alert class])];

    [result appendFormat:
        @"address: %p\n",
        alert];

    [result appendFormat:
        @"title: %@\n",
        alert.title ?: @"<nil>"];

    [result appendFormat:
        @"message: %@\n",
        alert.message ?: @"<nil>"];

    [result appendFormat:
        @"preferredStyle: %ld\n",
        (long)alert.preferredStyle];

    [result appendFormat:
        @"actions count: %lu\n",
        (unsigned long)alert.actions.count];

    [result appendString:@"\n"];

    if (alert.actions.count > 0) {

        [result appendString:
            @"---------- Actions ----------\n"];

        NSUInteger index = 0;

        for (UIAlertAction *action
             in alert.actions) {

            [result appendFormat:
                @"Action[%lu]\n",
                (unsigned long)index];

            [result appendFormat:
                @"  title: %@\n",
                action.title ?: @"<nil>"];

            [result appendFormat:
                @"  style: %ld\n",
                (long)action.style];

            [result appendFormat:
                @"  enabled: %@\n",
                action.enabled ? @"YES" : @"NO"];

            index++;
        }
    }

    [result appendString:
        @"\n========== END ALERT =========="];

    return result;
}

#pragma mark - Show Detail

static void HBShowAlertDetail(
    UIAlertController *alert,
    BOOL afterOriginal
)
{
    if (HBDetailAlertShown) {
        return;
    }

    HBDetailAlertShown = YES;

    NSString *detail =
        HBAlertDetail(alert);

    if (afterOriginal) {

        detail =
            [NSString stringWithFormat:
                @"原方法执行后\n\n%@",
                detail];
    }

    /*
     * UIAlertController 的 message
     * 太长时会导致界面不好看。
     *
     * 这里最多显示 3500 字符。
     */
    if (detail.length > 3500) {

        detail =
            [detail substringToIndex:3500];
    }

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

            @autoreleasepool {

                UIViewController *vc =
                    HBTopViewController();

                if (!vc) {

                    HBLog(
                        @"无法找到当前 ViewController"
                    );

                    return;
                }

                UIAlertController *debugAlert =
                    [UIAlertController
                        alertControllerWithTitle:
                            @"HB语音 · UIAlertController"
                        message:detail
                        preferredStyle:
                            UIAlertControllerStyleAlert];

                [debugAlert addAction:
                    [UIAlertAction
                        actionWithTitle:@"确定"
                        style:
                            UIAlertActionStyleDefault
                        handler:nil]];

                [vc presentViewController:
                        debugAlert
                    animated:YES
                    completion:^{

                    HBLog(
                        @"UIAlertController 详细信息弹窗已显示"
                    );
                }];
            }
        }
    );
}

#pragma mark - Hooked getNewVoiceServerList:

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

    HBLog(
        @"argument class = %@",
        arg
            ? NSStringFromClass([arg class])
            : @"nil"
    );

    /*
     * 重点：
     * 先分析原始参数。
     */
    if ([arg isKindOfClass:
            [UIAlertController class]]) {

        UIAlertController *alert =
            (UIAlertController *)arg;

        HBLog(
            @"argument is UIAlertController"
        );

        HBLog(
            @"UIAlertController title = %@",
            alert.title
        );

        HBLog(
            @"UIAlertController message = %@",
            alert.message
        );

        HBLog(
            @"UIAlertController actions = %lu",
            (unsigned long)alert.actions.count
        );

        NSUInteger index = 0;

        for (UIAlertAction *action
             in alert.actions) {

            HBLog(
                @"Action[%lu] title = %@",
                (unsigned long)index,
                action.title
            );

            HBLog(
                @"Action[%lu] style = %ld",
                (unsigned long)index,
                (long)action.style
            );

            index++;
        }

    } else {

        HBLog(
            @"argument is NOT UIAlertController"
        );

        HBLog(
            @"argument description = %@",
            HBSafeString(arg)
        );
    }

    /*
     * 第一次调用时显示参数详细内容。
     *
     * 注意：
     * 这里先不显示，等原方法执行之后，
     * 我们再观察它有没有修改 UIAlertController。
     */

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
     * 原方法执行完成以后，
     * 再读取一次 UIAlertController。
     */
    if ([arg isKindOfClass:
            [UIAlertController class]]) {

        UIAlertController *alert =
            (UIAlertController *)arg;

        HBLog(
            @"========== AFTER ORIGINAL =========="
        );

        HBLog(
            @"title = %@",
            alert.title
        );

        HBLog(
            @"message = %@",
            alert.message
        );

        HBLog(
            @"actions count = %lu",
            (unsigned long)alert.actions.count
        );

        NSUInteger index = 0;

        for (UIAlertAction *action
             in alert.actions) {

            HBLog(
                @"AFTER Action[%lu] = %@",
                (unsigned long)index,
                action.title
            );

            index++;
        }

        HBLog(
            @"===================================="
        );

        /*
         * 在主线程显示详细结果。
         */
        HBShowAlertDetail(
            alert,
            YES
        );
    }

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

    Class cls =
        NSClassFromString(
            @"VoiceSelectController"
        );

    if (!cls) {

        HBLog(
            @"VoiceSelectController not found"
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
            @"ERROR: getNewVoiceServerList: not found"
        );

        return NO;
    }

    HBLog(
        @"getNewVoiceServerList: FOUND"
    );

    /*
     * 输出原方法类型编码。
     */
    const char *types =
        method_getTypeEncoding(method);

    HBLog(
        @"Original type encoding = %s",
        types ? types : ""
    );

    IMP oldIMP =
        method_getImplementation(method);

    if (!oldIMP) {

        HBLog(
            @"ERROR: old IMP is NULL"
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
            @"Hook installation complete"
        );

        return;
    }

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            500 * NSEC_PER_MSEC
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
            @"VoiceRebuildInjectTest LOADED"
        );

        NSLog(
            @"[VoiceRebuild] "
            @"UIAlertController analysis enabled"
        );

        NSLog(
            @"========================================"
        );

        /*
         * 微信启动以后立即开始寻找
         * VoiceSelectController。
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{

                HBTryInstallHook();
            }
        );
    }
}
