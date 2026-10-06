#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static NSString *ProbeDirectory(void) {
    return @"/tmp/VoiceBridgeProbe";
}

static NSString *ProbeFile(NSString *name) {
    return [[ProbeDirectory() stringByAppendingString:@"/"] stringByAppendingString:name];
}

static void EnsureDirectory(void) {
    [[NSFileManager defaultManager]
        createDirectoryAtPath:ProbeDirectory()
        withIntermediateDirectories:YES
        attributes:nil
        error:nil];
}

static void WriteFile(NSString *name, NSString *text) {
    EnsureDirectory();

    NSString *path = ProbeFile(name);

    [text writeToFile:path
          atomically:YES
            encoding:NSUTF8StringEncoding
               error:nil];
}

static void AppendFile(NSString *name, NSString *text) {
    EnsureDirectory();

    NSString *path = ProbeFile(name);

    NSData *newData =
        [text dataUsingEncoding:NSUTF8StringEncoding];

    NSFileHandle *handle =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (!handle) {
        [newData writeToFile:path atomically:YES];
        return;
    }

    @try {
        [handle seekToEndOfFile];
        [handle writeData:newData];
        [handle closeFile];
    } @catch (__unused NSException *exception) {
        [handle closeFile];
    }
}

static BOOL IsInterestingName(const char *name) {
    if (!name) {
        return NO;
    }

    NSString *s =
        [[NSString alloc] initWithUTF8String:name];

    if (!s) {
        return NO;
    }

    NSString *lower =
        [s lowercaseString];

    NSArray *keywords = @[
        @"voice",
        @"tts",
        @"speech",
        @"audio",
        @"speak",
        @"synth",
        @"synthesis",
        @"message",
        @"send",
        @"record",
        @"player"
    ];

    for (NSString *keyword in keywords) {
        if ([lower containsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

static void ScanRuntime(void) {
    AppendFile(
        @"runtime.log",
        @"\n========== VoiceBridgeProbe Runtime Scan ==========\n"
    );

    int count = objc_getClassList(NULL, 0);

    if (count <= 0) {
        AppendFile(
            @"runtime.log",
            @"objc_getClassList returned 0\n"
        );
        return;
    }

    Class *classes =
        (__unsafe_unretained Class *)
        malloc(sizeof(Class) * count);

    if (!classes) {
        AppendFile(
            @"runtime.log",
            @"class allocation failed\n"
        );
        return;
    }

    count = objc_getClassList(classes, count);

    AppendFile(
        @"runtime.log",
        [NSString stringWithFormat:
            @"Loaded Objective-C classes: %d\n",
            count]
    );

    int interestingClasses = 0;
    int interestingMethods = 0;

    for (int i = 0; i < count; i++) {

        Class cls = classes[i];

        const char *className =
            class_getName(cls);

        if (!IsInterestingName(className)) {
            continue;
        }

        interestingClasses++;

        AppendFile(
            @"runtime.log",
            [NSString stringWithFormat:
                @"\nCLASS: %s\n",
                className]
        );

        unsigned int methodCount = 0;

        Method *methods =
            class_copyMethodList(cls, &methodCount);

        for (unsigned int j = 0;
             j < methodCount;
             j++) {

            SEL selector =
                method_getName(methods[j]);

            if (!selector) {
                continue;
            }

            const char *selectorName =
                sel_getName(selector);

            if (!IsInterestingName(selectorName)) {
                continue;
            }

            interestingMethods++;

            const char *types =
                method_getTypeEncoding(methods[j]);

            AppendFile(
                @"runtime.log",
                [NSString stringWithFormat:
                    @"  -[%s %s] types=%s\n",
                    className,
                    selectorName,
                    types ? types : "?"]
            );
        }

        free(methods);
    }

    free(classes);

    AppendFile(
        @"runtime.log",
        [NSString stringWithFormat:
            @"\nInteresting classes: %d\n"
             "Interesting methods: %d\n"
             "========== Scan Finished ==========\n",
            interestingClasses,
            interestingMethods]
    );

    WriteFile(
        @"scan.finished",
        @"VoiceBridgeProbe runtime scan finished\n"
    );
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {

    @autoreleasepool {

        /*
         * 最先执行的动作：
         * 如果这个文件存在，就证明 dylib 的
         * constructor 已经真正执行。
         */
        WriteFile(
            @"loaded",
            @"VoiceBridgeProbe constructor executed\n"
        );

        WriteFile(
            @"info",
            [NSString stringWithFormat:
                @"Process: %@\n"
                 "PID: %d\n"
                 "Timestamp: %@\n",
                [[NSProcessInfo processInfo] processName],
                [[NSProcessInfo processInfo] processIdentifier],
                [NSDate date]]
        );

        AppendFile(
            @"runtime.log",
            @"VoiceBridgeProbe constructor executed\n"
        );

        /*
         * 等主线程起来之后再扫描 Runtime。
         */
        dispatch_async(
            dispatch_get_main_queue(),
            ^{
                @autoreleasepool {
                    ScanRuntime();
                }
            }
        );
    }
}
