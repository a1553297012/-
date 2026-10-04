#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

#pragma mark - VoiceRebuild V0.4

@interface VoiceRebuildPanel : UIViewController
@property(nonatomic,strong) AVAudioRecorder *recorder;
@property(nonatomic,strong) AVAudioPlayer *player;
@property(nonatomic,strong) NSURL *audioURL;

@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UISegmentedControl *modeControl;
@property(nonatomic,strong) NSArray<UIButton *> *toneButtons;

@property(nonatomic,assign) NSInteger selectedTone;
@end

@implementation VoiceRebuildPanel

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];
    self.title = @"VoiceRebuild V0.4";

    self.selectedTone = 0;

    UILabel *title =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 25, 335, 40)];

    title.text = @"微信语音插件";
    title.font = [UIFont boldSystemFontOfSize:24];
    title.textAlignment = NSTextAlignmentCenter;

    [self.view addSubview:title];

    UILabel *modeTitle =
    [[UILabel alloc] initWithFrame:CGRectMake(25, 80, 330, 25)];

    modeTitle.text = @"转换方式";
    modeTitle.font = [UIFont boldSystemFontOfSize:17];

    [self.view addSubview:modeTitle];

    self.modeControl =
    [[UISegmentedControl alloc]
     initWithItems:@[@"本地 AI", @"硅基流动"]];

    self.modeControl.frame =
    CGRectMake(25, 110, 330, 42);

    self.modeControl.selectedSegmentIndex = 0;

    [self.view addSubview:self.modeControl];

    UILabel *toneTitle =
    [[UILabel alloc] initWithFrame:CGRectMake(25, 170, 330, 25)];

    toneTitle.text = @"目标音色";
    toneTitle.font = [UIFont boldSystemFontOfSize:17];

    [self.view addSubview:toneTitle];

    NSArray *tones = @[
        @"音色 1",
        @"音色 2",
        @"音色 3",
        @"音色 4"
    ];

    NSMutableArray *buttons = [NSMutableArray array];

    for (NSInteger i = 0; i < tones.count; i++) {

        UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
        CGRectMake(25 + (i % 2) * 170,
                   205 + (i / 2) * 50,
                   155,
                   40);

        button.tag = i;

        button.layer.cornerRadius = 8;
        button.layer.borderWidth = 1;
        button.layer.borderColor =
        [UIColor lightGrayColor].CGColor;

        [button setTitle:tones[i]
                forState:UIControlStateNormal];

        [button setTitleColor:UIColor.blackColor
                     forState:UIControlStateNormal];

        [button addTarget:self
                   action:@selector(tonePressed:)
         forControlEvents:UIControlEventTouchUpInside];

        [self.view addSubview:button];

        [buttons addObject:button];
    }

    self.toneButtons = buttons;

    [self updateToneButtons];

    self.statusLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(25, 315, 330, 45)];

    self.statusLabel.text = @"准备录音";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;
    self.statusLabel.numberOfLines = 2;

    [self.view addSubview:self.statusLabel];

    UIButton *recordButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    recordButton.frame =
    CGRectMake(25, 375, 330, 50);

    recordButton.backgroundColor =
    UIColor.systemBlueColor;

    [recordButton setTitle:@"开始录音"
                  forState:UIControlStateNormal];

    [recordButton setTitleColor:UIColor.whiteColor
                       forState:UIControlStateNormal];

    recordButton.layer.cornerRadius = 10;

    [recordButton addTarget:self
                     action:@selector(recordPressed:)
           forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:recordButton];

    UIButton *convertButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    convertButton.frame =
    CGRectMake(25, 440, 330, 50);

    convertButton.backgroundColor =
    UIColor.systemPurpleColor;

    [convertButton setTitle:@"AI 转换"
                   forState:UIControlStateNormal];

    [convertButton setTitleColor:UIColor.whiteColor
                         forState:UIControlStateNormal];

    convertButton.layer.cornerRadius = 10;

    [convertButton addTarget:self
                      action:@selector(convertPressed:)
            forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:convertButton];

    UIButton *playButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    playButton.frame =
    CGRectMake(25, 505, 330, 50);

    playButton.backgroundColor =
    UIColor.systemGrayColor;

    [playButton setTitle:@"试听"
                forState:UIControlStateNormal];

    [playButton setTitleColor:UIColor.whiteColor
                     forState:UIControlStateNormal];

    playButton.layer.cornerRadius = 10;

    [playButton addTarget:self
                   action:@selector(playPressed:)
         forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:playButton];

    UILabel *hint =
    [[UILabel alloc] initWithFrame:CGRectMake(25, 565, 330, 55)];

    hint.text =
    @"V0.4：本地 AI / 硅基流动双模式\n"
    @"下一步接入真实转换引擎";

    hint.font = [UIFont systemFontOfSize:13];
    hint.textColor = UIColor.grayColor;
    hint.textAlignment = NSTextAlignmentCenter;
    hint.numberOfLines = 2;

    [self.view addSubview:hint];
}

#pragma mark - 音色

- (void)tonePressed:(UIButton *)sender {

    self.selectedTone = sender.tag;

    [self updateToneButtons];

    self.statusLabel.text =
    [NSString stringWithFormat:@"已选择：音色 %ld",
     (long)(sender.tag + 1)];
}

- (void)updateToneButtons {

    for (UIButton *button in self.toneButtons) {

        if (button.tag == self.selectedTone) {

            button.backgroundColor =
            UIColor.systemBlueColor;

            [button setTitleColor:UIColor.whiteColor
                         forState:UIControlStateNormal];

        } else {

            button.backgroundColor =
            UIColor.whiteColor;

            [button setTitleColor:UIColor.blackColor
                         forState:UIControlStateNormal];
        }
    }
}

#pragma mark - 录音

- (void)recordPressed:(UIButton *)sender {

    if (self.recorder.recording) {

        [self.recorder stop];

        self.statusLabel.text =
        @"录音完成\n可以点击「AI 转换」";

        [sender setTitle:@"重新录音"
                forState:UIControlStateNormal];

        return;
    }

    AVAudioSession *session =
    [AVAudioSession sharedInstance];

    [session setCategory:
        AVAudioSessionCategoryPlayAndRecord
             withOptions:
        AVAudioSessionCategoryOptionDefaultToSpeaker
                   error:nil];

    [session setActive:YES error:nil];

    [session requestRecordPermission:^(BOOL granted) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (!granted) {

                self.statusLabel.text =
                @"没有麦克风权限";

                return;
            }

            NSString *path =
            [NSTemporaryDirectory()
             stringByAppendingPathComponent:
             @"voice_v04.m4a"];

            self.audioURL =
            [NSURL fileURLWithPath:path];

            NSDictionary *settings = @{
                AVFormatIDKey:
                    @(kAudioFormatMPEG4AAC),

                AVSampleRateKey:
                    @44100,

                AVNumberOfChannelsKey:
                    @1,

                AVEncoderAudioQualityKey:
                    @(AVAudioQualityHigh)
            };

            NSError *error = nil;

            self.recorder =
            [[AVAudioRecorder alloc]
             initWithURL:self.audioURL
             settings:settings
             error:&error];

            if (error || !self.recorder) {

                self.statusLabel.text =
                @"录音初始化失败";

                return;
            }

            [self.recorder prepareToRecord];
            [self.recorder record];

            self.statusLabel.text =
            @"正在录音……";

            [sender setTitle:@"停止录音"
                    forState:UIControlStateNormal];
        });
    }];
}

#pragma mark - AI 转换

- (void)convertPressed:(UIButton *)sender {

    if (!self.audioURL) {

        self.statusLabel.text =
        @"请先录音";

        return;
    }

    NSInteger mode =
    self.modeControl.selectedSegmentIndex;

    NSString *modeName =
    mode == 0 ? @"本地 AI" : @"硅基流动";

    NSString *toneName =
    [NSString stringWithFormat:@"音色 %ld",
     (long)(self.selectedTone + 1)];

    self.statusLabel.text =
    [NSString stringWithFormat:
     @"准备转换\n%@ → %@",
     modeName,
     toneName];

    /*
     V0.4 暂不伪造转换结果。

     下一阶段：

     本地 AI：
     录音 → OpenVoice SpeakerEncoder
           → VoiceConverter
           → 输出音频

     硅基流动：
     录音 → ASR
           → TTS
           → 目标音色
           → 输出音频
     */

    UIAlertController *alert =
    [UIAlertController
     alertControllerWithTitle:@"转换引擎"
     message:
     [NSString stringWithFormat:
      @"当前选择：%@\n%@\n\n"
       "真实 AI 转换引擎将在下一版本接入。",
      modeName,
      toneName]
     preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
     [UIAlertAction
      actionWithTitle:@"知道了"
      style:UIAlertActionStyleDefault
      handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

#pragma mark - 试听

- (void)playPressed:(UIButton *)sender {

    if (!self.audioURL) {

        self.statusLabel.text =
        @"还没有录音";

        return;
    }

    NSError *error = nil;

    self.player =
    [[AVAudioPlayer alloc]
     initWithContentsOfURL:self.audioURL
     error:&error];

    if (error) {

        self.statusLabel.text =
        @"试听失败";

        return;
    }

    [self.player prepareToPlay];
    [self.player play];

    self.statusLabel.text =
    @"正在试听……";
}

@end


#pragma mark - 插件入口

@interface VoiceRebuildTestController : NSObject
+ (void)showButton;
@end

@implementation VoiceRebuildTestController

+ (void)showButton {

    dispatch_async(dispatch_get_main_queue(), ^{

        UIWindow *window = nil;

        if (@available(iOS 13.0, *)) {

            for (UIScene *scene
                 in UIApplication.sharedApplication.connectedScenes) {

                if (scene.activationState !=
                    UISceneActivationStateForegroundActive)
                    continue;

                if (![scene isKindOfClass:
                      [UIWindowScene class]])
                    continue;

                for (UIWindow *w
                     in ((UIWindowScene *)scene).windows) {

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
            UIApplication.sharedApplication.keyWindow;

        if (!window)
            return;

        if ([window viewWithTag:987654])
            return;

        UIButton *button =
        [UIButton buttonWithType:UIButtonTypeSystem];

        button.frame =
        CGRectMake(window.bounds.size.width - 125,
                   100,
                   105,
                   45);

        button.backgroundColor =
        UIColor.systemBlueColor;

        [button setTitle:@"语音插件"
                forState:UIControlStateNormal];

        [button setTitleColor:UIColor.whiteColor
                     forState:UIControlStateNormal];

        button.layer.cornerRadius = 10;
        button.tag = 987654;

        [button addTarget:self
                   action:@selector(openPanel:)
         forControlEvents:UIControlEventTouchUpInside];

        [window addSubview:button];
    });
}

+ (void)openPanel:(UIButton *)sender {

    VoiceRebuildPanel *panel =
    [[VoiceRebuildPanel alloc] init];

    UINavigationController *nav =
    [[UINavigationController alloc]
     initWithRootViewController:panel];

    UIViewController *vc =
    sender.window.rootViewController;

    while (vc.presentedViewController)
        vc = vc.presentedViewController;

    [vc presentViewController:nav
                     animated:YES
                   completion:nil];
}

@end


#pragma mark - dylib 加载

__attribute__((constructor))
static void VoiceRebuild_Loaded(void) {

    NSLog(@"[VoiceRebuild] V0.4 loaded");

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3.0 *
                      NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [VoiceRebuildTestController
             showButton];
        });
}
