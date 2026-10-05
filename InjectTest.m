#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *HBLogPath(void) {
    NSArray *paths =
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        );

    return [paths.firstObject
            stringByAppendingPathComponent:@"HBCallTrace.log"];
}

static void HBLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);

    NSString *msg =
        [[NSString alloc] initWithFormat:format
                            arguments:args];

    va_end(args);

    NSString *line =
        [NSString stringWithFormat:@"[%@] %@\n",
         [NSDate date], msg];

    NSString *path = HBLogPath();

    NSFileHandle *fh =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!fh) {
        [[NSFileManager defaultManager]
            createFileAtPath:path
            contents:nil
            attributes:nil];

        fh =
            [NSFileHandle fileHandleForWritingAtPath:path];
    }

    [fh seekToEndOfFile];
    [fh writeData:
        [line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];

    NSLog(@"%@", msg);
}

static void HBLogStack(void) {

    NSArray *stack =
        [NSThread callStackSymbols];

    HBLog(@"========== CALL STACK ==========");

    NSUInteger count = MIN(stack.count, (NSUInteger)15);

    for (NSUInteger i = 0; i < count; i++) {
        HBLog(@"STACK[%lu] %@",
              (unsigned long)i,
              stack[i]);
    }

    HBLog(@"========== END STACK ==========");
}

#pragma mark -
#pragma mark Original IMP

static void (*HBOriginalGetReVoice)(id, SEL);

static void (*HBOriginalGetNewVoiceServerList)(
    id,
    SEL,
    id
);

#pragma mark -
#pragma mark GetReVoice

static void HB_GetReVoice(id self, SEL _cmd) {

    HBLog(@"========================================");
    HBLog(@"CALL GetReVoice");
    HBLog(@"self = %@", self);

    HBLogStack();

    HBLog(@"---- CALL ORIGINAL GetReVoice ----");

    if (HBOriginalGetReVoice) {
        HBOriginalGetReVoice(
            self,
            _cmd
        );
    }

    HBLog(@"---- RETURN ORIGINAL GetReVoice ----");
}

#pragma mark -
#pragma mark getNewVoiceServerList:

static void HB_getNewVoiceServerList(
    id self,
    SEL _cmd,
    id arg
) {

    HBLog(@"========================================");
    HBLog(@"CALL getNewVoiceServerList:");
    HBLog(@"self = %@", self);
    HBLog(@"arg class = %@", [arg class]);
    HBLog(@"arg = %@", arg);

    HBLogStack();

    HBLog(@"---- CALL ORIGINAL getNewVoiceServerList: ----");

    if (HBOriginalGetNewVoiceServerList) {
        HBOriginalGetNewVoiceServerList(
            self,
            _cmd,
            arg
        );
    }

    HBLog(@"---- RETURN ORIGINAL getNewVoiceServerList: ----");
}

#pragma mark -
#pragma mark Install

static void HBInstallTrace(void) {

    Class cls =
        NSClassFromString(@"VoiceSelectController");

    if (!cls) {
        HBLog(@"VoiceSelectController NOT FOUND");
        return;
    }

    HBLog(@"VoiceSelectController FOUND");

    /*
     * GetReVoice
     */

    Method method =
        class_getInstanceMethod(
            cls,
            @selector(GetReVoice)
        );

    if (method) {

        IMP original =
            method_getImplementation(method);

        HBOriginalGetReVoice =
            (void (*)(id, SEL))original;

        method_setImplementation(
            method,
            (IMP)HB_GetReVoice
        );

        HBLog(@"HOOKED GetReVoice");
        HBLog(@"ORIGINAL IMP = %p",
              original);
    }

    /*
     * getNewVoiceServerList:
     */

    method =
        class_getInstanceMethod(
            cls,
            @selector(getNewVoiceServerList:)
        );

    if (method) {

        IMP original =
            method_getImplementation(method);

        HBOriginalGetNewVoiceServerList =
            (void (*)(id, SEL, id))original;

        method_setImplementation(
            method,
            (IMP)HB_getNewVoiceServerList
        );

        HBLog(@"HOOKED getNewVoiceServerList:");
        HBLog(@"ORIGINAL IMP = %p",
              original);
    }

    HBLog(@"========================================");
    HBLog(@"TRACE INSTALL FINISHED");
}

#pragma mark -
#pragma mark Constructor

__attribute__((constructor))
static void HBInit(void) {

    HBLog(@"========================================");
    HBLog(@"HB CALL TRACE V2 LOADED");
    HBLog(@"PROCESS = %@",
          [[NSProcessInfo processInfo] processName]);

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(5.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            HBInstallTrace();
        }
    );
}
