#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static void HBWriteLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *path =
        [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/HBInjectTest.log"];

    NSString *line =
        [NSString stringWithFormat:@"[%@] %@\n",
         [NSDate date],
         message];

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (file)
    {
        [file seekToEndOfFile];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
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

static void HBScanViewControllers(void)
{
    HBWriteLog(@"========================================");
    HBWriteLog(@"START VIEW CONTROLLER SCAN");
    HBWriteLog(@"THIS IS THE NEW SCANNER");

    int count = objc_getClassList(NULL, 0);

    HBWriteLog(@"Objective-C class count = %d", count);

    if (count <= 0)
        return;

    Class *classes =
        (__unsafe_unretained Class *)malloc(sizeof(Class) * count);

    int actualCount =
        objc_getClassList(classes, count);

    for (int i = 0; i < actualCount; i++)
    {
        Class cls = classes[i];

        if (!cls)
            continue;

        NSString *name = NSStringFromClass(cls);

        if (!name)
            continue;

        BOOL nameMatched =
            [name rangeOfString:@"Setting"
                         options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"More"
                         options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Profile"
                         options:NSCaseInsensitiveSearch].location != NSNotFound ||
            [name rangeOfString:@"Config"
                         options:NSCaseInsensitiveSearch].location != NSNotFound;

        if (!nameMatched)
            continue;

        if (![cls isSubclassOfClass:[UIViewController class]])
            continue;

        Class superClass = class_getSuperclass(cls);

        NSString *superName =
            superClass ? NSStringFromClass(superClass) : @"<none>";

        HBWriteLog(@"CONTROLLER: %@ | SUPER: %@",
                   name,
                   superName);
    }

    free(classes);

    HBWriteLog(@"END VIEW CONTROLLER SCAN");
    HBWriteLog(@"========================================");
}

__attribute__((constructor))
static void HBInjectTestInit(void)
{
    @autoreleasepool
    {
        HBWriteLog(@"========================================");
        HBWriteLog(@"INJECT TEST START");
        HBWriteLog(@"NEW VERSION 2026-10-05-NEW-SCANNER");
        HBWriteLog(@"PID = %d", getpid());
        HBWriteLog(@"PROCESS = %@",
                   [[NSProcessInfo processInfo] processName]);
        HBWriteLog(@"========================================");

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(5 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                HBScanViewControllers();
            });
    }
}
