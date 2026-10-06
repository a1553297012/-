#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *ProbeLogPath(void) {
    NSString *tmp = NSTemporaryDirectory();
    return [tmp stringByAppendingPathComponent:@"VoiceBridgeProbe.log"];
}

static void WriteLog(NSString *text) {
    NSString *line = [NSString stringWithFormat:@"%@\n", text];

    NSLog(@"[VoiceBridgeProbe] %@", text);

    NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
    NSFileHandle *handle =
        [NSFileHandle fileHandleForWritingAtPath:ProbeLogPath()];

    if (handle) {
        @try {
            [handle seekToEndOfFile];
            [handle writeData:data];
            [handle closeFile];
        } @catch (__unused NSException *e) {
        }
    } else {
        [data writeToFile:ProbeLogPath() atomically:YES];
    }
}

static BOOL NameLooksRelevant(const char *name) {
    if (!name) return NO;

    NSString *s =
        [[NSString alloc] initWithUTF8String:name];

    if (!s) return NO;

    NSArray *keywords = @[
        @"voice",
        @"tts",
        @"speech",
        @"audio",
        @"speak",
        @"synthesis",
        @"synthesize",
        @"voicemessage",
        @"voicerecord",
        @"voicemsg",
        @"message",
        @"send",
        @"play",
        @"player"
    ];

    NSString *lower = [s lowercaseString];

    for (NSString *keyword in keywords) {
        if ([lower containsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

static void DumpMethods(Class cls) {
    if (!cls) return;

    const char *className = class_getName(cls);
    if (!className) return;

    if (!NameLooksRelevant(className)) {
        return;
    }

    WriteLog(
        [NSString stringWithFormat:
            @"\n========== CLASS: %s ==========",
            className]
    );

    unsigned int count = 0;
    Method *methods = class_copyMethodList(cls, &count);

    for (unsigned int i = 0; i < count; i++) {
        Method method = methods[i];

        SEL selector = method_getName(method);
        if (!selector) continue;

        const char *selName = sel_getName(selector);
        if (!selName) continue;

        NSString *methodString =
            [[NSString alloc] initWithUTF8String:selName];

        if (!methodString) continue;

        NSString *lower =
            [methodString lowercaseString];

        BOOL relevant = NO;

        NSArray *keywords = @[
            @"voice",
            @"tts",
            @"speech",
            @"audio",
            @"speak",
            @"synth",
            @"send",
            @"message",
            @"play",
            @"record"
        ];

        for (NSString *keyword in keywords) {
            if ([lower containsString:keyword]) {
                relevant = YES;
                break;
            }
        }

        if (relevant) {
            const char *types = method_getTypeEncoding(method);

            WriteLog(
                [NSString stringWithFormat:
                    @"  -[%s %s] types=%s",
                    className,
                    selName,
                    types ? types : "?"]
            );
        }
    }

    free(methods);
}

static void DumpRelevantClasses(void) {
    WriteLog(@"========================================");
    WriteLog(@"VoiceBridgeProbe START");
    WriteLog(@"========================================");

    int classCount = objc_getClassList(NULL, 0);

    if (classCount <= 0) {
        WriteLog(@"objc_getClassList returned no classes");
        return;
    }

    Class *classes =
        (__unsafe_unretained Class *)
        malloc(sizeof(Class) * classCount);

    if (!classes) {
        WriteLog(@"Unable to allocate class list");
        return;
    }

    classCount = objc_getClassList(classes, classCount);

    WriteLog(
        [NSString stringWithFormat:
            @"Loaded Objective-C classes: %d",
            classCount]
    );

    for (int i = 0; i < classCount; i++) {
        DumpMethods(classes[i]);
    }

    free(classes);

    WriteLog(@"========================================");
    WriteLog(@"VoiceBridgeProbe END");
    WriteLog(@"========================================");
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {
    @autoreleasepool {
        WriteLog(@"VoiceBridgeProbe dylib loaded");

        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                @autoreleasepool {
                    DumpRelevantClasses();
                }
            }
        );
    }
}
