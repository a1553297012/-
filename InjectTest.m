#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

#pragma mark - 顶层调试窗口

static UIWindow *HBDebugWindow = nil;

static void HBShow(NSString *text) {

    dispatch_async(dispatch_get_main_queue(), ^{

        if (!HBDebugWindow) {

            HBDebugWindow =
                [[UIWindow alloc] initWithFrame:
                 [UIScreen mainScreen].bounds];

            // 放到系统弹窗之上
            HBDebugWindow.windowLevel = UIWindowLevelAlert + 100;
            HBDebugWindow.backgroundColor = [UIColor clearColor];

            UIViewController *vc = [UIViewController new];
            vc.view.backgroundColor = [UIColor clearColor];

            HBDebugWindow.rootViewController = vc;
            HBDebugWindow.hidden = NO;
        }

        UIViewController *vc = HBDebugWindow.rootViewController;

        UILabel *label = [vc.view viewWithTag:9527];

        if (!label) {

            label =
                [[UILabel alloc] initWithFrame:
                 CGRectMake(15,
                            80,
                            [UIScreen mainScreen].bounds.size.width - 30,
                            320)];

            label.tag = 9527;

            label.numberOfLines = 0;
            label.font = [UIFont systemFontOfSize:14];
            label.textColor = [UIColor whiteColor];

            label.backgroundColor =
                [[UIColor blackColor] colorWithAlphaComponent:0.90];

            label.layer.cornerRadius = 12;
            label.layer.masksToBounds = YES;

            label.textAlignment = NSTextAlignmentLeft;

            [vc.view addSubview:label];
        }

        label.text = text;
    });
}

#pragma mark - Hook HB VoiceSelectController

static void HookVoiceController(void) {

    Class cls =
        NSClassFromString(@"VoiceSelectController");

    if (!cls) {

        NSLog(@"[VoiceRebuild] VoiceSelectController not found");

        HBShow(@"HB语音拦截\n\n❌ 找不到 VoiceSelectController");

        return;
    }

    SEL sel =
        NSSelectorFromString(@"getNewVoiceServerList:");

    Method method =
        class_getInstanceMethod(cls, sel);

    if (!method) {

        NSLog(@"[VoiceRebuild] getNewVoiceServerList: not found");

        HBShow(@"HB语音拦截\n\n❌ 找不到 getNewVoiceServerList:");

        return;
    }

    IMP oldIMP =
        method_getImplementation(method);

    typedef void (*VoiceFunc)(id, SEL, id);

    VoiceFunc original =
        (VoiceFunc)oldIMP;

    IMP newIMP =
        imp_implementationWithBlock(
            ^void(id self, id arg) {

                NSLog(@"[VoiceRebuild] ===================");
                NSLog(@"[VoiceRebuild] HB VOICE SERVER");
                NSLog(@"[VoiceRebuild] argument = %@", arg);
                NSLog(@"[VoiceRebuild] ===================");

                NSString *info =
                    [NSString stringWithFormat:
                     @"HB语音拦截\n\n"
                     @"方法：\n"
                     @"getNewVoiceServerList:\n\n"
                     @"参数：\n"
                     @"%@",
                     arg];

                /*
                 * 等 HB 自己的“获取成功，音色已更新”
                 * 弹窗消失以后，再显示我们的内容。
                 */
                dispatch_after(
                    dispatch_time(
                        DISPATCH_TIME_NOW,
                        2 * NSEC_PER_SEC
                    ),
                    dispatch_get_main_queue(),
                    ^{
                        HBShow(info);
                    }
                );

                // 继续执行 HB 原来的方法
                original(self, sel, arg);
            }
        );

    method_setImplementation(method, newIMP);

    NSLog(@"[VoiceRebuild] Hook installed!");

    HBShow(
        @"HB语音拦截\n\n"
         "✅ Hook 成功\n\n"
         "等待你点击“获取音色”..."
    );
}

#pragma mark - 插件加载

__attribute__((constructor))
static void VoiceRebuildInjectTest_Loaded(void) {

    @autoreleasepool {

        NSLog(@"[VoiceRebuild] loaded successfully");

        /*
         * 等微信和 HB 助手初始化完成以后再 Hook。
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                5 * NSEC_PER_SEC
            ),
            dispatch_get_main_queue(),
            ^{
                HookVoiceController();
            }
        );
    }
}
