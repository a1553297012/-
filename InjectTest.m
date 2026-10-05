#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import <objc/runtime.h>

#pragma mark - Log

static void HBWriteLog(NSString *format, ...)
{
    va_list args;
    va_start(args, format);

    NSString *message =
        [[NSString alloc] initWithFormat:format arguments:args];

    va_end(args);

    NSString *path =
        [NSHomeDirectory()
         stringByAppendingPathComponent:@"Documents/HBInjectTest.log"];

    NSString *line =
        [NSString stringWithFormat:@"[%@] %@\n",
         [NSDate date],
         message];

    NSFileHandle *file =
        [NSFileHandle fileHandleForWritingAtPath:path];

    if (file)
    {
        [file seekToEndOfFile];

        [file writeData:
         [line dataUsingEncoding:NSUTF8StringEncoding]];

        [file closeFile];
    }
    else
    {
        [line writeToFile:path
               atomically:YES
                 encoding:NSUTF8StringEncoding
                    error:nil];
    }

    NSLog(@"[HBVoicePlugin] %@", message);
}

#pragma mark - Text To Speech View Controller

@interface HBTextToSpeechViewController
    : UIViewController
    <UIPickerViewDataSource, UIPickerViewDelegate,
     UITextViewDelegate, AVSpeechSynthesizerDelegate>

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UIPickerView *voicePicker;
@property (nonatomic, strong) UISlider *rateSlider;
@property (nonatomic, strong) UILabel *rateLabel;
@property (nonatomic, strong) UILabel *voiceLabel;

@property (nonatomic, strong) UIButton *playButton;
@property (nonatomic, strong) UIButton *stopButton;

@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, strong) NSArray *voices;

@property (nonatomic, assign) NSInteger selectedVoiceIndex;

@end

@implementation HBTextToSpeechViewController

#pragma mark - View Did Load

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"文本转语音";

    if (@available(iOS 13.0, *))
    {
        self.view.backgroundColor =
            [UIColor systemGroupedBackgroundColor];
    }
    else
    {
        self.view.backgroundColor =
            [UIColor groupTableViewBackgroundColor];
    }

    self.synthesizer =
        [[AVSpeechSynthesizer alloc] init];

    self.synthesizer.delegate = self;

    /*
     * 获取系统语音
     */
    NSArray *allVoices =
        [AVSpeechSynthesisVoice speechVoices];

    NSMutableArray *voiceArray =
        [NSMutableArray array];

    for (AVSpeechSynthesisVoice *voice in allVoices)
    {
        NSString *language =
            voice.language.lowercaseString;

        /*
         * 第一版优先显示中文和英文系统音色
         */
        if ([language hasPrefix:@"zh"] ||
            [language hasPrefix:@"en"])
        {
            [voiceArray addObject:voice];
        }
    }

    /*
     * 如果没有找到中文/英文音色
     * 就使用系统全部音色
     */
    if (voiceArray.count == 0)
    {
        voiceArray =
            [allVoices mutableCopy];
    }

    self.voices = [voiceArray copy];

    self.selectedVoiceIndex = 0;

    HBWriteLog(
        @"系统语音数量 = %lu",
        (unsigned long)self.voices.count
    );

    [self HBCreateUI];
}

#pragma mark - Create UI

- (void)HBCreateUI
{
    CGFloat width =
        self.view.bounds.size.width;

    CGFloat top =
        20.0;

    /*
     * 输入文字
     */

    UILabel *inputTitle =
        [[UILabel alloc]
         initWithFrame:CGRectMake(
             20,
             top,
             width - 40,
             25
         )];

    inputTitle.text = @"输入文字";
    inputTitle.font =
        [UIFont boldSystemFontOfSize:17.0];

    [self.view addSubview:inputTitle];

    top += 35.0;

    self.textView =
        [[UITextView alloc]
         initWithFrame:CGRectMake(
             20,
             top,
             width - 40,
             130
         )];

    self.textView.backgroundColor =
        [UIColor whiteColor];

    self.textView.layer.cornerRadius = 10.0;

    self.textView.layer.borderWidth = 0.5;

    self.textView.layer.borderColor =
        [UIColor lightGrayColor].CGColor;

    self.textView.font =
        [UIFont systemFontOfSize:17.0];

    self.textView.text =
        @"你好，这是语音工具的文本转语音测试。";

    self.textView.delegate = self;

    [self.view addSubview:self.textView];

    top += 145.0;

    /*
     * 音色
     */

    self.voiceLabel =
        [[UILabel alloc]
         initWithFrame:CGRectMake(
             20,
             top,
             width - 40,
             25
         )];

    self.voiceLabel.text =
        @"系统音色";

    self.voiceLabel.font =
        [UIFont boldSystemFontOfSize:17.0];

    [self.view addSubview:self.voiceLabel];

    top += 30.0;

    self.voicePicker =
        [[UIPickerView alloc]
         initWithFrame:CGRectMake(
             0,
             top,
             width,
             130
         )];

    self.voicePicker.dataSource = self;
    self.voicePicker.delegate = self;

    [self.view addSubview:self.voicePicker];

    /*
     * 默认选择第一个
     */
    if (self.voices.count > 0)
    {
        [self.voicePicker
         selectRow:0
         inComponent:0
         animated:NO];

        [self HBUpdateVoiceLabel:0];
    }

    top += 140.0;

    /*
     * 语速
     */

    self.rateLabel =
        [[UILabel alloc]
         initWithFrame:CGRectMake(
             20,
             top,
             width - 40,
             25
         )];

    self.rateLabel.font =
        [UIFont boldSystemFontOfSize:17.0];

    self.rateLabel.text =
        @"语速：正常";

    [self.view addSubview:self.rateLabel];

    top += 35.0;

    self.rateSlider =
        [[UISlider alloc]
         initWithFrame:CGRectMake(
             20,
             top,
             width - 40,
             30
         )];

    /*
     * iOS 系统语音推荐范围
     */
    self.rateSlider.minimumValue =
        AVSpeechUtteranceMinimumSpeechRate;

    self.rateSlider.maximumValue =
        AVSpeechUtteranceMaximumSpeechRate;

    self.rateSlider.value =
        AVSpeechUtteranceDefaultSpeechRate;

    [self.rateSlider addTarget:self
                        action:@selector(HBRateChanged:)
              forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.rateSlider];

    top += 50.0;

    /*
     * 播放按钮
     */

    self.playButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.playButton.frame =
        CGRectMake(
            20,
            top,
            (width - 60) / 2.0,
            50
        );

    [self.playButton
     setTitle:@"▶ 播放"
     forState:UIControlStateNormal];

    self.playButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:17.0];

    self.playButton.backgroundColor =
        [UIColor whiteColor];

    self.playButton.layer.cornerRadius = 12.0;

    [self.playButton addTarget:self
                        action:@selector(HBPlay)
              forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.playButton];

    /*
     * 停止按钮
     */

    self.stopButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.stopButton.frame =
        CGRectMake(
            (width - 20) / 2.0 + 10,
            top,
            (width - 60) / 2.0,
            50
        );

    [self.stopButton
     setTitle:@"⏹ 停止"
     forState:UIControlStateNormal];

    self.stopButton.titleLabel.font =
        [UIFont boldSystemFontOfSize:17.0];

    self.stopButton.backgroundColor =
        [UIColor whiteColor];

    self.stopButton.layer.cornerRadius = 12.0;

    [self.stopButton addTarget:self
                        action:@selector(HBStop)
              forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.stopButton];

    HBWriteLog(@"文本转语音页面创建成功");
}

#pragma mark - Voice Label

- (void)HBUpdateVoiceLabel:(NSInteger)index
{
    if (index < 0 ||
        index >= self.voices.count)
    {
        return;
    }

    AVSpeechSynthesisVoice *voice =
        self.voices[index];

    self.voiceLabel.text =
        [NSString stringWithFormat:
         @"音色：%@ (%@)",
         voice.name,
         voice.language];

    self.selectedVoiceIndex = index;

    HBWriteLog(
        @"选择音色：%@ / %@",
        voice.name,
        voice.language
    );
}

#pragma mark - Voice Picker

- (NSInteger)numberOfComponentsInPickerView:
    (UIPickerView *)pickerView
{
    return 1;
}

- (NSInteger)pickerView:
    (UIPickerView *)pickerView
    numberOfRowsInComponent:(NSInteger)component
{
    return self.voices.count;
}

- (NSString *)pickerView:
    (UIPickerView *)pickerView
    titleForRow:(NSInteger)row
    forComponent:(NSInteger)component
{
    if (row >= self.voices.count)
    {
        return @"";
    }

    AVSpeechSynthesisVoice *voice =
        self.voices[row];

    return [NSString stringWithFormat:
            @"%@  %@", 
            voice.name,
            voice.language];
}

- (void)pickerView:
    (UIPickerView *)pickerView
    didSelectRow:(NSInteger)row
    inComponent:(NSInteger)component
{
    [self HBUpdateVoiceLabel:row];
}

#pragma mark - Rate

- (void)HBRateChanged:(UISlider *)slider
{
    float value = slider.value;

    if (value < 0.4)
    {
        self.rateLabel.text =
            @"语速：较慢";
    }
    else if (value < 0.52)
    {
        self.rateLabel.text =
            @"语速：正常";
    }
    else if (value < 0.62)
    {
        self.rateLabel.text =
            @"语速：较快";
    }
    else
    {
        self.rateLabel.text =
            @"语速：很快";
    }

    HBWriteLog(
        @"语速调整 = %.3f",
        value
    );
}

#pragma mark - Play

- (void)HBPlay
{
    /*
     * 收起键盘
     */
    [self.view endEditing:YES];

    NSString *text =
        self.textView.text;

    if (!text ||
        text.length == 0)
    {
        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:@"提示"
             message:@"请先输入要转换的文字"
             preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"确定"
          style:UIAlertActionStyleDefault
          handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];

        return;
    }

    /*
     * 如果正在播放，先停止
     */
    if (self.synthesizer.isSpeaking)
    {
        [self.synthesizer
         stopSpeakingAtBoundary:
         AVSpeechBoundaryImmediate];
    }

    AVSpeechUtterance *utterance =
        [[AVSpeechUtterance alloc]
         initWithString:text];

    /*
     * 设置语速
     */
    utterance.rate =
        self.rateSlider.value;

    /*
     * 设置音量
     */
    utterance.volume = 1.0;

    /*
     * 设置音色
     */
    if (self.selectedVoiceIndex >= 0 &&
        self.selectedVoiceIndex < self.voices.count)
    {
        AVSpeechSynthesisVoice *voice =
            self.voices[self.selectedVoiceIndex];

        utterance.voice = voice;

        HBWriteLog(
            @"开始播放：音色=%@，语言=%@，语速=%.3f",
            voice.name,
            voice.language,
            utterance.rate
        );
    }
    else
    {
        /*
         * 没有选择到音色时
         * 使用中文系统默认音色
         */
        utterance.voice =
            [AVSpeechSynthesisVoice
             voiceWithLanguage:@"zh-CN"];

        HBWriteLog(
            @"没有选择音色，使用 zh-CN"
        );
    }

    [self.synthesizer
     speakUtterance:utterance];

    [self.playButton
     setTitle:@"▶ 播放中..."
     forState:UIControlStateNormal];
}

#pragma mark - Stop

- (void)HBStop
{
    if (self.synthesizer.isSpeaking)
    {
        [self.synthesizer
         stopSpeakingAtBoundary:
         AVSpeechBoundaryImmediate];

        HBWriteLog(@"停止语音播放");
    }

    [self.playButton
     setTitle:@"▶ 播放"
     forState:UIControlStateNormal];
}

#pragma mark - Speech Delegate

- (void)speechSynthesizer:
    (AVSpeechSynthesizer *)synthesizer
    didStartSpeechUtterance:
    (AVSpeechUtterance *)utterance
{
    HBWriteLog(@"语音开始播放");
}

- (void)speechSynthesizer:
    (AVSpeechSynthesizer *)synthesizer
    didFinishSpeechUtterance:
    (AVSpeechUtterance *)utterance
{
    HBWriteLog(@"语音播放完成");

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [self.playButton
             setTitle:@"▶ 播放"
             forState:UIControlStateNormal];
        }
    );
}

- (void)speechSynthesizer:
    (AVSpeechSynthesizer *)synthesizer
    didCancelSpeechUtterance:
    (AVSpeechUtterance *)utterance
{
    HBWriteLog(@"语音播放取消");

    dispatch_async(
        dispatch_get_main_queue(),
        ^{
            [self.playButton
             setTitle:@"▶ 播放"
             forState:UIControlStateNormal];
        }
    );
}

#pragma mark - Keyboard

- (BOOL)textView:
    (UITextView *)textView
    shouldChangeTextInRange:(NSRange)range
    replacementText:(NSString *)text
{
    /*
     * 换行正常允许
     */
    return YES;
}

#pragma mark - Disappear

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];

    /*
     * 离开页面自动停止
     */
    if (self.synthesizer.isSpeaking)
    {
        [self.synthesizer
         stopSpeakingAtBoundary:
         AVSpeechBoundaryImmediate];

        HBWriteLog(
            @"离开文本转语音页面，停止播放"
        );
    }
}

@end

#pragma mark - Voice Tool View Controller

@interface HBVoiceToolViewController
    : UIViewController
    <UITableViewDataSource, UITableViewDelegate>
@end

@implementation HBVoiceToolViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"语音工具";

    if (@available(iOS 13.0, *))
    {
        self.view.backgroundColor =
            [UIColor systemGroupedBackgroundColor];
    }
    else
    {
        self.view.backgroundColor =
            [UIColor groupTableViewBackgroundColor];
    }

    UITableView *tableView =
        [[UITableView alloc]
         initWithFrame:self.view.bounds
         style:UITableViewStyleGrouped];

    tableView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth |
        UIViewAutoresizingFlexibleHeight;

    tableView.dataSource = self;
    tableView.delegate = self;

    [self.view addSubview:tableView];

    HBWriteLog(@"语音工具页面创建成功");
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:
    (UITableView *)tableView
    numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 3;
    }

    return 2;
}

- (NSString *)tableView:
    (UITableView *)tableView
    titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return @"语音功能";
    }

    return @"语音设置";
}

- (UITableViewCell *)
tableView:(UITableView *)tableView
cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier =
        @"HBVoiceCell";

    UITableViewCell *cell =
        [tableView
         dequeueReusableCellWithIdentifier:identifier];

    if (!cell)
    {
        cell =
            [[UITableViewCell alloc]
             initWithStyle:UITableViewCellStyleValue1
             reuseIdentifier:identifier];
    }

    cell.textLabel.text = nil;
    cell.detailTextLabel.text = nil;

    if (indexPath.section == 0)
    {
        cell.accessoryType =
            UITableViewCellAccessoryDisclosureIndicator;

        if (indexPath.row == 0)
        {
            cell.textLabel.text =
                @"文本转语音";

            cell.detailTextLabel.text =
                @"输入文字并播放语音";
        }
        else if (indexPath.row == 1)
        {
            cell.textLabel.text =
                @"音频文件";

            cell.detailTextLabel.text =
                @"选择本地音频";
        }
        else
        {
            cell.textLabel.text =
                @"音色设置";

            cell.detailTextLabel.text =
                @"选择语音音色";
        }
    }
    else
    {
        cell.accessoryType =
            UITableViewCellAccessoryNone;

        if (indexPath.row == 0)
        {
            cell.textLabel.text =
                @"自定义语音时长";

            cell.detailTextLabel.text =
                @"开发中";
        }
        else
        {
            cell.textLabel.text =
                @"随机语音时长";

            cell.detailTextLabel.text =
                @"开发中";
        }
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:
    (UITableView *)tableView
    didSelectRowAtIndexPath:
    (NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];

    HBWriteLog(
        @"点击语音工具项目 section=%ld row=%ld",
        (long)indexPath.section,
        (long)indexPath.row
    );

    /*
     * 文本转语音
     */
    if (indexPath.section == 0 &&
        indexPath.row == 0)
    {
        HBTextToSpeechViewController *controller =
            [[HBTextToSpeechViewController alloc] init];

        controller.hidesBottomBarWhenPushed = YES;

        [self.navigationController
         pushViewController:controller
         animated:YES];

        return;
    }

    /*
     * 其他功能暂时保留
     */
    if (indexPath.section == 0 &&
        indexPath.row == 1)
    {
        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:@"音频文件"
             message:@"音频文件功能下一步实现"
             preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"确定"
          style:UIAlertActionStyleDefault
          handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];

        return;
    }

    if (indexPath.section == 0 &&
        indexPath.row == 2)
    {
        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:@"音色设置"
             message:@"音色设置已经包含在文本转语音页面中"
             preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"确定"
          style:UIAlertActionStyleDefault
          handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];

        return;
    }
}

@end

#pragma mark - Settings Hook

static void HBHookNewSettingViewController(void)
{
    Class settingsClass =
        NSClassFromString(@"NewSettingViewController");

    if (!settingsClass)
    {
        HBWriteLog(
            @"找不到 NewSettingViewController"
        );

        return;
    }

    SEL viewDidLoadSEL =
        @selector(viewDidLoad);

    Method method =
        class_getInstanceMethod(
            settingsClass,
            viewDidLoadSEL
        );

    if (!method)
    {
        HBWriteLog(
            @"NewSettingViewController 没有 viewDidLoad"
        );

        return;
    }

    static BOOL alreadyHooked = NO;

    if (alreadyHooked)
    {
        HBWriteLog(
            @"NewSettingViewController 已经 Hook"
        );

        return;
    }

    alreadyHooked = YES;

    static IMP originalIMP = NULL;

    originalIMP =
        method_getImplementation(method);

    IMP newIMP =
        imp_implementationWithBlock(
            ^(UIViewController *self)
            {
                /*
                 * 先执行微信原来的 viewDidLoad
                 */
                ((void (*)(id, SEL))
                 originalIMP)(
                    self,
                    viewDidLoadSEL
                );

                HBWriteLog(
                    @"NewSettingViewController viewDidLoad"
                );

                /*
                 * 防止重复添加
                 */
                UIView *marker =
                    [self.view viewWithTag:952713];

                if (marker)
                {
                    HBWriteLog(
                        @"语音工具按钮已经存在"
                    );

                    return;
                }

                /*
                 * 创建按钮
                 */
                UIButton *button =
                    [UIButton buttonWithType:
                     UIButtonTypeSystem];

                button.tag = 952713;

                [button setTitle:@"语音工具"
                         forState:UIControlStateNormal];

                CGFloat width =
                    self.view.bounds.size.width;

                CGFloat height =
                    self.view.bounds.size.height;

                button.frame =
                    CGRectMake(
                        20.0,
                        height - 80.0,
                        width - 40.0,
                        50.0
                    );

                button.autoresizingMask =
                    UIViewAutoresizingFlexibleWidth |
                    UIViewAutoresizingFlexibleTopMargin;

                if (@available(iOS 13.0, *))
                {
                    button.backgroundColor =
                        [UIColor secondarySystemBackgroundColor];
                }
                else
                {
                    button.backgroundColor =
                        [UIColor whiteColor];
                }

                button.layer.cornerRadius = 12.0;

                [button addTarget:self
                           action:@selector(
                               HBVoiceToolButtonPressed:)
                 forControlEvents:
                     UIControlEventTouchUpInside];

                [self.view addSubview:button];

                HBWriteLog(
                    @"已在设置页面添加【语音工具】按钮"
                );
            }
        );

    method_setImplementation(
        method,
        newIMP
    );

    HBWriteLog(
        @"成功 Hook NewSettingViewController"
    );
}

#pragma mark - Button Action

@interface UIViewController (HBVoicePlugin)

- (void)HBVoiceToolButtonPressed:(id)sender;

@end

@implementation UIViewController (HBVoicePlugin)

- (void)HBVoiceToolButtonPressed:(id)sender
{
    HBWriteLog(
        @"【语音工具】按钮被点击"
    );

    HBVoiceToolViewController *controller =
        [[HBVoiceToolViewController alloc] init];

    controller.hidesBottomBarWhenPushed = YES;

    if (self.navigationController)
    {
        [self.navigationController
         pushViewController:controller
         animated:YES];
    }
    else
    {
        [self presentViewController:controller
                           animated:YES
                         completion:nil];
    }
}

@end

#pragma mark - Constructor

__attribute__((constructor))
static void HBVoicePluginInit(void)
{
    @autoreleasepool
    {
        HBWriteLog(
            @"========================================"
        );

        HBWriteLog(
            @"HB VOICE PLUGIN START"
        );

        HBWriteLog(
            @"VERSION = 2.0"
        );

        HBWriteLog(
            @"PID = %d",
            getpid()
        );

        HBWriteLog(
            @"PROCESS = %@",
            [[NSProcessInfo processInfo] processName]
        );

        HBWriteLog(
            @"========================================"
        );

        /*
         * 等微信启动完成以后再 Hook
         */
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(5 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{
                HBHookNewSettingViewController();
            }
        );
    }
}
