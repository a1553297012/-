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
                [line dataUsingEncoding:NSUTF8StringEncoding];

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

#pragma mark - Object Description

static void HBLogObject(
    id object,
    NSString *prefix
) {

    if (!object) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ = nil",
                prefix]
        );

        return;
    }

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ class = %@",
            prefix,
            NSStringFromClass([object class])]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ address = %p",
            prefix,
            object]
    );

    @try {

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ description = %@",
                prefix,
                object]
        );

    } @catch (...) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ description = <exception>",
                prefix]
        );
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
            @"METHOD getNewVoiceServerList: = NOT FOUND"
        );

        return;
    }

    const char *encoding =
        method_getTypeEncoding(method);

    unsigned int argumentCount =
        method_getNumberOfArguments(method);

    IMP implementation =
        method_getImplementation(method);

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

    HBWriteLog(
        [NSString stringWithFormat:
            @"METHOD IMP = %p",
            implementation]
    );
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

        HBWriteLog(@"");
        HBWriteLog(@"########################################");
        HBWriteLog(@"getNewVoiceServerList: ENTER");

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
         * 参数信息
         */

        if (arg) {

            HBLogObject(
                arg,
                @"ARGUMENT"
            );

        } else {

            HBWriteLog(
                @"ARGUMENT = nil"
            );
        }

        /*
         * 如果参数是 UIAlertController，
         * 这里只观察，不修改。
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
         * ========================================
         * 调用真正的原始 IMP
         * ========================================
         *
         * 不改变参数。
         * 不拦截。
         * 不创建弹窗。
         * 不关闭弹窗。
         * 不修改返回结果。
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
         * 原方法结束以后，
         * 再观察一次参数。
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

        HBWriteLog(@"");
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

    HBWriteLog(
        @"Searching VoiceSelectController..."
    );

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

    IMP oldIMP =
        method_getImplementation(method);

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

    HBWriteLog(
        [NSString stringWithFormat:
            @"old IMP = %p",
            oldIMP]
    );

    /*
     * Objective-C 方法：
     *
     * 0 = self
     * 1 = _cmd
     * 2 = arg
     *
     * 所以：
     *
     * argumentCount = 3
     */

    if (argumentCount != 3) {

        HBWriteLog(
            @"WARNING: unexpected argument count"
        );

        HBWriteLog(
            @"HOOK ABORTED"
        );

        return;
    }

    if (!oldIMP) {

        HBWriteLog(
            @"ERROR: old IMP is NULL"
        );

        return;
    }

    /*
     * 保存原始 IMP
     */

    HBOriginalGetNewVoiceServerList =
        (HBVoiceOriginalFunc)oldIMP;

    HBWriteLog(
        @"Original IMP saved"
    );

    /*
     * 安装 Hook
     */

    method_setImplementation(
        method,
        (IMP)HBHookedGetNewVoiceServerList
    );

    /*
     * 验证
     */

    IMP currentIMP =
        method_getImplementation(method);

    HBWriteLog(
        [NSString stringWithFormat:
            @"new IMP = %p",
            currentIMP]
    );

    if (currentIMP ==
        (IMP)HBHookedGetNewVoiceServerList) {

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

    } else {

        HBWriteLog(
            @"ERROR: Hook verification failed"
        );
    }
}

#pragma mark - Retry

static void HBTryInstallHook(void) {

    if (HBHookInstalled) {
        return;
    }

    HBWriteLog(
        @"Trying to install VoiceSelectController hook..."
    );

    HookVoiceController();

    if (HBHookInstalled) {

        HBWriteLog(
            @"Hook installation completed"
        );

        return;
    }

    HBWriteLog(
        @"Hook not installed yet"
    );
}

#pragma mark - Start

static void StartVoiceHook(void) {

    HBWriteLog(
        @"========================================"
    );

    HBWriteLog(
        @"VoiceRebuildInjectTest START"
    );

    HBWriteLog(
        @"MODE = OBSERVE ONLY"
    );

    HBWriteLog(
        @"NO DEBUG ALERT"
    );

    HBWriteLog(
        @"NO ALERT MODIFICATION"
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

    /*
     * 第一次：
     * 等待目标类加载。
     */

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

            HBTryInstallHook();

            /*
             * 第二次尝试
             */

            if (!HBHookInstalled) {

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

                        HBTryInstallHook();

                        /*
                         * 第三次尝试
                         */

                        if (!HBHookInstalled) {

                            dispatch_after(
                                dispatch_time(
                                    DISPATCH_TIME_NOW,
                                    10 * NSEC_PER_SEC
                                ),
                                dispatch_get_main_queue(),
                                ^{

                                    HBWriteLog(
                                        @"Third hook attempt"
                                    );

                                    HBTryInstallHook();
                                }
                            );
                        }
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
            @"Observe-only mode"
        );

        HBWriteLog(
            @"No UIAlertController created"
        );

        HBWriteLog(
            @"No UIAlertController dismissed"
        );

        HBWriteLog(
            @"No original method blocked"
        );

        HBWriteLog(
            @"########################################"
        );

        StartVoiceHook();
    }
}
