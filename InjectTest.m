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

            NSError *error = nil;

            BOOL created =
                [@"" writeToFile:path
                       atomically:YES
                         encoding:NSUTF8StringEncoding
                            error:&error];

            if (!created) {

                NSLog(
                    @"[VoiceRebuild] 创建日志失败: %@",
                    error
                );

                return;
            }
        }

        NSFileHandle *handle =
            [NSFileHandle fileHandleForWritingAtPath:path];

        if (!handle) {

            NSLog(
                @"[VoiceRebuild] 无法打开日志: %@",
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

#pragma mark - Object Logger

static void HBLogObject(id obj, NSString *name) {

    if (!obj) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ = nil",
                name]
        );

        return;
    }

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ class = %@",
            name,
            NSStringFromClass([obj class])]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"%@ description = %@",
            name,
            obj]
    );

    if ([obj isKindOfClass:[UIAlertController class]]) {

        UIAlertController *alert =
            (UIAlertController *)obj;

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ title = %@",
                name,
                alert.title]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ message = %@",
                name,
                alert.message]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"%@ actions = %lu",
                name,
                (unsigned long)alert.actions.count]
        );

        for (UIAlertAction *action in alert.actions) {

            HBWriteLog(
                [NSString stringWithFormat:
                    @"%@ action = %@",
                    name,
                    action.title]
            );
        }
    }
}

#pragma mark - Hook

static void HBHookedGetNewVoiceServerList(
    id self,
    SEL _cmd,
    id arg
) {

    @autoreleasepool {

        HBWriteLog(
            @"========================================"
        );

        HBWriteLog(
            @"getNewVoiceServerList: CALLED"
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"self = %@",
                NSStringFromClass([self class])]
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"selector = %@",
                NSStringFromSelector(_cmd)]
        );

        HBLogObject(
            arg,
            @"ARGUMENT"
        );

        /*
         * 关键测试：
         *
         * 这里暂时不调用原方法。
         *
         * 如果这样微信不再卡死，
         * 就可以确定问题出在：
         *
         * HBOriginalGetNewVoiceServerList(...)
         *
         * 这一行。
         */

        HBWriteLog(
            @"TEST MODE: original method NOT called"
        );

        HBWriteLog(
            @"getNewVoiceServerList: RETURN"
        );

        HBWriteLog(
            @"========================================"
        );

        return;
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
        [NSString stringWithFormat:
            @"VoiceSelectController FOUND: %@",
            cls]
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

        HBWriteLog(
            @"getNewVoiceServerList: NOT FOUND"
        );

        return;
    }

    HBWriteLog(
        @"getNewVoiceServerList: FOUND"
    );

    /*
     * 输出 Objective-C 方法签名
     */

    unsigned int argumentCount =
        method_getNumberOfArguments(method);

    HBWriteLog(
        [NSString stringWithFormat:
            @"argument count = %u",
            argumentCount]
    );

    const char *typeEncoding =
        method_getTypeEncoding(method);

    if (typeEncoding) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"type encoding = %s",
                typeEncoding]
        );
    }

    /*
     * 正常的：
     *
     * self
     * _cmd
     * arg
     *
     * 一共应该是 3 个参数。
     */

    if (argumentCount != 3) {

        HBWriteLog(
            @"WARNING: argument count is NOT 3"
        );

        HBWriteLog(
            @"Hook aborted for safety"
        );

        return;
    }

    IMP oldIMP =
        method_getImplementation(method);

    if (!oldIMP) {

        HBWriteLog(
            @"old IMP = NULL"
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
            cls]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"selector = %@",
            NSStringFromSelector(selector)]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"type encoding = %s",
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
        @"VoiceRebuild dylib LOADED"
    );

    HBWriteLog(
        @"TEST VERSION"
    );

    HBWriteLog(
        @"NO DEBUG WINDOW"
    );

    HBWriteLog(
        @"NO ALERT"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"log path = %@",
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
                @"5 seconds elapsed"
            );

            HookVoiceController();

            /*
             * 如果第一次没找到，
             * 再等 5 秒。
             */

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
