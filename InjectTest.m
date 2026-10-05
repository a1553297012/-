#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - Global

typedef void (*HBVoiceOriginalFunc)(id, SEL, id);

static HBVoiceOriginalFunc HBOriginalGetNewVoiceServerList = NULL;
static BOOL HBHookInstalled = NO;

#pragma mark - File Logger

static NSString *HBLogPath(void) {

    return @"/var/mobile/Media/VoiceRebuild.log";
}

static void HBWriteLog(NSString *text) {

    if (!text) {
        return;
    }

    @autoreleasepool {

        NSString *time =
            [[NSDate date] description];

        NSString *line =
            [NSString stringWithFormat:
                @"[%@] %@\n",
                time,
                text];

        /*
         * 同时写系统日志
         */
        NSLog(
            @"[VoiceRebuild] %@",
            text
        );

        /*
         * 写入文件
         */
        NSString *path =
            HBLogPath();

        NSFileManager *fm =
            [NSFileManager defaultManager];

        if (![fm fileExistsAtPath:path]) {

            [@"" writeToFile:
                path
                atomically:YES
                encoding:NSUTF8StringEncoding
                error:nil];
        }

        NSFileHandle *handle =
            [NSFileHandle fileHandleForWritingAtPath:path];

        if (!handle) {

            NSLog(
                @"[VoiceRebuild] "
                @"无法打开日志文件: %@",
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
                @"[VoiceRebuild] "
                @"写日志异常: %@",
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
    id obj,
    NSString *name
) {

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

    /*
     * 如果参数是 UIAlertController，
     * 把里面的信息也记录下来。
     */
    if ([obj isKindOfClass:
            [UIAlertController class]]) {

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
                @"%@ actions count = %lu",
                name,
                (unsigned long)alert.actions.count]
        );

        for (UIAlertAction *action
             in alert.actions) {

            HBWriteLog(
                [NSString stringWithFormat:
                    @"%@ action = %@",
                    name,
                    action.title]
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

    HBWriteLog(
        @"========================================"
    );

    HBWriteLog(
        @"getNewVoiceServerList: CALLED"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"self class = %@",
            NSStringFromClass([self class])]
    );

    HBLogObject(
        arg,
        @"ARGUMENT BEFORE"
    );

    /*
     * 调用 HB 原来的方法
     */
    if (HBOriginalGetNewVoiceServerList) {

        HBOriginalGetNewVoiceServerList(
            self,
            _cmd,
            arg
        );

    } else {

        HBWriteLog(
            @"ERROR: original IMP is NULL"
        );
    }

    /*
     * 原方法执行完成
     */
    HBLogObject(
        arg,
        @"ARGUMENT AFTER"
    );

    HBWriteLog(
        @"getNewVoiceServerList: FINISHED"
    );

    HBWriteLog(
        @"========================================"
    );
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
            @"ERROR: VoiceSelectController not found"
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
            @"ERROR: getNewVoiceServerList: not found"
        );

        return;
    }

    HBWriteLog(
        @"getNewVoiceServerList: FOUND"
    );

    IMP oldIMP =
        method_getImplementation(
            method
        );

    if (!oldIMP) {

        HBWriteLog(
            @"ERROR: old IMP is NULL"
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
            @"log file = %@",
            HBLogPath()]
    );

    HBWriteLog(
        @"========================================"
    );
}

#pragma mark - Delayed Start

static void StartVoiceHook(void) {

    HBWriteLog(
        @"VoiceRebuild loaded"
    );

    HBWriteLog(
        @"Waiting for HB initialization..."
    );

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            5 * NSEC_PER_SEC
        ),
        dispatch_get_main_queue(),
        ^{

            HBWriteLog(
                @"Checking VoiceSelectController..."
            );

            Class cls =
                NSClassFromString(
                    @"VoiceSelectController"
                );

            if (cls) {

                HBWriteLog(
                    @"VoiceSelectController is ready"
                );

                HookVoiceController();

            } else {

                HBWriteLog(
                    @"VoiceSelectController "
                    @"not ready yet"
                );

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

        HBWriteLog(
            @"========================================"
        );

        HBWriteLog(
            @"VoiceRebuild loaded successfully"
        );

        HBWriteLog(
            @"Debug window: DISABLED"
        );

        HBWriteLog(
            @"UIAlertController: DISABLED"
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"Log path: %@",
                HBLogPath()]
        );

        HBWriteLog(
            @"========================================"
        );

        StartVoiceHook();
    }
}
