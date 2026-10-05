#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;
static BOOL HBHookInstalled = NO;

#pragma mark - Logger

static NSString *HBLogPath(void) {
    return @"/var/mobile/Media/VoiceRebuild.log";
}

static void HBWriteLog(NSString *text) {

    if (!text) {
        return;
    }

    @autoreleasepool {

        NSString *time =
            [NSString stringWithFormat:@"%@", [NSDate date]];

        NSString *line =
            [NSString stringWithFormat:
                @"[%@] %@\n",
                time,
                text];

        NSLog(@"[VoiceRebuild] %@", text);

        NSString *path = HBLogPath();

        NSFileManager *fm =
            [NSFileManager defaultManager];

        if (![fm fileExistsAtPath:path]) {

            NSError *createError = nil;

            BOOL created =
                [@"" writeToFile:path
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:&createError];

            if (!created) {

                NSLog(
                    @"[VoiceRebuild] 创建日志失败: %@",
                    createError
                );

                return;
            }
        }

        NSFileHandle *handle =
            [NSFileHandle fileHandleForWritingAtPath:path];

        if (!handle) {

            NSLog(
                @"[VoiceRebuild] 打开日志失败: %@",
                path
            );

            return;
        }

        @try {

            [handle seekToEndOfFile];

            NSData *data =
                [line dataUsingEncoding:
                    NSUTF8StringEncoding];

            [handle writeData:data];

            [handle closeFile];

        } @catch (NSException *exception) {

            NSLog(
                @"[VoiceRebuild] 写日志异常: %@",
                exception
            );

            @try {
                [handle closeFile];
            } @catch (...) {
            }
        }
    }
}

#pragma mark - Alert Logger

static void HBLogAlert(
    UIAlertController *alert,
    NSString *prefix
) {

    if (!alert) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ = nil",
                prefix]
        );

        return;
    }

    HBWriteLog(
        @"----------------------------------------"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ class = %@",
            prefix,
            NSStringFromClass([alert class])]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ address = %p",
            prefix,
            alert]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ title = %@",
            prefix,
            alert.title]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ message = %@",
            prefix,
            alert.message]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ preferredStyle = %ld",
            prefix,
            (long)alert.preferredStyle]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ actions count = %lu",
            prefix,
            (unsigned long)alert.actions.count]
    );

    NSUInteger index = 0;

    for (UIAlertAction *action in alert.actions) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ action[%lu] title = %@",
                prefix,
                (unsigned long)index,
                action.title]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ action[%lu] style = %ld",
                prefix,
                (unsigned long)index,
                (long)action.style]
        );

        index++;
    }

    HBWriteLog(
        @"----------------------------------------"
    );
}

#pragma mark - Runtime Information

static void HBLogClassInformation(Class cls) {

    if (!cls) {
        return;
    }

    HBWriteLog(
        [NSString stringWithFormat:
            @"TARGET CLASS = %@",
            NSStringFromClass(cls)]
    );

    Class superClass =
        class_getSuperclass(cls);

    if (superClass) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"SUPER CLASS = %@",
                NSStringFromClass(superClass)]
        );
    }

    Method method =
        class_getInstanceMethod(
            cls,
            @selector(getNewVoiceServerList:)
        );

    if (method) {

        const char *encoding =
            method_getTypeEncoding(method);

        unsigned int argumentCount =
            method_getNumberOfArguments(method);

        HBWriteLog(
            [NSString stringWithFormat:
                @"METHOD TYPE ENCODING = %s",
                encoding ? encoding : "(null)"]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"METHOD ARGUMENT COUNT = %u",
                argumentCount]
        );
    }
}

#pragma mark - Stack Trace

static void HBLogStackTrace(void) {

    NSArray *stack =
        [NSThread callStackSymbols];

    HBWriteLog(
        @"========== CALL STACK =========="
    );

    NSUInteger index = 0;

    for (NSString *item in stack) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"STACK[%lu] %@",
                (unsigned long)index,
                item]
        );

        index++;

        /*
         * 不需要把几百行全部记录下来。
         */
        if (index >= 20) {
            break;
        }
    }

    HBWriteLog(
        @"========== END STACK =========="
    );
}

#pragma mark - Hook

static void HBHookedGetNewVoiceServerList(
    id self,
    SEL _cmd,
    id arg
) {

    @autoreleasepool {

        HBWriteLog(
            @""
        );

        HBWriteLog(
            @"########################################"
        );

        HBWriteLog(
            @"getNewVoiceServerList: ENTER"
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"self class = %@",
                NSStringFromClass([self class])]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"self address = %p",
                self]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"selector = %@",
                NSStringFromSelector(_cmd)]
        );

        /*
         * 记录参数
         */

        if (arg) {

            HBWriteLog(
                [NSString stringWithFormat:
                    @"ARGUMENT class = %@",
                    NSStringFromClass([arg class])]
            );

            HBWriteLog(
                [NSString stringWithFormat:
                    @"ARGUMENT address = %p",
                    arg]
            );

            HBWriteLog(
                [NSString stringWithFormat:
                    @"ARGUMENT description = %@",
                    arg]
            );

        } else {

            HBWriteLog(
                @"ARGUMENT = nil"
            );
        }

        /*
         * 如果参数是 UIAlertController，
         * 详细记录它。
         */

        if ([arg isKindOfClass:
                [UIAlertController class]]) {

            HBLogAlert(
                (UIAlertController *)arg,
                @"ARGUMENT ALERT BEFORE"
            );
        }

        /*
         * 记录调用栈
         */

        HBLogStackTrace();

        /*
         * ====================================
         * 关键部分
         * ====================================
         *
         * 这一次恢复调用原始方法。
         *
         * 所以不会像上一版一样卡在：
         *
         *     正在获取...
         *
         */

        HBWriteLog(
            @"CALLING ORIGINAL METHOD"
        );

        if (HBOriginalGetNewVoiceServerList) {

            HBOriginalGetNewVoiceServerList(
                self,
                _cmd,
                arg
            );

            HBWriteLog(
                @"ORIGINAL METHOD RETURNED"
            );

        } else {

            HBWriteLog(
                @"ERROR: ORIGINAL IMP IS NULL"
            );
        }

        /*
         * 原方法返回以后，再记录一次参数。
         *
         * 如果 UIAlertController 内容发生变化，
         * 这里可以看到。
         */

        if ([arg isKindOfClass:
                [UIAlertController class]]) {

            HBLogAlert(
                (UIAlertController *)arg,
                @"ARGUMENT ALERT AFTER"
            );
        }

        HBWriteLog(
            @"getNewVoiceServerList: EXIT"
        );

        HBWriteLog(
            @"########################################"
        );

        HBWriteLog(
            @""
        );
    }
}

#pragma mark - Install Hook

static void HookVoiceController(void) {

    if (HBHookInstalled) {

        HBWriteLog(
            @"Hook already installed"
        );

        return;
    }

    Class cls =
        NSClassFromString(
            @"VoiceSelectController"
        );

    if (!cls) {

        HBWriteLog(
            @"VoiceSelectController NOT FOUND"
        );

        return;
    }

    HBWriteLog(
        @"VoiceSelectController FOUND"
    );

    HBLogClassInformation(cls);

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

        HBWriteLog(
            @"getNewVoiceServerList: NOT FOUND"
        );

        return;
    }

    HBWriteLog(
        @"getNewVoiceServerList: FOUND"
    );

    const char *typeEncoding =
        method_getTypeEncoding(method);

    unsigned int argumentCount =
        method_getNumberOfArguments(method);

    HBWriteLog(
        [NSString stringWithFormat:
            @"type encoding = %s",
            typeEncoding ? typeEncoding : "(null)"]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"argument count = %u",
            argumentCount]
    );

    /*
     * 当前我们已经验证过这个 Hook 能正常进入。
     *
     * 正常 Objective-C：
     *
     * 0 = self
     * 1 = _cmd
     * 2 = arg
     *
     * 所以这里应该是 3。
     */

    if (argumentCount != 3) {

        HBWriteLog(
            @"WARNING: unexpected argument count"
        );

        HBWriteLog(
            @"Hook aborted"
        );

        return;
    }

    IMP oldIMP =
        method_getImplementation(method);

    if (!oldIMP) {

        HBWriteLog(
            @"ERROR: old IMP is NULL"
        );

        return;
    }

    HBOriginalGetNewVoiceServerList =
        (HBVoiceOriginalFunc)oldIMP;

    HBWriteLog(
        @"Original IMP saved"
    );

    method_setImplementation(
        method,
        (IMP)HBHookedGetNewVoiceServerList
    );

    HBHookInstalled = YES;

    HBWriteLog(
        @"========================================"
    );

    HBWriteLog(
        @"HOOK INSTALLED SUCCESSFULLY"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"class = %@",
            NSStringFromClass(cls)]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"selector = %@",
            NSStringFromSelector(selector)]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"encoding = %s",
            typeEncoding ? typeEncoding : "(null)"]
    );

    HBWriteLog(
        @"========================================"
    );
}

#pragma mark - Start

static void StartVoiceHook(void) {

    HBWriteLog(
        @"========================================"
    );

    HBWriteLog(
        @"VoiceRebuildInjectTest LOADED"
    );

    HBWriteLog(
        @"NORMAL MODE"
    );

    HBWriteLog(
        @"NO ALERT"
    );

    HBWriteLog(
        @"ORIGINAL METHOD WILL RUN"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"LOG PATH = %@",
            HBLogPath()]
    );

    HBWriteLog(
        @"========================================"
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            5 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{

            HBWriteLog(
                @"First hook attempt"
            );

            HookVoiceController();

            if (!HBHookInstalled) {

                HBWriteLog(
                    @"First attempt failed"
                );

                dispatch_after(
                    dispatch_time(
                        DISPATCH_TIME_NOW,
                        5 * NSEC_PER_SEC
                    ),
                    dispatch_get_main_queue(),
                    ^{

                        HBWriteLog(
                            @"Second hook attempt"
                        );

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

        HBWriteLog(
            @"########################################"
        );

        HBWriteLog(
            @"VoiceRebuild constructor START"
        );

        HBWriteLog(
            @"VoiceRebuildInjectTest loaded successfully"
        );

        HBWriteLog(
            @"########################################"
        );

        StartVoiceHook();
    }
}
