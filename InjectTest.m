#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *HBLogPath(void) {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory,
        NSUserDomainMask,
        YES
    );
    NSString *documents = paths.firstObject;
    return [documents stringByAppendingPathComponent:@"HBCallTrace.log"];
}

static void HBLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);

    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *line = [NSString stringWithFormat:
                      @"[%@] %@\n",
                      [NSDate date],
                      msg];

    NSFileHandle *fh =
        [NSFileHandle fileHandleForWritingAtPath:HBLogPath()];

    if (!fh) {
        [[NSFileManager defaultManager]
            createFileAtPath:HBLogPath()
            contents:nil
            attributes:nil];

        fh = [NSFileHandle fileHandleForWritingAtPath:HBLogPath()];
    }

    [fh seekToEndOfFile];
    [fh writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [fh closeFile];

    NSLog(@"%@", msg);
}

#pragma mark - GetNewVoiceServerList

static void HB_getNewVoiceServerList(id self, SEL _cmd, id arg) {
    HBLog(@"========================================");
    HBLog(@"CALL getNewVoiceServerList:");
    HBLog(@"self = %@", self);
    HBLog(@"arg class = %@", [arg class]);
    HBLog(@"arg = %@", arg);

    // 不改变原逻辑：
    // 这里暂时不调用原 IMP，只用于确认是否会触发。
    HBLog(@"getNewVoiceServerList: 被调用");
}

#pragma mark - GetVoiceServerList

static id HB_GetVoiceServerList(id self, SEL _cmd) {
    HBLog(@"========================================");
    HBLog(@"CALL GetVoiceServerList");
    HBLog(@"self = %@", self);

    HBLog(@"GetVoiceServerList 被调用");

    return nil;
}

#pragma mark - GetReVoice

static void HB_GetReVoice(id self, SEL _cmd) {
    HBLog(@"========================================");
    HBLog(@"CALL GetReVoice");
    HBLog(@"self = %@", self);

    HBLog(@"GetReVoice 被调用");
}

#pragma mark - getVoiceSelectKey:

static void HB_getVoiceSelectKey(id self, SEL _cmd, id arg) {
    HBLog(@"========================================");
    HBLog(@"CALL getVoiceSelectKey:");
    HBLog(@"arg class = %@", [arg class]);
    HBLog(@"arg = %@", arg);

    HBLog(@"getVoiceSelectKey: 被调用");
}

#pragma mark - parseVoiceData:forType:completion:

static void HB_parseVoiceData(
    id self,
    SEL _cmd,
    id data,
    id type,
    id completion
) {
    HBLog(@"========================================");
    HBLog(@"CALL parseVoiceData:forType:completion:");
    HBLog(@"data class = %@", [data class]);
    HBLog(@"data = %@", data);
    HBLog(@"type class = %@", [type class]);
    HBLog(@"type = %@", type);
    HBLog(@"completion class = %@", [completion class]);

    if ([data isKindOfClass:[NSData class]]) {
        NSData *d = data;

        HBLog(@"NSData length = %lu",
              (unsigned long)d.length);

        NSString *text =
            [[NSString alloc] initWithData:d
                                  encoding:NSUTF8StringEncoding];

        if (text) {
            HBLog(@"NSData UTF8 = %@", text);
        }
    }

    HBLog(@"parseVoiceData: 被调用");
}

#pragma mark - Scan

static void HBInstallTrace(void) {

    Class cls = NSClassFromString(@"VoiceSelectController");

    if (!cls) {
        HBLog(@"VoiceSelectController NOT FOUND");
        return;
    }

    HBLog(@"VoiceSelectController FOUND");

    /*
     * 注意：
     * 当前版本只是替换 IMP 来观察调用。
     * 这意味着这些方法如果被调用，原方法逻辑不会执行。
     *
     * 这是故意的诊断步骤。
     */

    Method m;

    m = class_getInstanceMethod(
        cls,
        @selector(getNewVoiceServerList:)
    );

    if (m) {
        method_setImplementation(
            m,
            (IMP)HB_getNewVoiceServerList
        );

        HBLog(@"HOOKED getNewVoiceServerList:");
    }

    m = class_getInstanceMethod(
        cls,
        @selector(GetVoiceServerList)
    );

    if (m) {
        method_setImplementation(
            m,
            (IMP)HB_GetVoiceServerList
        );

        HBLog(@"HOOKED GetVoiceServerList");
    }

    m = class_getInstanceMethod(
        cls,
        @selector(GetReVoice)
    );

    if (m) {
        method_setImplementation(
            m,
            (IMP)HB_GetReVoice
        );

        HBLog(@"HOOKED GetReVoice");
    }

    m = class_getInstanceMethod(
        cls,
        @selector(getVoiceSelectKey:)
    );

    if (m) {
        method_setImplementation(
            m,
            (IMP)HB_getVoiceSelectKey
        );

        HBLog(@"HOOKED getVoiceSelectKey:");
    }

    m = class_getInstanceMethod(
        cls,
        @selector(parseVoiceData:forType:completion:)
    );

    if (m) {
        method_setImplementation(
            m,
            (IMP)HB_parseVoiceData
        );

        HBLog(@"HOOKED parseVoiceData:forType:completion:");
    }

    HBLog(@"========================================");
    HBLog(@"TRACE INSTALL FINISHED");
}

__attribute__((constructor))
static void HBInit(void) {

    HBLog(@"========================================");
    HBLog(@"HB CALL TRACE LOADED");
    HBLog(@"PROCESS = %@", [[NSProcessInfo processInfo] processName]);

    /*
     * 延迟一点，确保微信相关类已经加载。
     */
    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(5.0 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{
            HBLog(@"START INSTALL TRACE");
            HBInstallTrace();
        }
    );
}
