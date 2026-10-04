#import <Foundation/Foundation.h>

__attribute__((constructor))
static void VoiceRebuildInjectTest_Loaded(void) {
    @autoreleasepool {
        NSLog(@"[VoiceRebuildInjectTest] loaded successfully");
    }
}
