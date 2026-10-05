#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/message.h>
#import <objc/runtime.h>

@interface VR052VC : UIViewController
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) UIButton *record;
@property(nonatomic,strong) UIButton *convert;
@property(nonatomic,strong) UIButton *play;
@property(nonatomic,strong) AVAudioRecorder *recorder;
@property(nonatomic,strong) AVAudioPlayer *player;
@property(nonatomic,strong) NSURL *recordURL;
@property(nonatomic,strong) NSURL *convertedURL;
@property(nonatomic,strong) NSString *toneID;
@property(nonatomic,strong) NSArray *tones;
@end

@implementation VR052VC

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = UIColor.whiteColor;
    self.title = @"微信语音变声 V0.5.2";

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

    self.status = [[UILabel alloc] init];
    self.status.text = @"正在读取 OpenVoice……";
    self.status.numberOfLines = 0;
    self.status.font = [UIFont systemFontOfSize:14];
    self.status.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:self.status];

    UILabel *toneTitle = [[UILabel alloc] init];
    toneTitle.text = @"选择音色";
    toneTitle.font = [UIFont boldSystemFontOfSize:18];
    toneTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:toneTitle];

    UIStackView *tones =
        [[UIStackView alloc] init];

    tones.axis = UILayoutConstraintAxisVertical;
    tones.spacing = 8;
    tones.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:tones];

    Class cls =
        NSClassFromString(@"SHVoiceReconstructionManager");

    id manager = nil;

    if (cls &&
        [cls respondsToSelector:
         NSSelectorFromString(@"sharedManager")]) {

        manager =
            ((id (*)(id, SEL))objc_msgSend)(
                cls,
                NSSelectorFromString(@"sharedManager"));
    }

    if (!manager) {
        self.status.text =
            @"❌ 找不到 OpenVoice 管理器";
    } else {

        BOOL ready = NO;

        if ([manager respondsToSelector:
             NSSelectorFromString(@"modelReady")]) {

            ready =
                ((BOOL (*)(id, SEL))objc_msgSend)(
                    manager,
                    NSSelectorFromString(@"modelReady"));
        }

        if ([manager respondsToSelector:
             NSSelectorFromString(@"tones")]) {

            self.tones =
                ((id (*)(id, SEL))objc_msgSend)(
                    manager,
                    NSSelectorFromString(@"tones"));
        }

        self.status.text =
            [NSString stringWithFormat:
             @"OpenVoice：%@\n检测到 %lu 个音色",
             ready ? @"✅ 已就绪" : @"⚠️ 未就绪",
             (unsigned long)self.tones.count];

        for (id tone in self.tones) {

            NSString *name = nil;
            NSString *identifier = nil;

            if ([tone respondsToSelector:
                 NSSelectorFromString(@"name")]) {

                name =
                    ((id (*)(id, SEL))objc_msgSend)(
                        tone,
                        NSSelectorFromString(@"name"));
            }

            if ([tone respondsToSelector:
                 NSSelectorFromString(@"identifier")]) {

                identifier =
                    ((id (*)(id, SEL))objc_msgSend)(
                        tone,
                        NSSelectorFromString(@"identifier"));
            }

            UIButton *b =
                [UIButton buttonWithType:UIButtonTypeSystem];

            [b setTitle:(name ?: identifier ?: @"未知音色")
               forState:UIControlStateNormal];

            b.contentHorizontalAlignment =
                UIControlContentHorizontalAlignmentLeft;

            b.contentEdgeInsets =
                UIEdgeInsetsMake(10, 14, 10, 14);

            b.layer.borderWidth = 1;
            b.layer.cornerRadius = 8;
            b.layer.borderColor =
                UIColor.lightGrayColor.CGColor;

            b.accessibilityIdentifier = identifier;

            [b addTarget:self
                  action:@selector(tone:)
        forControlEvents:UIControlEventTouchUpInside];

            [tones addArrangedSubview:b];
        }
    }

    self.record = [self makeButton:@"🎙 录音"];
    self.convert = [self makeButton:@"✨ OpenVoice 变声"];
    self.play = [self makeButton:@"▶️ 试听"];

    self.convert.enabled = NO;
    self.play.enabled = NO;

    [self.record addTarget:self
                    action:@selector(recordPressed)
          forControlEvents:UIControlEventTouchUpInside];

    [self.convert addTarget:self
                     action:@selector(convertPressed)
           forControlEvents:UIControlEventTouchUpInside];

    [self.play addTarget:self
                  action:@selector(playPressed)
        forControlEvents:UIControlEventTouchUpInside];

    [content addSubview:self.record];
    [content addSubview:self.convert];
    [content addSubview:self.play];

    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:content.topAnchor constant:20],
        [title.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:20],

        [self.status.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:10],
        [self.status.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.status.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [toneTitle.topAnchor constraintEqualToAnchor:self.status.bottomAnchor constant:20],
        [toneTitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],

        [tones.topAnchor constraintEqualToAnchor:toneTitle.bottomAnchor constant:8],
        [tones.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [tones.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],

        [self.record.topAnchor constraintEqualToAnchor:tones.bottomAnchor constant:20],
        [self.record.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.record.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-20],
        [self.record.heightAnchor constraintEqualToConstant:50],

        [self.convert.topAnchor constraintEqualToAnchor:self.record.bottomAnchor constant:10],
        [self.convert.leadingAnchor constraintEqualToAnchor:self.record.leadingAnchor],
        [self.convert.trailingAnchor constraintEqualToAnchor:self.record.trailingAnchor],
        [self.convert.heightAnchor constraintEqualToConstant:50],

        [self.play.topAnchor constraintEqualToAnchor:self.convert.bottomAnchor constant:10],
        [self.play.leadingAnchor constraintEqualToAnchor:self.record.leadingAnchor],
        [self.play.trailingAnchor constraintEqualToAnchor:self.record.trailingAnchor],
        [self.play.heightAnchor constraintEqualToConstant:50],

        [self.play.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-30]
    ]];
}

- (UIButton *)makeButton:(NSString *)title {
    UIButton *b =
        [UIButton buttonWithType:UIButtonTypeSystem];

    [b setTitle:title forState:UIControlStateNormal];

    b.titleLabel.font =
        [UIFont boldSystemFontOfSize:17];

    b.layer.cornerRadius = 10;
    b.layer.borderWidth = 1;
    b.layer.borderColor =
        UIColor.lightGrayColor.CGColor;

    b.translatesAutoresizingMaskIntoConstraints = NO;

    return b;
}

- (void)tone:(UIButton *)button {

    self.toneID = button.accessibilityIdentifier;

    Class cls =
        NSClassFromString(@"SHVoiceReconstructionManager");

    id manager =
        ((id (*)(id, SEL))objc_msgSend)(
            cls,
            NSSelectorFromString(@"sharedManager"));

    if (self.toneID.length &&
        [manager respondsToSelector:
         NSSelectorFromString(@"selectToneWithIdentifier:")]) {

        ((void (*)(id, SEL, id))objc_msgSend)(
            manager,
            NSSelectorFromString(@"selectToneWithIdentifier:"),
            self.toneID);
    }

    self.status.text =
        [NSString stringWithFormat:
         @"已选择：%@",
         button.currentTitle];

    self.convert.enabled =
        self.recordURL != nil;
}

- (NSURL *)recordURLPath {

    NSString *p =
        [NSTemporaryDirectory()
         stringByAppendingPathComponent:@"vr052_input.wav"];

    return [NSURL fileURLWithPath:p];
}

- (void)recordPressed {

    if (self.recorder.isRecording) {

        [self.recorder stop];

        [self.record setTitle:@"🎙 重新录音"
                      forState:UIControlStateNormal];

        self.convert.enabled = YES;

        self.status.text =
            @"✅ 录音完成，可以开始变声";

        return;
    }

    AVAudioSession *session =
        [AVAudioSession sharedInstance];

    [session requestRecordPermission:^(BOOL granted) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (!granted) {

                self.status.text =
                    @"❌ 没有麦克风权限";

                return;
            }

            NSError *error = nil;

            [session setCategory:
                AVAudioSessionCategoryRecord
                       error:&error];

            [session setActive:YES error:&error];

            self.recordURL =
                [self recordURLPath];

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

            if (error) {

                self.status.text =
                    [NSString stringWithFormat:
                     @"❌ 录音失败：%@",
                     error.localizedDescription];

                return;
            }

            [self.recorder prepareToRecord];
            [self.recorder record];

            self.convert.enabled = NO;
            self.play.enabled = NO;

            [self.record setTitle:@"⏹ 停止录音"
                          forState:UIControlStateNormal];

            self.status.text =
                @"🔴 正在录音……";
        });
    }];
}

- (void)convertPressed {

    if (!self.recordURL) {
        self.status.text = @"❌ 请先录音";
        return;
    }

    Class cls =
        NSClassFromString(@"SHVoiceReconstructionManager");

    id manager =
        ((id (*)(id, SEL))objc_msgSend)(
            cls,
            NSSelectorFromString(@"sharedManager"));

    SEL selector =
        NSSelectorFromString(
            @"convertSourceAudioURL:progress:completion:");

    if (![manager respondsToSelector:selector]) {

        self.status.text =
            @"❌ 没有找到转换接口";

        return;
    }

    self.convert.enabled = NO;
    self.play.enabled = NO;

    self.status.text =
        @"⏳ OpenVoice 正在转换……";

    /*
     * progress 先传 nil。
     * completion 使用两个对象参数接收：
     * output / error
     */

    id completion =
        ^(id output, NSError *error) {

            dispatch_async(
                dispatch_get_main_queue(), ^{

                if (error) {

                    self.status.text =
                        [NSString stringWithFormat:
                         @"❌ 转换失败：%@",
                         error.localizedDescription];

                    self.convert.enabled = YES;
                    return;
                }

                NSURL *url = nil;

                if ([output isKindOfClass:[NSURL class]]) {
                    url = output;
                } else if ([output isKindOfClass:[NSString class]]) {
                    url = [NSURL fileURLWithPath:output];
                }

                if (!url ||
                    ![[NSFileManager defaultManager]
                     fileExistsAtPath:url.path]) {

                    self.status.text =
                        [NSString stringWithFormat:
                         @"⚠️ 转换返回：%@",
                         output];

                    self.convert.enabled = YES;
                    return;
                }

                self.convertedURL = url;

                self.status.text =
                    @"✅ OpenVoice 转换完成，可以试听";

                self.play.enabled = YES;
                self.convert.enabled = YES;
            });
        };

    NSMethodSignature *sig =
        [manager methodSignatureForSelector:selector];

    if (!sig) {

        self.status.text =
            @"❌ 无法取得方法签名";

        self.convert.enabled = YES;

        return;
    }

    NSInvocation *inv =
        [NSInvocation invocationWithMethodSignature:sig];

    inv.target = manager;
    inv.selector = selector;

    NSURL *input = self.recordURL;
    id progress = nil;
    id completionArg = completion;

    [inv setArgument:&input atIndex:2];
    [inv setArgument:&progress atIndex:3];
    [inv setArgument:&completionArg atIndex:4];

    @try {

        [inv invoke];

    } @catch (NSException *e) {

        self.status.text =
            [NSString stringWithFormat:
             @"❌ 调用失败：%@",
             e.reason];

        self.convert.enabled = YES;
    }
}

- (void)playPressed {

    if (!self.convertedURL) {
        self.status.text = @"❌ 没有转换结果";
        return;
    }

    NSError *error = nil;

    self.player =
        [[AVAudioPlayer alloc]
         initWithContentsOfURL:self.convertedURL
         error:&error];

    if (error) {

        self.status.text =
            [NSString stringWithFormat:
             @"❌ 播放失败：%@",
             error.localizedDescription];

        return;
    }

    [self.player prepareToPlay];
    [self.player play];

    self.status.text =
        @"▶️ 正在试听";
}

@end

@interface VR052Launcher : NSObject
@end

@implementation VR052Launcher

+ (void)load {

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      3 * NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{

        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {

            for (UIScene *scene in
                 UIApplication.sharedApplication.connectedScenes) {

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

                if (window) break;
            }
        }

        if (!window)
            window =
                UIApplication.sharedApplication.keyWindow;

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

        [button setTitle:@"语音 V0.5.2"
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

    VR052VC *vc =
        [[VR052VC alloc] init];

    UINavigationController *nav =
        [[UINavigationController alloc]
         initWithRootViewController:vc];

    [root presentViewController:nav
                       animated:YES
                     completion:nil];
}

@end
