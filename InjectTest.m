#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoidFunc)(id, SEL);
typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static BOOL HBViewHookInstalled = NO;
static BOOL HBMethodHookInstalled = NO;

static HBVoidFunc HBOriginalViewDidAppear = NULL;
static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;

static BOOL HBViewAlertShown = NO;
static BOOL HBMethodAlertShown = NO;

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
        window = [UIApplication sharedApplication].keyWindow;
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
        vc = vc.presentedViewController;
    }

    return vc;
}

#pragma mark - Alert

static void HBShowAlert(NSString *title,
                        NSString *message)
{
    dispatch_async(dispatch_get_main_queue(), ^{

        @autoreleasepool {

            UIViewController *vc =
                HBTopViewController();

            if (!vc) {
                HBLog(@"无法找到当前 ViewController");
                return;
            }

            UIAlertController *alert =
                [UIAlertController
                    alertControllerWithTitle:title
                    message:message
                    preferredStyle:UIAlertControllerStyleAlert];

            [alert addAction:
                [UIAlertAction
                    actionWithTitle:@"确定"
                    style:UIAlertActionStyleDefault
                    handler:nil]];

            [vc presentViewController:alert
                             animated:YES
                           completion:nil];
        }
    });
}

#pragma mark - Dump VoiceSelectController Methods

static void HBDumpVoiceMethods(Class cls)
{
    unsigned int count = 0;

    Method *methods =
        class_copyMethodList(cls, &count);

    if (!methods) {
        HBLog(@"无法获取 VoiceSelectController 方法列表");
        return;
    }

    NSMutableArray *names =
        [NSMutableArray array];

    HBLog(
        @"VoiceSelectController 方法数量: %u",
        count
    );

    for (unsigned int i = 0; i < count; i++) {

        Method method = methods[i];

        SEL selector =
            method_getName(method);

        const char *types =
            method_getTypeEncoding(method);

        NSString *name =
            NSStringFromSelector(selector);

        if (!name) {
            continue;
        }

        HBLog(
            @"METHOD[%u] %@  type=%s",
            i,
            name,
            types ? types : ""
        );

        /*
         * 只把比较有意义的方法放进弹窗。
         */
        if ([name containsString:@"Voice"] ||
            [name containsString:@"voice"] ||
            [name containsString:@"Server"] ||
            [name containsString:@"server"] ||
            [name containsString:@"List"] ||
            [name containsString:@"list"] ||
            [name containsString:@"load"] ||
            [name containsString:@"Load"] ||
            [name containsString:@"request"] ||
            [name containsString:@"Request"] ||
            [name containsString:@"reload"] ||
            [name containsString:@"Reload"]) {

            [names addObject:name];
        }
    }

    free(methods);

    if (names.count == 0) {

        HBLog(
            @"没有发现明显的语音/列表相关方法"
        );

        return;
    }

    NSString *message =
        [names componentsJoinedByString:@"\n"];

    /*
     * 防止弹窗过长
     */
    if (message.length > 2500) {

        message =
            [message substringToIndex:2500];
    }

    HBShowAlert(
        @"VoiceSelectController 方法",
        message
    );
}

#pragma mark - viewDidAppear Hook

static void HBHookedViewDidAppear(
    id self,
    SEL _cmd
)
{
    HBLog(
        @"========================================"
    );

    HBLog(
        @"VoiceSelectController viewDidAppear:"
    );

    HBLog(
        @"self = %@",
        NSStringFromClass([self class])
    );

    HBLog(
        @"========================================"
    );

    if (!HBViewAlertShown) {

        HBViewAlertShown = YES;

        HBShowAlert(
            @"HB语音侦察",
            @"VoiceSelectController 已经显示\n\n"
             "说明我们现在进入了目标页面"
        );
    }

    /*
     * 调用原始 viewDidAppear:
     */
    if (HBOriginalViewDidAppear) {

        HBOriginalViewDidAppear(
            self,
            _cmd
        );
    }
}

#pragma mark - getNewVoiceServerList Hook

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
        @"argument class = %@",
        arg ? NSStringFromClass([arg class]) : @"nil"
    );

    HBLog(
        @"argument = %@",
        arg
    );

    HBLog(
        @"========================================"
    );

    /*
     * 第一次真正调用时弹窗
     */
    if (!HBMethodAlertShown) {

        HBMethodAlertShown = YES;

        NSString *message =
            [NSString stringWithFormat:
                @"getNewVoiceServerList: 已被调用\n\n"
                 "参数类型：%@\n\n"
                 "参数：%@",
                arg
                    ? NSStringFromClass([arg class])
                    : @"nil",
                arg ? [NSString stringWithFormat:@"%@", arg]
                    : @"nil"];

        if (message.length > 2500) {
            message =
                [message substringToIndex:2500];
        }

        HBShowAlert(
            @"HB语音方法调用",
            message
        );
    }

    /*
     * 调用原方法
     */
    if (HBOriginalGetNewVoiceServerList) {

        HBOriginalGetNewVoiceServerList(
            self,
            _cmd,
            arg
        );
    }
}

#pragma mark - Install viewDidAppear Hook

static BOOL InstallViewDidAppearHook(Class cls)
{
    if (HBViewHookInstalled) {
        return YES;
    }

    SEL selector =
        @selector(viewDidAppear:);

    Method method =
        class_getInstanceMethod(
            cls,
            selector
        );

    if (!method) {

        HBLog(
            @"VoiceSelectController 没有 viewDidAppear:"
        );

        return NO;
    }

    IMP oldIMP =
        method_getImplementation(method);

    if (!oldIMP) {
        return NO;
    }

    HBOriginalViewDidAppear =
        (HBVoidFunc)oldIMP;

    method_setImplementation(
        method,
        (IMP)HBHookedViewDidAppear
    );

    HBViewHookInstalled = YES;

    HBLog(
        @"viewDidAppear: Hook 成功"
    );

    return YES;
}

#pragma mark - Install getNewVoiceServerList Hook

static BOOL InstallVoiceMethodHook(Class cls)
{
    if (HBMethodHookInstalled) {
        return YES;
    }

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
            @"getNewVoiceServerList: 不存在"
        );

        return NO;
    }

    IMP oldIMP =
        method_getImplementation(method);

    if (!oldIMP) {
        return NO;
    }

    HBOriginalGetNewVoiceServerList =
        (HBVoiceOriginalFunc)oldIMP;

    method_setImplementation(
        method,
        (IMP)HBHookedGetNewVoiceServerList
    );

    HBMethodHookInstalled = YES;

    HBLog(
        @"getNewVoiceServerList: Hook 成功"
    );

    /*
     * 输出真实类型编码
     */
    const char *types =
        method_getTypeEncoding(method);

    HBLog(
        @"getNewVoiceServerList: type=%s",
        types ? types : ""
    );

    return YES;
}

#pragma mark - Install All Hooks

static void InstallHooks(void)
{
    Class cls =
        NSClassFromString(
            @"VoiceSelectController"
        );

    if (!cls) {

        HBLog(
            @"VoiceSelectController 尚未加载"
        );

        return;
    }

    HBLog(
        @"VoiceSelectController FOUND"
    );

    /*
     * 第一次发现类时把方法全部列出来
     */
    HBDumpVoiceMethods(cls);

    /*
     * Hook 页面出现
     */
    InstallViewDidAppearHook(cls);

    /*
     * Hook 目标方法
     */
    InstallVoiceMethodHook(cls);
}

#pragma mark - Retry

static void HBTryInstall(void)
{
    InstallHooks();

    if (HBViewHookInstalled &&
        HBMethodHookInstalled) {

        HBLog(
            @"所有侦察 Hook 已安装"
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
            HBTryInstall();
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
            @"[VoiceRebuild] DLL LOADED"
        );

        NSLog(
            @"[VoiceRebuild] 开始侦察 VoiceSelectController"
        );

        NSLog(
            @"========================================"
        );

        /*
         * 立即开始检查。
         *
         * 不再等待 5 秒，
         * 防止目标方法在前面已经调用过。
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                HBTryInstall();
            }
        );
    }
}
