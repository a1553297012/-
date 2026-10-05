#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - 日志

static void HBWriteLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *path =
        [NSHomeDirectory()
         stringByAppendingPathComponent:
         @"Documents/HBInjectTest.log"];

    NSString *line =
        [NSString stringWithFormat:
         @"[%@] %@\n",
         [NSDate date],
         message];

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (file)
    {
        [file seekToEndOfFile];

        [file writeData:
         [line dataUsingEncoding:
          NSUTF8StringEncoding]];

        [file closeFile];
    }
    else
    {
        [line writeToFile:path
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];
    }

    NSLog(@"[HBInjectTest] %@", message);
}

#pragma mark - 扫描设置相关 Class

static void HBScanSettingClasses(void)
{
    HBWriteLog(@"========================================");
    HBWriteLog(@"START SETTING CLASS SCAN");

    int count = objc_getClassList(NULL, 0);

    if (count <= 0)
    {
        HBWriteLog(@"objc_getClassList returned 0");
        return;
    }

    Class *classes =
        (__unsafe_unretained Class *)
        malloc(sizeof(Class) * count);

    int actualCount =
        objc_getClassList(classes, count);

    HBWriteLog(@"Total classes = %d", actualCount);

    for (int i = 0; i < actualCount; i++)
    {
        Class cls = classes[i];

        if (!cls)
            continue;

        NSString *name =
            NSStringFromClass(cls);

        if (!name)
            continue;

        BOOL matched =
            [name rangeOfString:@"Setting"
                         options:NSCaseInsensitiveSearch].location
                != NSNotFound
            ||
            [name rangeOfString:@"More"
                         options:NSCaseInsensitiveSearch].location
                != NSNotFound
            ||
            [name rangeOfString:@"Config"
                         options:NSCaseInsensitiveSearch].location
                != NSNotFound
            ||
            [name rangeOfString:@"Profile"
                         options:NSCaseInsensitiveSearch].location
                != NSNotFound
            ||
            [name rangeOfString:@"Account"
                         options:NSCaseInsensitiveSearch].location
                != NSNotFound;

        if (!matched)
            continue;

        Class superClass =
            class_getSuperclass(cls);

        NSString *superName =
            superClass
            ? NSStringFromClass(superClass)
            : @"<none>";

        HBWriteLog(
            @"FOUND CLASS: %@ | SUPER: %@",
            name,
            superName
        );
    }

    free(classes);

    HBWriteLog(@"END SETTING CLASS SCAN");
    HBWriteLog(@"========================================");
}

#pragma mark - Constructor

__attribute__((constructor))
static void HBInjectTestInit(void)
{
    @autoreleasepool
    {
        HBWriteLog(@"========================================");
        HBWriteLog(@"INJECT TEST CONSTRUCTOR START");

        HBWriteLog(@"InjectTest.m 已经被加载");

        HBWriteLog(
            @"Process ID = %d",
            getpid()
        );

        HBWriteLog(
            @"Process name = %@",
            [[NSProcessInfo processInfo] processName]
        );

        HBWriteLog(@"========================================");

        /*
         * 延迟几秒。
         *
         * 目的：
         * 等微信主程序完成初始化后，
         * 再扫描 Objective-C Class。
         */

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(5 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                HBScanSettingClasses();
            }
        );
    }
}
