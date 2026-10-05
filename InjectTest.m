#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static void HBWriteLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *path =
        [NSHomeDirectory()
         stringByAppendingPathComponent:@"Documents/HBInjectTest.log"];

    NSString *line =
        [NSString stringWithFormat:@"[%@] %@\n",
         [NSDate date],
         message];

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (file)
    {
        [file seekToEndOfFile];
        [file writeData:
         [line dataUsingEncoding:NSUTF8StringEncoding]];
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

static UIViewController *HBTopViewController(UIViewController *root)
{
    if (!root)
        return nil;

    if (root.presentedViewController)
    {
        return HBTopViewController(root.presentedViewController);
    }

    if ([root isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *nav =
            (UINavigationController *)root;

        return HBTopViewController(nav.visibleViewController);
    }

    if ([root isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tab =
            (UITabBarController *)root;

        return HBTopViewController(tab.selectedViewController);
    }

    return root;
}

static void HBScanCurrentUI(void)
{
    HBWriteLog(@"========================================");
    HBWriteLog(@"CURRENT UI SCAN");

    UIApplication *app =
        [UIApplication sharedApplication];

    if (!app)
    {
        HBWriteLog(@"UIApplication unavailable");
        return;
    }

    for (UIWindow *window in app.windows)
    {
        if (!window)
            continue;

        if (window.hidden)
            continue;

        if (window.alpha <= 0.01)
            continue;

        UIViewController *root =
            window.rootViewController;

        if (!root)
            continue;

        UIViewController *top =
            HBTopViewController(root);

        if (!top)
            continue;

        HBWriteLog(
            @"WINDOW=%p ROOT=%@ TOP=%@",
            window,
            NSStringFromClass([root class]),
            NSStringFromClass([top class])
        );
    }

    HBWriteLog(@"END CURRENT UI SCAN");
    HBWriteLog(@"========================================");
}

__attribute__((constructor))
static void HBInjectTestInit(void)
{
    @autoreleasepool
    {
        HBWriteLog(@"========================================");
        HBWriteLog(@"INJECT TEST START");
        HBWriteLog(@"SAFE UI SCANNER");
        HBWriteLog(@"PID = %d", getpid());
        HBWriteLog(@"PROCESS = %@",
                   [[NSProcessInfo processInfo] processName]);
        HBWriteLog(@"========================================");

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(8 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{
                HBScanCurrentUI();
            }
        );
    }
}
