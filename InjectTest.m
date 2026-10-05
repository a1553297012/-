#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;
static BOOL HBHookInstalled = NO;

#pragma mark - Log Object

static void HBLogObject(id obj, NSString *name) {

    if (obj == nil) {

        NSLog(
            @"[VoiceRebuild] %@ = nil",
            name
        );

        return;
    }

    NSLog(
        @"[VoiceRebuild] %@ class = %@",
        name,
        NSStringFromClass([obj class])
    );

    NSLog(
        @"[VoiceRebuild] %@ = %@",
        name,
        obj
    );

    if ([obj isKindOfClass:[UIAlertController class]]) {

        UIAlertController *alert =
            (UIAlertController *)obj;

        NSLog(
            @"[VoiceRebuild] %@ title = %@",
            name,
            alert.title
        );

        NSLog(
            @"[VoiceRebuild] %@ message = %@",
            name,
            alert.message
        );

        NSLog(
            @"[VoiceRebuild] %@ actions = %lu",
            name,
            (unsigned long)alert.actions.count
        );

        for (UIAlertAction *action in alert.actions) {

            NSLog(
                @"[VoiceRebuild] %@ action = %@",
                name,
                action.title
            );
        }
    }
}

#pragma mark - Hook Function

static void HBHookedGetNewVoiceServerList(
    id self,
    SEL _cmd,
    id arg
) {

    NSLog(
        @"[VoiceRebuild] ========================================"
    );

    NSLog(
        @"[VoiceRebuild] getNewVoiceServerList: CALLED"
    );

    NSLog(
        @"[VoiceRebuild] self = %@",
        self
    );

    NSLog(
        @"[VoiceRebuild] self class = %@",
        NSStringFromClass([self class])
    );

    HBLogObject(
        arg,
        @"ARGUMENT BEFORE"
    );

    /*
     * 调用 HB 原来的实现
     */
    if (HBOriginalGetNewVoiceServerList != NULL) {

        HBOriginalGetNewVoiceServerList(
            self,
            _cmd,
            arg
        );

    } else {

        NSLog(
            @"[VoiceRebuild] ERROR: original IMP is NULL"
        );
    }

    /*
     * 原方法执行以后再次读取
     */
    HBLogObject(
        arg,
        @"ARGUMENT AFTER"
    );

    NSLog(
        @"[VoiceRebuild] getNewVoiceServerList: FINISHED"
    );

    NSLog(
        @"[VoiceRebuild] ========================================"
    );
}

#pragma mark - Install Hook

static void HookVoiceController(void) {

    if (HBHookInstalled) {

        NSLog(
            @"[VoiceRebuild] Hook already installed"
        );

        return;
    }

    Class cls =
        NSClassFromString(
            @"VoiceSelectController"
        );

    if (cls == Nil) {

        NSLog(
            @"[VoiceRebuild] ERROR: "
            @"VoiceSelectController not found"
        );

        return;
    }

    NSLog(
        @"[VoiceRebuild] VoiceSelectController FOUND: %@",
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

    if (method == NULL) {

        NSLog(
            @"[VoiceRebuild] ERROR: "
            @"getNewVoiceServerList: not found"
        );

        return;
    }

    NSLog(
        @"[VoiceRebuild] "
        @"getNewVoiceServerList: FOUND"
    );

    IMP oldIMP =
        method_getImplementation(
            method
        );

    if (oldIMP == NULL) {

        NSLog(
            @"[VoiceRebuild] ERROR: old IMP is NULL"
        );

        return;
    }

    HBOriginalGetNewVoiceServerList =
        (HBVoiceOriginalFunc)oldIMP;

    method_setImplementation(
        method,
        (IMP)HBHookedGetNewVoiceServerList
    );

    HBHookInstalled = YES;

    NSLog(
        @"[VoiceRebuild] ========================================"
    );

    NSLog(
        @"[VoiceRebuild] HOOK INSTALLED SUCCESSFULLY"
    );

    NSLog(
        @"[VoiceRebuild] class = %@",
        cls
    );

    NSLog(
        @"[VoiceRebuild] selector = %@",
        NSStringFromSelector(selector)
    );

    NSLog(
        @"[VoiceRebuild] ========================================"
    );
}

#pragma mark - Delayed Start

static void StartVoiceHook(void) {

    NSLog(
        @"[VoiceRebuild] Waiting for HB initialization..."
    );

    /*
     * 不使用递归 Block。
     * 直接延迟 5 秒检查一次。
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            5 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{

            NSLog(
                @"[VoiceRebuild] Checking "
                @"VoiceSelectController..."
            );

            Class cls =
                NSClassFromString(
                    @"VoiceSelectController"
                );

            if (cls != Nil) {

                NSLog(
                    @"[VoiceRebuild] "
                    @"VoiceSelectController is ready"
                );

                HookVoiceController();

            } else {

                NSLog(
                    @"[VoiceRebuild] "
                    @"VoiceSelectController not ready yet"
                );

                /*
                 * 再等 5 秒。
                 */
                dispatch_after(
                    dispatch_time(
                        DISPATCH_TIME_NOW,
                        5 * NSEC_PER_SEC
                    ),
                    dispatch_get_main_queue(),
                    ^{

                        HookVoiceController();
                    }
                );
            }
        }
    );
}

#pragma mark - Constructor

__attribute__((constructor))
static void VoiceRebuildInjectTest_Loaded(void) {

    @autoreleasepool {

        NSLog(
            @"[VoiceRebuild] ========================================"
        );

        NSLog(
            @"[VoiceRebuild] VoiceRebuild loaded successfully"
        );

        NSLog(
            @"[VoiceRebuild] Debug window: DISABLED"
        );

        NSLog(
            @"[VoiceRebuild] UIAlertController: DISABLED"
        );

        NSLog(
            @"[VoiceRebuild] ========================================"
        );

        StartVoiceHook();
    }
}
