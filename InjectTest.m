#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#pragma mark - Test Logger

static void HBTestLog(NSString *text) {

    if (!text) {
        return;
    }

    NSLog(@"[HB-INJECT-TEST] %@", text);

    @autoreleasepool {

        NSArray *paths =
            NSSearchPathForDirectoriesInDomains(
                NSDocumentDirectory,
                NSUserDomainMask,
                YES
            );

        NSString *documents =
            [paths firstObject];

        if (!documents) {
            return;
        }

        NSString *path =
            [documents stringByAppendingPathComponent:
                @"HBInjectTest.log"];

        NSString *time =
            [NSString stringWithFormat:
                @"[%@]",
                [NSDate date]];

        NSString *line =
            [NSString stringWithFormat:
                @"%@ %@\n",
                time,
                text];

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
                    @"[HB-INJECT-TEST] 写入失败: %@",
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
                @"[HB-INJECT-TEST] 异常: %@",
                exception
            );

            @try {
                [handle closeFile];
            } @catch (...) {
            }
        }
    }
}

#pragma mark - Constructor

__attribute__((constructor))
static void HBInjectTestConstructor(void) {

    @autoreleasepool {

        HBTestLog(
            @"========================================"
        );

        HBTestLog(
            @"INJECT TEST CONSTRUCTOR START"
        );

        HBTestLog(
            @"InjectTest.m 已经被加载"
        );

        HBTestLog(
            [NSString stringWithFormat:
                @"Process ID = %d",
                getpid()]
        );

        HBTestLog(
            [NSString stringWithFormat:
                @"Process name = %@",
                [[NSProcessInfo processInfo] processName]]
        );

        HBTestLog(
            @"========================================"
        );
    }
}
