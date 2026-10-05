#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

#pragma mark - 日志

static void VoicePluginLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *path =
        [NSHomeDirectory() stringByAppendingPathComponent:
         @"Documents/VoicePlugin.log"];

    NSString *line =
        [NSString stringWithFormat:@"[%@] %@\n",
         [NSDate date], message];

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!file) {
        [line writeToFile:path
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];
    } else {
        [file seekToEndOfFile];
        [file writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
    }

    NSLog(@"[VoicePlugin] %@", message);
}

#pragma mark - 原始 IMP

static IMP OriginalGetReVoice = NULL;
static IMP OriginalGetNewVoiceServerList = NULL;

#pragma mark - Hook: GetReVoice

static void VoicePlugin_GetReVoice(id self, SEL _cmd) {

    VoicePluginLog(@"================================");
    VoicePluginLog(@"GetReVoice CALLED");
    VoicePluginLog(@"self = %@", self);
    VoicePluginLog(@"class = %@", NSStringFromClass([self class]));

    NSArray *stack = [NSThread callStackSymbols];

    for (NSUInteger i = 0;
         i < MIN(stack.count, 12);
         i++) {

        VoicePluginLog(@"STACK[%lu] %@",
                       (unsigned long)i,
                       stack[i]);
    }

    if (OriginalGetReVoice) {
        ((void (*)(id, SEL))
         OriginalGetReVoice)(self, _cmd);
    }

    VoicePluginLog(@"GetReVoice RETURN");
}

#pragma mark - Hook: getNewVoiceServerList:

static void VoicePlugin_GetNewVoiceServerList(
    id self,
    SEL _cmd,
    id arg
) {

    VoicePluginLog(@"================================");
    VoicePluginLog(@"getNewVoiceServerList: CALLED");

    if (arg) {
        VoicePluginLog(@"arg class = %@",
                       NSStringFromClass([arg class]));

        VoicePluginLog(@"arg = %@",
                       arg);
    } else {
        VoicePluginLog(@"arg = nil");
    }

    NSArray *stack = [NSThread callStackSymbols];

    for (NSUInteger i = 0;
         i < MIN(stack.count, 12);
         i++) {

        VoicePluginLog(@"STACK[%lu] %@",
                       (unsigned long)i,
                       stack[i]);
    }

    if (OriginalGetNewVoiceServerList) {
        ((void (*)(id, SEL, id))
         OriginalGetNewVoiceServerList)(
            self,
            _cmd,
            arg
        );
    }

    VoicePluginLog(@"getNewVoiceServerList: RETURN");
}

#pragma mark - 安装 Hook

static BOOL VoicePluginInstallHooks(void) {

    Class cls = NSClassFromString(@"VoiceSelectController");

    if (!cls) {
        VoicePluginLog(@"VoiceSelectController NOT FOUND");
        return NO;
    }

    VoicePluginLog(@"VoiceSelectController FOUND");

    Method reVoiceMethod =
        class_getInstanceMethod(
            cls,
            @selector(GetReVoice)
        );

    if (reVoiceMethod) {

        OriginalGetReVoice =
            method_getImplementation(reVoiceMethod);

        method_setImplementation(
            reVoiceMethod,
            (IMP)VoicePlugin_GetReVoice
        );

        VoicePluginLog(
            @"Hooked GetReVoice, original IMP = %p",
            OriginalGetReVoice
        );
    } else {
        VoicePluginLog(@"GetReVoice NOT FOUND");
    }

    Method serverMethod =
        class_getInstanceMethod(
            cls,
            @selector(getNewVoiceServerList:)
        );

    if (serverMethod) {

        OriginalGetNewVoiceServerList =
            method_getImplementation(serverMethod);

        method_setImplementation(
            serverMethod,
            (IMP)VoicePlugin_GetNewVoiceServerList
        );

        VoicePluginLog(
            @"Hooked getNewVoiceServerList:, original IMP = %p",
            OriginalGetNewVoiceServerList
        );
    } else {
        VoicePluginLog(
            @"getNewVoiceServerList: NOT FOUND"
        );
    }

    return YES;
}

#pragma mark - 启动

__attribute__((constructor))
static void VoicePluginInit(void) {

    @autoreleasepool {

        VoicePluginLog(@"================================");
        VoicePluginLog(@"VoicePlugin START");
        VoicePluginLog(@"PID = %d", getpid());
        VoicePluginLog(@"Process = %@",
                       [[NSProcessInfo processInfo] processName]);

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(5 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                VoicePluginInstallHooks();
            }
        );
    }
}
