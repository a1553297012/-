#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface VoiceRebuildPanel : UIViewController
@property(nonatomic,strong) AVAudioRecorder *recorder;
@property(nonatomic,strong) AVAudioPlayer *player;
@property(nonatomic,strong) NSURL *audioURL;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UIButton *recordButton;
@property(nonatomic,strong) UIButton *playButton;
@end

@implementation VoiceRebuildPanel

- (void)viewDidLoad {
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor whiteColor];

    self.title = @"VoiceRebuild V0.3";

    UILabel *title =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 40, 330, 40)];

    title.text = @"微信语音插件";
    title.font = [UIFont boldSystemFontOfSize:24];
    title.textAlignment = NSTextAlignmentCenter;

    [self.view addSubview:title];

    self.statusLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 95, 330, 40)];

    self.statusLabel.text = @"准备录音";
    self.statusLabel.textAlignment = NSTextAlignmentCenter;

    [self.view addSubview:self.statusLabel];

    self.recordButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    self.recordButton.frame =
    CGRectMake(70, 160, 260, 55);

    self.recordButton.backgroundColor =
    UIColor.systemBlueColor;

    [self.recordButton setTitle:@"开始录音"
                       forState:UIControlStateNormal];

    [self.recordButton setTitleColor:UIColor.whiteColor
                            forState:UIControlStateNormal];

    self.recordButton.layer.cornerRadius = 12;

    [self.recordButton addTarget:self
                          action:@selector(recordPressed:)
                forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.recordButton];

    self.playButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    self.playButton.frame =
    CGRectMake(70, 235, 260, 55);

    self.playButton.backgroundColor =
    UIColor.systemGrayColor;

    [self.playButton setTitle:@"试听"
                     forState:UIControlStateNormal];

    [self.playButton setTitleColor:UIColor.whiteColor
                          forState:UIControlStateNormal];

    self.playButton.layer.cornerRadius = 12;

    self.playButton.enabled = NO;

    [self.playButton addTarget:self
                        action:@selector(playPressed:)
              forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.playButton];
}

- (void)recordPressed:(UIButton *)sender {

    if (self.recorder.recording) {
        [self.recorder stop];

        self.statusLabel.text = @"录音完成，可以试听";

        [self.recordButton setTitle:@"重新录音"
                           forState:UIControlStateNormal];

        self.playButton.enabled = YES;

        return;
    }

    AVAudioSession *session =
    [AVAudioSession sharedInstance];

    [session setCategory:AVAudioSessionCategoryPlayAndRecord
             withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
                   error:nil];

    [session setActive:YES error:nil];

    [session requestRecordPermission:^(BOOL granted) {

        dispatch_async(dispatch_get_main_queue(), ^{

            if (!granted) {
                self.statusLabel.text = @"没有麦克风权限";
                return;
            }

            NSString *path =
            [NSTemporaryDirectory()
             stringByAppendingPathComponent:@"voice_v03.m4a"];

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
                self.statusLabel.text = @"录音初始化失败";
                return;
            }

            [self.recorder prepareToRecord];
            [self.recorder record];

            self.statusLabel.text = @"正在录音……";

            [self.recordButton setTitle:@"停止录音"
                               forState:UIControlStateNormal];
        });
    }];
}

- (void)playPressed:(UIButton *)sender {

    if (!self.audioURL)
        return;

    NSError *error = nil;

    self.player =
    [[AVAudioPlayer alloc]
     initWithContentsOfURL:self.audioURL
     error:&error];

    if (error) {
        self.statusLabel.text = @"试听失败";
        return;
    }

    [self.player prepareToPlay];
    [self.player play];

    self.statusLabel.text = @"正在试听……";
}

@end


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

                if (![scene isKindOfClass:[UIWindowScene class]])
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
            window = UIApplication.sharedApplication.keyWindow;

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


__attribute__((constructor))
static void VoiceRebuild_Loaded(void) {

    NSLog(@"[VoiceRebuild] V0.3 loaded");

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(3.0 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{
            [VoiceRebuildTestController showButton];
        });
}
