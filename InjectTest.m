#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import <mach-o/dyld.h>

@interface VR053VC : UIViewController
@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,assign) NSInteger count;
@end

@implementation VR053VC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"V0.5.3 模型诊断";

    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.font = [UIFont systemFontOfSize:14];
    [self.view addSubview:self.textView];

    [NSLayoutConstraint activateConstraints:@[
        [self.textView.topAnchor constraintEqualToAnchor:
         self.view.safeAreaLayoutGuide.topAnchor constant:10],

        [self.textView.bottomAnchor constraintEqualToAnchor:
         self.view.bottomAnchor constant:-10],

        [self.textView.leadingAnchor constraintEqualToAnchor:
         self.view.leadingAnchor constant:10],

        [self.textView.trailingAnchor constraintEqualToAnchor:
         self.view.trailingAnchor constant:-10]
    ]];

    [self refresh];

    self.timer =
        [NSTimer scheduledTimerWithTimeInterval:1.0
                                         target:self
                                       selector:@selector(refresh)
                                       userInfo:nil
                                        repeats:YES];
}

- (void)dealloc {
    [self.timer invalidate];
}

- (void)refresh {

    self.count++;

    NSMutableString *out =
        [NSMutableString string];

    [out appendString:@"V0.5.3 OpenVoice 模型诊断\n\n"];

    Class cls =
        NSClassFromString(@"SHVoiceReconstructionManager");

    if (!cls) {

        [out appendString:
         @"❌ SHVoiceReconstructionManager 不存在\n"];

        self.textView.text = out;
        return;
    }

    [out appendString:
     @"✅ SHVoiceReconstructionManager\n"];

    SEL sharedSEL =
        NSSelectorFromString(@"sharedManager");

    id manager = nil;

    if ([cls respondsToSelector:sharedSEL]) {

        manager =
            ((id (*)(id, SEL))objc_msgSend)(
                cls,
                sharedSEL
            );
    }

    if (!manager) {

        [out appendString:
         @"❌ sharedManager 返回为空\n"];

        self.textView.text = out;
        return;
    }

    [out appendString:@"✅ sharedManager\n\n"];

    BOOL ready = NO;

    SEL readySEL =
        NSSelectorFromString(@"modelReady");

    if ([manager respondsToSelector:readySEL]) {

        ready =
            ((BOOL (*)(id, SEL))objc_msgSend)(
                manager,
                readySEL
            );
    }

    [out appendFormat:
     @"modelReady：%@\n",
     ready ? @"✅ YES" : @"⚠️ NO"];

    NSString *status = nil;

    SEL statusSEL =
        NSSelectorFromString(@"modelStatusText");

    if ([manager respondsToSelector:statusSEL]) {

        status =
            ((id (*)(id, SEL))objc_msgSend)(
                manager,
                statusSEL
            );
    }

    [out appendFormat:
     @"modelStatusText：%@\n\n",
     status.length ? status : @"(空)"];

    NSArray *tones = nil;

    SEL tonesSEL =
        NSSelectorFromString(@"tones");

    if ([manager respondsToSelector:tonesSEL]) {

        tones =
            ((id (*)(id, SEL))objc_msgSend)(
                manager,
                tonesSEL
            );
    }

    [out appendFormat:
     @"音色数量：%lu\n\n",
     (unsigned long)tones.count];

    /*
     * 查找当前进程加载的 dylib。
     */
    [out appendString:@"━━ dylib 路径 ━━\n"];

    uint32_t imageCount =
        _dyld_image_count();

    for (uint32_t i = 0;
         i < imageCount;
         i++) {

        const char *name =
            _dyld_get_image_name(i);

        if (!name)
            continue;

        NSString *path =
            [NSString stringWithUTF8String:name];

        NSString *lower =
            path.lowercaseString;

        if ([lower containsString:@"hangt"] ||
            [lower containsString:@"senhang"] ||
            [lower containsString:@"openvoice"] ||
            [lower containsString:@"voicerebuild"]) {

            [out appendFormat:@"%@\n", path];
        }
    }

    /*
     * 检查常见模型资源名称。
     */
    [out appendString:@"\n━━ 模型资源扫描 ━━\n"];

    NSArray *keywords = @[
        @"OpenVoice",
        @"openvoice",
        @"SenHang",
        @"senhang",
        @"SpeakerEncoder",
        @"VoiceConverter",
        @".mlmodelc"
    ];

    NSFileManager *fm =
        [NSFileManager defaultManager];

    NSMutableSet *found =
        [NSMutableSet set];

    NSArray *roots = @[
        [NSBundle mainBundle].bundlePath,
        [NSBundle mainBundle].resourcePath,
        NSTemporaryDirectory()
    ];

    for (NSString *root in roots) {

        NSDirectoryEnumerator *enumerator =
            [fm enumeratorAtPath:root];

        NSString *relative = nil;

        while ((relative = [enumerator nextObject])) {

            NSString *full =
                [root stringByAppendingPathComponent:relative];

            NSString *lower =
                full.lowercaseString;

            BOOL match = NO;

            for (NSString *key in keywords) {

                if ([lower containsString:
                     key.lowercaseString]) {

                    match = YES;
                    break;
                }
            }

            if (match) {

                if (![found containsObject:full]) {

                    [found addObject:full];

                    [out appendFormat:
                     @"%@\n",
                     full];
                }
            }

            /*
             * 防止扫描异常庞大的目录。
             */
            if (found.count >= 80)
                break;
        }

        if (found.count >= 80)
            break;
    }

    if (found.count == 0) {
        [out appendString:@"❌ 没找到明显的 OpenVoice 模型资源\n"];
    }

    [out appendString:@"\n━━ 检测次数 ━━\n"];
    [out appendFormat:@"%ld 秒\n",
     (long)self.count];

    if (ready) {

        [out appendString:
         @"\n🎉 模型已经 Ready，可以进入下一阶段。"];

        [self.timer invalidate];
        self.timer = nil;
    } else if (self.count >= 15) {

        [out appendString:
         @"\n⚠️ 等待 15 秒后仍未 Ready。"];

        [self.timer invalidate];
        self.timer = nil;
    } else {

        [out appendString:
         @"\n⏳ 正在等待模型初始化……"];
    }

    self.textView.text = out;
}

@end


@interface VR053Launcher : NSObject
@end

@implementation VR053Launcher

+ (void)load {

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{

        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {

            for (UIScene *scene in
                 [UIApplication sharedApplication].connectedScenes) {

                if (scene.activationState !=
                    UISceneActivationStateForegroundActive)
                    continue;

                if (![scene isKindOfClass:
                     [UIWindowScene class]])
                    continue;

                for (UIWindow *w in
                     ((UIWindowScene *)scene).windows) {

                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }

                if (window)
                    break;
            }
        }

        if (!window)
            window =
                [UIApplication sharedApplication].keyWindow;

        if (!window)
            return;

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
            CGRectMake(window.bounds.size.width - 125,
                       120,
                       110,
                       45);

        button.autoresizingMask =
            UIViewAutoresizingFlexibleLeftMargin;

        button.layer.cornerRadius = 22;
        button.layer.borderWidth = 1;

        [button setTitle:@"V0.5.3"
                forState:UIControlStateNormal];

        [button addTarget:self
                   action:@selector(open:)
         forControlEvents:UIControlEventTouchUpInside];

        [window addSubview:button];
    });
}

+ (void)open:(UIButton *)sender {

    UIViewController *root =
        sender.window.rootViewController;

    while (root.presentedViewController)
        root = root.presentedViewController;

    VR053VC *vc =
        [[VR053VC alloc] init];

    UINavigationController *nav =
        [[UINavigationController alloc]
         initWithRootViewController:vc];

    [root presentViewController:nav
                       animated:YES
                     completion:nil];
}

@end
