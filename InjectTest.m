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

static void HBHookViewDidAppear(void)
{
    Class cls = [UIViewController class];

    SEL sel = @selector(viewDidAppear:);

    Method method =
        class_getInstanceMethod(cls, sel);

    if (!method)
    {
        HBWriteLog(@"viewDidAppear method not found");
        return;
    }

    IMP originalIMP =
        method_getImplementation(method);

    static IMP savedOriginalIMP = NULL;

    savedOriginalIMP = originalIMP;

    IMP newIMP =
        imp_implementationWithBlock(
            ^(UIViewController *self,
              BOOL animated)
            {
                /*
                 * 先执行系统原来的 viewDidAppear
                 */
                ((void (*)(id, SEL, BOOL))
                 savedOriginalIMP)(
                    self,
                    sel,
                    animated
                );

                /*
                 * 只记录真正出现的页面
                 */
                NSString *className =
                    NSStringFromClass([self class]);

                NSString *title =
                    self.navigationItem.title;

                HBWriteLog(
                    @"VIEW APPEAR: %@ | TITLE=%@ | NAV=%@",
                    className,
                    title ?: @"<nil>",
                    self.navigationController
                    ? NSStringFromClass(
                        [self.navigationController class])
                    : @"<nil>"
                );
            }
        );

    method_setImplementation(method, newIMP);

    HBWriteLog(@"UIViewController viewDidAppear hooked");
}

__attribute__((constructor))
static void HBInjectTestInit(void)
{
    @autoreleasepool
    {
        HBWriteLog(@"========================================");
        HBWriteLog(@"INJECT TEST START");
        HBWriteLog(@"VIEW APPEAR LOGGER");
        HBWriteLog(@"PID = %d", getpid());
        HBWriteLog(@"PROCESS = %@",
                   [[NSProcessInfo processInfo] processName]);
        HBWriteLog(@"========================================");

        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                HBHookViewDidAppear();
            }
        );
    }
}
