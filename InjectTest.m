#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

static void WriteMarker(void) {
    NSFileManager *fm = [NSFileManager defaultManager];

    NSArray *directories = @[
        NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory,
            NSUserDomainMask,
            YES
        ).firstObject ?: @"",
        
        NSSearchPathForDirectoriesInDomains(
            NSCachesDirectory,
            NSUserDomainMask,
            YES
        ).firstObject ?: @""
    ];

    NSString *content = [NSString stringWithFormat:
        @"VoiceBridgeProbe constructor executed\n"
         "Process=%@\n"
         "PID=%d\n"
         "Time=%@\n",
        [[NSProcessInfo processInfo] processName],
        [[NSProcessInfo processInfo] processIdentifier],
        [NSDate date]
    ];

    for (NSString *directory in directories) {
        if (directory.length == 0) {
            continue;
        }

        [fm createDirectoryAtPath:directory
       withIntermediateDirectories:YES
                        attributes:nil
                             error:nil];

        NSString *path =
            [directory stringByAppendingPathComponent:
                @"VoiceBridgeProbe_loaded.txt"];

        [content writeToFile:path
                  atomically:YES
                    encoding:NSUTF8StringEncoding
                       error:nil];
    }
}

__attribute__((constructor))
static void VoiceBridgeProbeLoaded(void) {
    @autoreleasepool {
        WriteMarker();
    }
}
