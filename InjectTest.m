#import <Foundation/Foundation.h>
#import <objc/runtime.h>

static void WriteLog(NSString *text) {
    @autoreleasepool {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        );

        NSString *documents = [paths firstObject];
        if (!documents) return;

        NSString *file = [documents stringByAppendingPathComponent:
                          @"VoiceBridgeProbe_runtime.log"];

        [text writeToFile:file
              atomically:YES
                encoding:NSUTF8StringEncoding
                   error:nil];
    }
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {
    @autoreleasepool {

        NSString *marker =
        [NSString stringWithFormat:
         @"VoiceBridgeProbe constructor executed\n"
          "Process=%@\n"
          "PID=%d\n"
          "Time=%@\n\n",
         [[NSProcessInfo processInfo] processName],
         getpid(),
         [NSDate date]];

        WriteLog(marker);

        int count = objc_getClassList(NULL, 0);

        if (count <= 0) {
            WriteLog([marker stringByAppendingString:
                      @"objc_getClassList returned 0\n"]);
            return;
        }

        Class *classes = (__unsafe_unretained Class *)
            malloc(sizeof(Class) * count);

        if (!classes) {
            WriteLog([marker stringByAppendingString:
                      @"malloc failed\n"]);
            return;
        }

        int actualCount = objc_getClassList(classes, count);

        NSMutableString *result =
            [NSMutableString stringWithString:marker];

        [result appendFormat:
         @"Objective-C class count = %d\n\n",
         actualCount];

        NSArray *keywords = @[
            @"voice",
            @"tts",
            @"speech",
            @"audio",
            @"synth",
            @"synthesis",
            @"speak"
        ];

        int matched = 0;

        for (int i = 0; i < actualCount; i++) {

            Class cls = classes[i];

            if (!cls) continue;

            const char *name = class_getName(cls);

            if (!name) continue;

            NSString *className =
                [NSString stringWithUTF8String:name];

            NSString *lower =
                [className lowercaseString];

            BOOL hit = NO;

            for (NSString *keyword in keywords) {
                if ([lower containsString:keyword]) {
                    hit = YES;
                    break;
                }
            }

            if (hit) {
                [result appendFormat:
                 @"CLASS: %@\n",
                 className];

                matched++;

                if (matched >= 500) {
                    [result appendString:
                     @"\n[Output limited to 500 matches]\n"];
                    break;
                }
            }
        }

        [result appendFormat:
         @"\nMatched classes = %d\n",
         matched];

        free(classes);

        WriteLog(result);
    }
}
