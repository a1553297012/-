#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <unistd.h>

#pragma mark - Logger

static NSString *HBLogPath(void) {

    NSArray *paths =
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        );

    NSString *documents = [paths firstObject];

    if (!documents) {
        return nil;
    }

    return [documents stringByAppendingPathComponent:
        @"HBInjectTest.log"];
}

static void HBWriteLog(NSString *text) {

    if (!text) {
        return;
    }

    @autoreleasepool {

        NSString *line =
            [NSString stringWithFormat:
                @"[%@] %@\n",
                [NSDate date],
                text];

        NSLog(@"[HB-SCAN] %@", text);

        NSString *path = HBLogPath();

        if (!path) {
            return;
        }

        NSFileHandle *handle =
            [NSFileHandle fileHandleForWritingAtPath:path];

        if (!handle) {

            NSError *error = nil;

            [line writeToFile:path
                   atomically:YES
                     encoding:NSUTF8StringEncoding
                        error:&error];

            if (error) {

                NSLog(
                    @"[HB-SCAN] 创建日志失败: %@",
                    error
                );
            }

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
                @"[HB-SCAN] 写日志异常: %@",
                exception
            );

            @try {
                [handle closeFile];
            } @catch (...) {
            }
        }
    }
}

#pragma mark - Method Information

static void HBScanMethod(
    Class cls,
    NSString *selectorName
) {

    if (!cls || !selectorName) {
        return;
    }

    HBWriteLog(
        [NSString stringWithFormat:
            @"----------------------------------------"]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"Searching method: %@",
            selectorName]
    );

    SEL selector =
        NSSelectorFromString(selectorName);

    Method method =
        class_getInstanceMethod(
            cls,
            selector
        );

    if (!method) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"METHOD NOT FOUND: %@",
                selectorName]
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
            @"METHOD FOUND: %@",
            selectorName]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"TYPE ENCODING: %s",
            encoding ? encoding : "(null)"]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"ARGUMENT COUNT: %u",
            argumentCount]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"IMP ADDRESS: %p",
            implementation]
    );

    /*
     * 输出每一个参数的类型编码。
     */

    for (unsigned int i = 0;
         i < argumentCount;
         i++) {

        char buffer[256] = {0};

        method_getArgumentType(
            method,
            i,
            buffer,
            sizeof(buffer)
        );

        HBWriteLog(
            [NSString stringWithFormat:
                @"ARG[%u] TYPE: %s",
                i,
                buffer]
        );
    }
}

#pragma mark - Scan Class

static void HBScanVoiceController(void) {

    HBWriteLog(
        @"========================================"
    );

    HBWriteLog(
        @"START VoiceSelectController SCAN"
    );

    Class cls =
        NSClassFromString(
            @"VoiceSelectController"
        );

    if (!cls) {

        HBWriteLog(
            @"VoiceSelectController NOT FOUND"
        );

        HBWriteLog(
            @"========================================"
        );

        return;
    }

    HBWriteLog(
        @"VoiceSelectController FOUND"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"CLASS ADDRESS: %p",
            cls]
    );

    Class superClass =
        class_getSuperclass(cls);

    if (superClass) {

        HBWriteLog(
            [NSString stringWithFormat:
                @"SUPER CLASS: %@",
                NSStringFromClass(superClass)]
        );
    }

    /*
     * 检查我们之前关注的方法。
     */

    HBScanMethod(
        cls,
        @"getNewVoiceServerList:"
    );

    HBScanMethod(
        cls,
        @"GetVoiceServerList"
    );

    HBScanMethod(
        cls,
        @"GetReVoice"
    );

    /*
     * 输出该类自己的实例方法列表。
     */

    unsigned int methodCount = 0;

    Method *methods =
        class_copyMethodList(
            cls,
            &methodCount
        );

    HBWriteLog(
        [NSString stringWithFormat:
            @"INSTANCE METHOD COUNT: %u",
            methodCount]
    );

    if (methods) {

        for (unsigned int i = 0;
             i < methodCount;
             i++) {

            SEL selector =
                method_getName(methods[i]);

            const char *name =
                sel_getName(selector);

            if (name) {

                HBWriteLog(
                    [NSString stringWithFormat:
                        @"METHOD[%u]: %s",
                        i,
                        name]
                );
            }
        }

        free(methods);
    }

    HBWriteLog(
        @"END VoiceSelectController SCAN"
    );

    HBWriteLog(
        @"========================================"
    );
}

#pragma mark - Delayed Scan

static void HBStartScan(void) {

    HBWriteLog(
        @"========================================"
    );

    HBWriteLog(
        @"HB SCAN START"
    );

    HBWriteLog(
        @"InjectTest.m is running"
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"PROCESS ID: %d",
            getpid()]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"PROCESS NAME: %@",
            [[NSProcessInfo processInfo] processName]]
    );

    HBWriteLog(
        [NSString stringWithFormat:
            @"LOG PATH: %@",
            HBLogPath()]
    );

    HBWriteLog(
        @"NO HOOK"
    );

    HBWriteLog(
        @"NO METHOD MODIFICATION"
    );

    HBWriteLog(
        @"NO ALERT"
    );

    HBWriteLog(
        @"========================================"
    );

    /*
     * 延迟几秒，给微信自己的类加载时间。
     */

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

            HBScanVoiceController();
        }
    );
}

#pragma mark - Constructor

__attribute__((constructor))
static void HBInjectTestConstructor(void) {

    @autoreleasepool {

        HBWriteLog(
            @"########################################"
        );

        HBWriteLog(
            @"HB INJECT TEST CONSTRUCTOR"
        );

        HBWriteLog(
            @"InjectTest.m LOADED"
        );

        HBWriteLog(
            @"########################################"
        );

        HBStartScan();
    }
}
