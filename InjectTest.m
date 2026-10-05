#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>

#pragma mark - OpenVoice runtime bridge

typedef void (^SHVRProgressBlock)(float progress);
typedef void (^SHVRCompletionBlock)(NSURL *outputURL, NSError *error);

@interface SHVoiceTone : NSObject
@property(nonatomic, copy) NSString *identifier;
@property(nonatomic, copy) NSString *name;
@end

@interface SHVoiceReconstructionManager : NSObject
+ (instancetype)sharedManager;
- (NSArray *)tones;
- (BOOL)modelReady;
- (NSString *)modelStatusText;
- (void)selectToneWithIdentifier:(NSString *)identifier;
- (SHVoiceTone *)selectedTone;
@end

#pragma mark - Main controller

@interface VR05ViewController : UIViewController
@property(nonatomic,strong) AVAudioRecorder *recorder;
@property(nonatomic,strong) AVAudioPlayer *player;
@property(nonatomic,strong) NSURL *recordURL;
@property(nonatomic,strong) NSURL *convertedURL;

@property(nonatomic,strong) NSArray *tones;
@property(nonatomic,strong) NSString *selectedToneID;

@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *recordButton;
@property(nonatomic,strong) UIButton *convertButton;
@property(nonatomic,strong) UIButton *playButton;
@property(nonatomic,strong) UIButton *sendButton;
@property(nonatomic,strong) UIStackView *toneStack;
@end

@implementation VR05ViewController

#pragma mark UI

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    self.title = @"语音插件 V0.5";

    UIScrollView *scroll =
    [[UIScrollView alloc] initWithFrame:self.view.bounds];

    scroll.autoresizingMask =
    UIViewAutoresizingFlexibleWidth |
    UIViewAutoresizingFlexibleHeight;

    [self.view addSubview:scroll];

    UIView *content = [[UIView alloc] init];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor]
    ]];

    UILabel *title = [[UILabel alloc] init];
    title.text = @"微信语音变声";
    title.font = [UIFont boldSystemFontOfSize:24];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:title];

    UILabel *mode = [[UILabel alloc] init];
    mode.text = @"模式：本地 OpenVoice";
    mode.font = [UIFont systemFontOfSize:15];
    mode.textColor = [UIColor darkGrayColor];
    mode.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:mode];

    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.text = @"正在检查 OpenVoice 模型……";
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.font = [UIFont systemFontOfSize:14];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.statusLabel];

    UILabel *toneTitle = [[UILabel alloc] init];
    toneTitle.text = @"选择音色";
    toneTitle.font = [UIFont boldSystemFontOfSize:17];
    toneTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:toneTitle];

    self.toneStack =
    [[UIStackView alloc] initWithFrame:CGRectZero];

    self.toneStack.axis = UILayoutConstraintAxisVertical;
    self.toneStack.spacing = 8;
    self.toneStack.translatesAutoresizingMaskIntoConstraints = NO;

    [content addSubview:self.toneStack];

    self.recordButton =
    [self button:@"🎙 开始录音"];

    self.convertButton =
    [self button:@"✨ OpenVoice 变声"];

    self.playButton =
    [self button:@"▶️ 试听"];

    self.sendButton =
    [self button:@"📤 确认发送"];

    [self.recordButton addTarget:self
                          action:@selector(recordPressed)
                forControlEvents:UIControlEventTouchUpInside];

    [self.convertButton addTarget:self
                           action:@selector(convertPressed)
                 forControlEvents:UIControlEventTouchUpInside];

    [self.playButton addTarget:self
                        action:@selector(playPressed)
              forControlEvents:UIControlEventTouchUpInside];

    [self.sendButton addTarget:self
                        action:@selector(sendPressed)
              forControlEvents:UIControlEventTouchUpInside];

    [content addSubview:self.recordButton];
    [content addSubview:self.convertButton];
    [content addSubview:self.playButton];
    [content addSubview:self.sendButton];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:content.topAnchor constant:24],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],

        [mode.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [mode.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],

        [self.statusLabel.topAnchor constraintEqualToAnchor:mode.bottomAnchor constant:10],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [toneTitle.topAnchor constraintEqualToAnchor:self.statusLabel.bottomAnchor constant:22],
        [toneTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],

        [self.toneStack.topAnchor constraintEqualToAnchor:toneTitle.bottomAnchor constant:10],
        [self.toneStack.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.toneStack.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [self.recordButton.topAnchor constraintEqualToAnchor:self.toneStack.bottomAnchor constant:25],
        [self.recordButton.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.recordButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [self.recordButton.heightAnchor constraintEqualToConstant:50],

        [self.convertButton.topAnchor constraintEqualToAnchor:self.recordButton.bottomAnchor constant:10],
        [self.convertButton.leadingAnchor constraintEqualToAnchor:self.recordButton.leadingAnchor],
        [self.convertButton.trailingAnchor constraintEqualToAnchor:self.recordButton.trailingAnchor],
        [self.convertButton.heightAnchor constraintEqualToConstant:50],

        [self.playButton.topAnchor constraintEqualToAnchor:self.convertButton.bottomAnchor constant:10],
        [self.playButton.leadingAnchor constraintEqualToAnchor:self.recordButton.leadingAnchor],
        [self.playButton.trailingAnchor constraintEqualToAnchor:self.recordButton.trailingAnchor],
        [self.playButton.heightAnchor constraintEqualToConstant:50],

        [self.sendButton.topAnchor constraintEqualToAnchor:self.playButton.bottomAnchor constant:10],
        [self.sendButton.leadingAnchor constraintEqualToAnchor:self.recordButton.leadingAnchor],
        [self.sendButton.trailingAnchor constraintEqualToAnchor:self.recordButton.trailingAnchor],
        [self.sendButton.heightAnchor constraintEqualToConstant:50],
        [self.sendButton.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-30]
    ]];

    self.convertButton.enabled = NO;
    self.playButton.enabled = NO;
    self.sendButton.enabled = NO;

    [self loadOpenVoice];
}

- (UIButton *)button:(NSString *)title {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];

    [b setTitle:title forState:UIControlStateNormal];

    b.titleLabel.font = [UIFont boldSystemFontOfSize:17];

    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 1;
    b.layer.borderColor = [UIColor lightGrayColor].CGColor;

    b.translatesAutoresizingMaskIntoConstraints = NO;

    return b;
}

#pragma mark OpenVoice

- (void)loadOpenVoice {

    Class cls = NSClassFromString(@"SHVoiceReconstructionManager");

    if (!cls) {
        self.statusLabel.text =
        @"❌ 没有找到 SHVoiceReconstructionManager\n"
        @"请确认 hangtiankeji.dylib 已经注入。";
        return;
    }

    SHVoiceReconstructionManager *manager =
    [cls sharedManager];

    BOOL ready = NO;

    if ([manager respondsToSelector:@selector(modelReady)]) {
        ready = manager.modelReady;
    }

    NSString *status = nil;

    if ([manager respondsToSelector:@selector(modelStatusText)]) {
        status = manager.modelStatusText;
    }

    self.tones = nil;

    if ([manager respondsToSelector:@selector(tones)]) {
        self.tones = manager.tones;
    }

    NSMutableString *text =
    [NSMutableString string];

    [text appendFormat:@"OpenVoice：%@\n",
     ready ? @"✅ 已就绪" : @"⏳ 未就绪"];

    if (status.length) {
        [text appendFormat:@"%@\n", status];
    }

    [text appendFormat:@"检测到音色：%lu",
     (unsigned long)self.tones.count];

    self.statusLabel.text = text;

    [self reloadTones];

    if (ready) {
        self.convertButton.enabled = YES;
    }
}

- (void)reloadTones {

    for (UIView *v in self.toneStack.arrangedSubviews) {
        [self.toneStack removeArrangedSubview:v];
        [v removeFromSuperview];
    }

    if (self.tones.count == 0) {

        UILabel *label = [[UILabel alloc] init];

        label.text =
        @"没有检测到预置音色。\n"
        @"如果模型已经加载，这里会显示可用音色。";

        label.numberOfLines = 0;
        label.textColor = [UIColor grayColor];

        [self.toneStack addArrangedSubview:label];

        return;
    }

    for (id tone in self.tones) {

        NSString *name = nil;
        NSString *identifier = nil;

        if ([tone respondsToSelector:@selector(name)]) {
            name = [tone name];
        }

        if ([tone respondsToSelector:@selector(identifier)]) {
            identifier = [tone identifier];
        }

        if (!name.length) {
            name = identifier ?: @"未知音色";
        }

        UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

        [button setTitle:name forState:UIControlStateNormal];

        button.contentHorizontalAlignment =
        UIControlContentHorizontalAlignmentLeft;

        button.titleLabel.font =
        [UIFont systemFontOfSize:16];

        button.layer.cornerRadius = 8;
        button.layer.borderWidth = 1;
        button.layer.borderColor =
        [UIColor lightGrayColor].CGColor;

        button.contentEdgeInsets =
        UIEdgeInsetsMake(10, 14, 10, 14);

        button.accessibilityIdentifier = identifier;

        [button addTarget:self
                   action:@selector(tonePressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.toneStack addArrangedSubview:button];
    }
}

- (void)tonePressed:(UIButton *)button {

    self.selectedToneID =
    button.accessibilityIdentifier;

    Class cls =
    NSClassFromString(@"SHVoiceReconstructionManager");

    SHVoiceReconstructionManager *manager =
    [cls sharedManager];

    if (self.selectedToneID.length &&
        [manager respondsToSelector:@selector(selectToneWithIdentifier:)]) {

        [manager selectToneWithIdentifier:self.selectedToneID];
    }

    for (UIView *view in self.toneStack.arrangedSubviews) {

        if ([view isKindOfClass:[UIButton class]]) {

            UIButton *b = (UIButton *)view;

            if ([b isEqual:button]) {
                b.backgroundColor =
                [UIColor colorWithWhite:0.9 alpha:1.0];
            } else {
                b.backgroundColor =
                [UIColor clearColor];
            }
        }
    }

    self.statusLabel.text =
    [NSString stringWithFormat:@"已选择音色：%@",
     button.currentTitle ?: @"未知"];
}

#pragma mark Recording

- (NSURL *)recordFileURL {

    NSString *path =
    [NSTemporaryDirectory()
     stringByAppendingPathComponent:@"voice_v05_input.wav"];

    return [NSURL fileURLWithPath:path];
}

- (void)recordPressed {

    if (self.recorder.isRecording) {

        [self.recorder stop];

        self.recordButton.enabled = YES;
        [self.recordButton setTitle:@"🎙 重新录音"
                            forState:UIControlStateNormal];

        self.convertButton.enabled = YES;

        self.statusLabel.text =
        @"录音完成，可以开始 OpenVoice 变声。";

        return;
    }

    AVAudioSession *session =
    [AVAudioSession sharedInstance];

    [session requestRecordPermission:^(BOOL granted) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (!granted) {

                self.statusLabel.text =
                @"❌ 没有麦克风权限，请在系统设置中允许微信使用麦克风。";

                return;
            }

            NSError *error = nil;

            [session setCategory:AVAudioSessionCategoryRecord
                             error:&error];

            [session setActive:YES error:&error];

            self.recordURL = [self recordFileURL];

            NSDictionary *settings = @{
                AVFormatIDKey : @(kAudioFormatLinearPCM),
                AVSampleRateKey : @16000,
                AVNumberOfChannelsKey : @1,
                AVLinearPCMBitDepthKey : @16,
                AVLinearPCMIsFloatKey : @NO,
                AVLinearPCMIsBigEndianKey : @NO
            };

            self.recorder =
            [[AVAudioRecorder alloc]
             initWithURL:self.recordURL
             settings:settings
             error:&error];

            if (error || !self.recorder) {

                self.statusLabel.text =
                [NSString stringWithFormat:
                 @"❌ 创建录音失败：%@",
                 error.localizedDescription];

                return;
            }

            [self.recorder prepareToRecord];
            [self.recorder record];

            self.convertButton.enabled = NO;
            self.playButton.enabled = NO;
            self.sendButton.enabled = NO;

            [self.recordButton setTitle:@"⏹ 停止录音"
                                forState:UIControlStateNormal];

            self.statusLabel.text =
            @"🔴 正在录音……";
        });
    }];
}

#pragma mark Conversion

- (void)convertPressed {

    if (!self.recordURL ||
        ![[NSFileManager defaultManager]
         fileExistsAtPath:self.recordURL.path]) {

        self.statusLabel.text =
        @"❌ 请先录音。";

        return;
    }

    Class cls =
    NSClassFromString(@"SHVoiceReconstructionManager");

    if (!cls) {
        self.statusLabel.text =
        @"❌ 找不到 OpenVoice 管理器。";
        return;
    }

    SHVoiceReconstructionManager *manager =
    [cls sharedManager];

    if (![manager respondsToSelector:
          NSSelectorFromString(
          @"convertSourceAudioURL:progress:completion:")]) {

        self.statusLabel.text =
        @"❌ 当前 hangtiankeji 版本没有找到转换接口。";

        return;
    }

    self.convertButton.enabled = NO;
    self.playButton.enabled = NO;
    self.sendButton.enabled = NO;

    self.statusLabel.text =
    @"⏳ OpenVoice 正在转换……";

    NSURL *inputURL = self.recordURL;

    SHVRProgressBlock progress =
    ^(float progress) {

        dispatch_async(dispatch_get_main_queue(), ^{

            self.statusLabel.text =
            [NSString stringWithFormat:
             @"⏳ OpenVoice 转换中：%.0f%%",
             progress * 100.0];

        });
    };

    SHVRCompletionBlock completion =
    ^(NSURL *outputURL, NSError *error) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (error) {

                self.statusLabel.text =
                [NSString stringWithFormat:
                 @"❌ OpenVoice 转换失败：%@",
                 error.localizedDescription];

                self.convertButton.enabled = YES;

                return;
            }

            if (!outputURL ||
                ![[NSFileManager defaultManager]
                 fileExistsAtPath:outputURL.path]) {

                self.statusLabel.text =
                @"❌ OpenVoice 没有返回有效音频文件。";

                self.convertButton.enabled = YES;

                return;
            }

            self.convertedURL = outputURL;

            self.statusLabel.text =
            @"✅ 变声完成，可以试听。";

            self.playButton.enabled = YES;
            self.sendButton.enabled = YES;
            self.convertButton.enabled = YES;
        });
    };

    /*
     * 使用 NSInvocation 调用，避免因为 dylib 内部没有公开头文件
     * 而产生链接依赖。
     */
    SEL selector =
    NSSelectorFromString(
    @"convertSourceAudioURL:progress:completion:");

    NSMethodSignature *signature =
    [manager methodSignatureForSelector:selector];

    if (!signature) {

        self.statusLabel.text =
        @"❌ 无法获取转换方法签名。";

        self.convertButton.enabled = YES;

        return;
    }

    NSInvocation *invocation =
    [NSInvocation invocationWithMethodSignature:signature];

    invocation.target = manager;
    invocation.selector = selector;

    NSURL *urlArg = inputURL;
    id progressArg = progress;
    id completionArg = completion;

    [invocation setArgument:&urlArg atIndex:2];
    [invocation setArgument:&progressArg atIndex:3];
    [invocation setArgument:&completionArg atIndex:4];

    @try {

        [invocation invoke];

    } @catch (NSException *exception) {

        self.statusLabel.text =
        [NSString stringWithFormat:
         @"❌ 调用 OpenVoice 失败：%@",
         exception.reason];

        self.convertButton.enabled = YES;
    }
}

#pragma mark Playback

- (void)playPressed {

    if (!self.convertedURL) {
        self.statusLabel.text =
        @"❌ 没有可试听的音频。";
        return;
    }

    NSError *error = nil;

    self.player =
    [[AVAudioPlayer alloc]
     initWithContentsOfURL:self.convertedURL
     error:&error];

    if (error || !self.player) {

        self.statusLabel.text =
        [NSString stringWithFormat:
         @"❌ 播放失败：%@",
         error.localizedDescription];

        return;
    }

    [self.player prepareToPlay];
    [self.player play];

    self.statusLabel.text =
    @"▶️ 正在试听变声结果……";
}

#pragma mark Send

- (void)sendPressed {

    /*
     * V0.5 第一阶段先验证：
     *
     * 录音 → OpenVoice → 输出文件 → 试听
     *
     * 微信 SILK / 当前聊天对象发送桥接下一阶段接入。
     */

    if (!self.convertedURL) {

        self.statusLabel.text =
        @"❌ 请先完成变声。";

        return;
    }

    self.statusLabel.text =
    @"✅ 变声文件已经准备好。\n"
    @"V0.5 当前阶段发送桥接尚未启用。";

    UIAlertController *alert =
    [UIAlertController
     alertControllerWithTitle:@"V0.5"
     message:@"OpenVoice 变声已经完成。下一阶段接入微信语音发送。"
     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
     [UIAlertAction actionWithTitle:@"知道了"
                              style:UIAlertActionStyleDefault
                            handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

@end

#pragma mark - Floating button

static void VR05ShowButton(void);

@interface VR05Launcher : NSObject
@end

@implementation VR05Launcher

+ (void)load {

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{

        VR05ShowButton();

        [[NSNotificationCenter defaultCenter]
         addObserverForName:UIApplicationDidBecomeActiveNotification
         object:nil
         queue:[NSOperationQueue mainQueue]
         usingBlock:^(NSNotification *note) {

            VR05ShowButton();

        }];
    });
}

@end

static void VR05ShowButton(void) {

    UIWindow *window = nil;

    if (@available(iOS 13.0, *)) {

        for (UIScene *scene in
             [UIApplication sharedApplication].connectedScenes) {

            if (scene.activationState ==
                UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {

                for (UIWindow *w in
                     ((UIWindowScene *)scene).windows) {

                    if (w.isKeyWindow) {
                        window = w;
                        break;
                    }
                }
            }

            if (window) break;
        }
    }

    if (!window) {
        window =
        [UIApplication sharedApplication].keyWindow;
    }

    if (!window) return;

    if ([window viewWithTag:2050]) return;

    UIButton *button =
    [UIButton buttonWithType:UIButtonTypeSystem];

    button.tag = 2050;

    [button setTitle:@"语音插件"
            forState:UIControlStateNormal];

    button.backgroundColor =
    [UIColor colorWithWhite:0.95 alpha:0.95];

    button.layer.cornerRadius = 22;

    button.frame =
    CGRectMake(window.bounds.size.width - 110,
               120,
               95,
               44);

    button.autoresizingMask =
    UIViewAutoresizingFlexibleLeftMargin;

    [button addTarget:NSClassFromString(@"VR05Launcher")
               action:@selector(open:)
     forControlEvents:UIControlEventTouchUpInside];

    [window addSubview:button];

    /*
     * 直接绑定 block 不适用于 UIButton target/action，
     * 所以使用辅助对象。
     */
    objc_setAssociatedObject(
        button,
        "vr05_open_block",
        [^{
            UIViewController *vc =
            [[VR05ViewController alloc] init];

            vc.modalPresentationStyle =
            UIModalPresentationPageSheet;

            UIViewController *root =
            window.rootViewController;

            while (root.presentedViewController) {
                root = root.presentedViewController;
            }

            [root presentViewController:vc
                               animated:YES
                             completion:nil];

        } copy],
        OBJC_ASSOCIATION_COPY);
}

@implementation VR05Launcher (Open)

+ (void)open:(UIButton *)sender {

    void (^block)(void) =
    objc_getAssociatedObject(sender, "vr05_open_block");

    if (block) block();
}

@end
