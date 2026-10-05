#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

#pragma mark - HB Voice Hook

static BOOL HBVoiceHookInstalled = NO;

#pragma mark - 打印 UIAlertController 内容

static void HBLogAlertController(id obj, NSString *prefix) {

    if (!obj) {
        NSLog(@"[VoiceRebuild] %@ = nil", prefix);
        return;
    }

    NSLog(@"[VoiceRebuild] %@ class = %@",
          prefix,
          NSStringFromClass([obj class]));

    NSLog(@"[VoiceRebuild] %@ description = %@",
          prefix,
          obj);

    if ([obj isKindOfClass:[UIAlertController class]]) {

        UIAlertController *alert =
            (UIAlertController *)obj;

        NSLog(@"[VoiceRebuild] %@ title = %@",
              prefix,
              alert.title);

        NSLog(@"[VoiceRebuild] %@ message = %@",
              prefix,
              alert.message);

        NSLog(@"[VoiceRebuild] %@ actions count = %lu",
              prefix,
              (unsigned long)alert.actions.count);

        for (UIAlertAction *action in alert.actions) {

            NSLog(@"[VoiceRebuild] %@ action = %@",
                  prefix,
                  action.title);
        }
    }
}

#pragma mark - Hook VoiceSelectController

static void HookVoiceController(void) {

    if (HBVoiceHookInstalled) {

        NSLog(
            @"[VoiceRebuild] Hook already installed"
        );

        return;
    }

    Class cls =
        NSClassFromString(@"VoiceSelectController");

    if (!cls) {

        NSLog(
            @"[VoiceRebuild] ❌ VoiceSelectController not found"
        );

        return;
    }

    NSLog(
        @"[VoiceRebuild] ✅ VoiceSelectController found: %@",
        cls
    );

    SEL sel =
        NSSelectorFromString(
            @"getNewVoiceServerList:"
        );

    Method method =
        class_getInstanceMethod(cls, sel);

    if (!method) {

        NSLog(
            @"[VoiceRebuild] ❌ getNewVoiceServerList: not found"
        );

        return;
    }

    NSLog(
        @"[VoiceRebuild] ✅ getNewVoiceServerList: found"
    );

    IMP oldIMP =
        method_getImplementation(method);

    typedef void (*VoiceFunc)(
        id,
        SEL,
        id
    );

    VoiceFunc original =
        (VoiceFunc)oldIMP;

    IMP newIMP =
        imp_implementationWithBlock(
            ^void(id self, id arg) {

                NSLog(
                    @"[VoiceRebuild] "
                    @"========================================"
                );

                NSLog(
                    @"[VoiceRebuild] "
                    @"getNewVoiceServerList: CALLED"
                );

                NSLog(
                    @"[VoiceRebuild] self = %@",
                    self
                );

                NSLog(
                    @"[VoiceRebuild] self class = %@",
                    NSStringFromClass([self class])
                );

                HBLogAlertController(
                    arg,
                    @"BEFORE"
                );

                /*
                 * 执行 HB 原来的方法
                 */
                original(
                    self,
                    sel,
                    arg
                );

                /*
                 * 原方法执行完成以后
                 * 再次读取参数。
                 *
                 * 如果 HB 是通过传入的 UIAlertController
                 * 修改提示内容，这里就可以看到结果。
                 */
                HBLogAlertController(
                    arg,
                    @"AFTER"
                );

                NSLog(
                    @"[VoiceRebuild] "
                    @"========================================"
                );
            }
        );

    method_setImplementation(
        method,
        newIMP
    );

    HBVoiceHookInstalled = YES;

    NSLog(
        @"[VoiceRebuild] "
        @"✅ Hook installed successfully!"
    );
}

#pragma mark - 等待 HB 初始化

static void StartVoiceHookSearch(void) {

    NSLog(
        @"[VoiceRebuild] "
        @"开始寻找 VoiceSelectController..."
    );

    /*
     * HB 可能不是马上完成初始化。
     *
     * 每 2 秒检查一次。
     * 最多检查 30 次。
     */

    __block int count = 0;

    dispatch_queue_t queue =
        dispatch_get_main_queue();

    void (^checkBlock)(void) =
        ^{
            count++;

            NSLog(
                @"[VoiceRebuild] "
                @"检查 VoiceSelectController (%d/30)",
                count
            );

            Class cls =
                NSClassFromString(
                    @"VoiceSelectController"
                );

            if (cls) {

                HookVoiceController();

                return;
            }

            if (count >= 30) {

                NSLog(
                    @"[VoiceRebuild] "
                    @"❌ 等待超时，仍未找到 VoiceSelectController"
                );

                return;
            }

            dispatch_after(
                dispatch_time(
                    DISPATCH_TIME_NOW,
                    2 * NSEC_PER_SEC
                ),
                queue,
                checkBlock
            );
        };

    checkBlock();
}

#pragma mark - 插件加载

__attribute__((constructor))
static void VoiceRebuildInjectTest_Loaded(void) {

    @autoreleasepool {

        NSLog(
            @"[VoiceRebuild] "
            @"========================================"
        );

        NSLog(
            @"[VoiceRebuild] "
            @"VoiceRebuild loaded successfully"
        );

        NSLog(
            @"[VoiceRebuild] "
            @"不再创建任何调试窗口"
        );

        NSLog(
            @"[VoiceRebuild] "
            @"不再显示 UIAlertController"
        );

        NSLog(
            @"[VoiceRebuild] "
            @"========================================"
        );

        /*
         * 等待微信 / HB 初始化
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                3 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                StartVoiceHookSearch();
            }
        );
    }
}
