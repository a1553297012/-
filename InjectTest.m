#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static NSString *DocumentsPath(void) {
    NSArray *paths =
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        );

    return paths.firstObject;
}

static void WriteLog(NSString *text) {
    NSString *dir = DocumentsPath();

    if (!dir) {
        return;
    }

    NSString *path =
        [dir stringByAppendingPathComponent:
            @"VoiceBridgeProbe_runtime.log"];

    NSFileHandle *handle =
        [NSFileHandle fileHandleForWritingAtPath:path];

    NSData *data =
        [[text stringByAppendingString:@"\n"]
            dataUsingEncoding:NSUTF8StringEncoding];

    if (!handle) {
        [data writeToFile:path atomically:YES];
        return;
    }

    @try {
        [handle seekToEndOfFile];
        [handle writeData:data];
        [handle closeFile];
    } @catch (__unused NSException *e) {
        [handle closeFile];
    }
}

static BOOL ContainsKeyword(const char *name) {
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
        @"speak",
        @"synth",
        @"synthesis",
        @"audio",
        @"voiceprint",
        @"voicemsg",
        @"voicemessage"
    ];

    for (NSString *keyword in keywords) {
        if ([lower containsString:keyword]) {
            return YES;
        }
    }

    return NO;
}

static void ScanRuntime(void) {

    WriteLog(@"========================================");
    WriteLog(@"VoiceBridgeProbe runtime scan started");
    WriteLog(@"========================================");

    int classCount =
        objc_getClassList(NULL, 0);

    WriteLog(
        [NSString stringWithFormat:
            @"Class count reported: %d",
            classCount]
    );

    if (classCount <= 0) {
        WriteLog(@"No Objective-C classes reported.");
        return;
    }

    Class *classes =
        (__unsafe_unretained Class *)
        malloc(sizeof(Class) * classCount);

    if (!classes) {
        WriteLog(@"Unable to allocate class list.");
        return;
    }

    classCount =
        objc_getClassList(classes, classCount);

    int matchedClasses = 0;
    int matchedMethods = 0;

    for (int i = 0; i < classCount; i++) {

        Class cls = classes[i];

        const char *className =
            class_getName(cls);

        if (!ContainsKeyword(className)) {
            continue;
        }

        matchedClasses++;

        WriteLog(
            [NSString stringWithFormat:
                @"\nCLASS: %s",
                className]
        );

        unsigned int methodCount = 0;

        Method *methods =
            class_copyMethodList(
                cls,
                &methodCount
            );

        for (unsigned int j = 0;
             j < methodCount;
             j++) {

            Method method = methods[j];

            SEL selector =
                method_getName(method);

            if (!selector) {
                continue;
            }

            const char *selectorName =
                sel_getName(selector);

            if (!ContainsKeyword(selectorName)) {
                continue;
            }

            matchedMethods++;

            const char *types =
                method_getTypeEncoding(method);

            WriteLog(
                [NSString stringWithFormat:
                    @"  -[%s %s] types=%s",
                    className,
                    selectorName,
                    types ? types : "?"]
            );
        }

        free(methods);
    }

    free(classes);

    WriteLog(
        [NSString stringWithFormat:
            @"\nMatched classes: %d",
            matchedClasses]
    );

    WriteLog(
        [NSString stringWithFormat:
            @"Matched methods: %d",
            matchedMethods]
    );

    WriteLog(@"========================================");
    WriteLog(@"VoiceBridgeProbe runtime scan finished");
    WriteLog(@"========================================");
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {

    @autoreleasepool {

        /*
         * 保留之前已经验证成功的加载标记。
         */
        NSString *documents =
            DocumentsPath();

        if (documents) {

            NSString *marker =
                [documents
                    stringByAppendingPathComponent:
                        @"VoiceBridgeProbe_loaded.txt"];

            NSString *content =
                [NSString stringWithFormat:
                    @"VoiceBridgeProbe constructor executed\n"
                     "Process=%@\n"
                     "PID=%d\n"
                     "Time=%@\n",
                    [[NSProcessInfo processInfo]
                        processName],
                    [[NSProcessInfo processInfo]
                        processIdentifier],
                    [NSDate date]];

            [content writeToFile:marker
                      atomically:YES
                        encoding:NSUTF8StringEncoding
                           error:nil];
        }

        /*
         * 等微信主线程启动后再扫描。
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
