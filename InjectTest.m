#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>

@interface VR051Controller : UIViewController
@property(nonatomic,strong) UITextView *textView;
@end

@implementation VR051Controller

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"V0.5.1 接口检测";

    self.textView = [[UITextView alloc] initWithFrame:CGRectZero];
    self.textView.translatesAutoresizingMaskIntoConstraints = NO;
    self.textView.editable = NO;
    self.textView.font = [UIFont systemFontOfSize:13];
    [self.view addSubview:self.textView];

    [NSLayoutConstraint activateConstraints:@[
        [self.textView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:10],
        [self.textView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-10],
        [self.textView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:10],
        [self.textView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-10]
    ]];

    [self inspect];
}

- (void)inspect {

    NSMutableString *out = [NSMutableString string];

    [out appendString:@"V0.5.1 OpenVoice 接口检测\n\n"];

    Class managerClass =
        NSClassFromString(@"SHVoiceReconstructionManager");

    if (!managerClass) {
        [out appendString:@"❌ 找不到 SHVoiceReconstructionManager\n"];
        self.textView.text = out;
        return;
    }

    [out appendString:@"✅ SHVoiceReconstructionManager\n\n"];

    id manager =
        ((id (*)(id, SEL))objc_msgSend)(
            managerClass,
            sel_registerName("sharedManager")
        );

    if (!manager) {
        [out appendString:@"❌ sharedManager 返回为空\n"];
        self.textView.text = out;
        return;
    }

    [out appendString:@"✅ sharedManager\n\n"];

    NSArray *selectors = @[
        @"convertSourceAudioURL:progress:completion:",
        @"convertPCM16WAVData:toneIdentifier:progress:completion:",
        @"convertChatSourceAudioURL:operationIdentifier:progress:completion:",
        @"convertAuthorizedSourceAudioURL:progress:completion:",
        @"speakerEmbeddingForAudioURL:error:",
        @"speakerEmbeddingForSampleData:error:",
        @"writeWeChatPCM16kFromAudioURL:toURL:error:",
        @"tones",
        @"modelReady",
        @"modelStatusText",
        @"selectedTone"
    ];

    for (NSString *name in selectors) {

        SEL sel = NSSelectorFromString(name);

        [out appendFormat:@"━━━━━━━━━━━━━━━━━━\n"];
        [out appendFormat:@"%@\n", name];

        if (![manager respondsToSelector:sel]) {
            [out appendString:@"❌ 不存在\n"];
            continue;
        }

        [out appendString:@"✅ 存在\n"];

        NSMethodSignature *sig =
            [manager methodSignatureForSelector:sel];

        if (!sig) {
            [out appendString:@"⚠️ 无法取得签名\n"];
            continue;
        }

        [out appendFormat:@"返回类型：%s\n",
         sig.methodReturnType];

        [out appendFormat:@"参数数量：%lu\n",
         (unsigned long)(sig.numberOfArguments - 2)];

        for (NSUInteger i = 2;
             i < sig.numberOfArguments;
             i++) {

            [out appendFormat:@"参数 %lu：%s\n",
             (unsigned long)(i - 2),
             [sig getArgumentTypeAtIndex:i]];
        }
    }

    [out appendString:@"\n━━━━━━━━━━━━━━━━━━\n"];
    [out appendString:@"音色列表\n"];

    SEL tonesSel = NSSelectorFromString(@"tones");

    if ([manager respondsToSelector:tonesSel]) {

        NSArray *tones =
            ((id (*)(id, SEL))objc_msgSend)(
                manager,
                tonesSel
            );

        [out appendFormat:@"数量：%lu\n\n",
         (unsigned long)tones.count];

        for (id tone in tones) {

            NSString *identifier = nil;
            NSString *name = nil;

            if ([tone respondsToSelector:
                 NSSelectorFromString(@"identifier")]) {

                identifier =
                    ((id (*)(id, SEL))objc_msgSend)(
                        tone,
                        NSSelectorFromString(@"identifier")
                    );
            }

            if ([tone respondsToSelector:
                 NSSelectorFromString(@"name")]) {

                name =
                    ((id (*)(id, SEL))objc_msgSend)(
                        tone,
                        NSSelectorFromString(@"name")
                    );
            }

            [out appendFormat:@"%@ | %@\n",
             identifier ?: @"(无ID)",
             name ?: @"(无名称)"];
        }
    }

    [out appendString:@"\n检测完成。"];

    self.textView.text = out;
}

@end

static void VR051Open(void);

@interface VR051Launcher : NSObject
@end

@implementation VR051Launcher

+ (void)load {

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            VR051Open();
        }
    );
}

@end

static void VR051Open(void) {

    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (scene.activationState !=
                UISceneActivationStateForegroundActive) {
                continue;
            }

            if (![scene isKindOfClass:[UIWindowScene class]]) {
                continue;
            }

            for (UIWindow *w in
                 ((UIWindowScene *)scene).windows) {

                if (w.isKeyWindow) {
                    window = w;
                    break;
                }
            }

            if (window) break;
        }
    }

    if (!window) {
        window = [UIApplication sharedApplication].keyWindow;
    }

    if (!window) return;

    UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

    button.frame =
        CGRectMake(window.bounds.size.width - 120,
                   120,
                   105,
                   45);

    button.autoresizingMask =
        UIViewAutoresizingFlexibleLeftMargin;

    button.backgroundColor =
        [UIColor colorWithWhite:0.95 alpha:0.95];

    button.layer.cornerRadius = 22;

    [button setTitle:@"接口检测"
            forState:UIControlStateNormal];

    [button addTarget:[VR051Launcher class]
               action:@selector(open:)
     forControlEvents:UIControlEventTouchUpInside];

    [window addSubview:button];
}

@implementation VR051Launcher (Open)

+ (void)open:(UIButton *)sender {

    UIWindow *window = sender.window;

    UIViewController *root =
        window.rootViewController;

    while (root.presentedViewController) {
        root = root.presentedViewController;
    }

    VR051Controller *vc =
        [[VR051Controller alloc] init];

    UINavigationController *nav =
        [[UINavigationController alloc]
         initWithRootViewController:vc];

    [root presentViewController:nav
                       animated:YES
                     completion:nil];
}

@end
