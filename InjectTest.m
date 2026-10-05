#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>

#pragma mark - Forward

@class HBVoiceTextToSpeechViewController;

#pragma mark - Keychain

@interface HBKeychain : NSObject
+ (void)saveAPIKey:(NSString *)key;
+ (NSString *)loadAPIKey;
+ (void)deleteAPIKey;
@end

@implementation HBKeychain

static NSString * const HBKeychainService = @"com.huangbai.voiceplugin";
static NSString * const HBKeychainAccount = @"siliconflow_api_key";

+ (void)saveAPIKey:(NSString *)key
{
    if (!key || key.length == 0) {
        return;
    }

    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : HBKeychainService,
        (__bridge id)kSecAttrAccount : HBKeychainAccount
    };

    SecItemDelete((__bridge CFDictionaryRef)query);

    NSMutableDictionary *item = [query mutableCopy];

    item[(__bridge id)kSecValueData] = data;

    SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}

+ (NSString *)loadAPIKey
{
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : HBKeychainService,
        (__bridge id)kSecAttrAccount : HBKeychainAccount,
        (__bridge id)kSecReturnData : @YES,
        (__bridge id)kSecMatchLimit : (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef result = NULL;

    OSStatus status = SecItemCopyMatching(
        (__bridge CFDictionaryRef)query,
        &result
    );

    if (status != errSecSuccess || !result) {
        return nil;
    }

    NSData *data = (__bridge_transfer NSData *)result;

    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (void)deleteAPIKey
{
    NSDictionary *query = @{
        (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService : HBKeychainService,
        (__bridge id)kSecAttrAccount : HBKeychainAccount
    };

    SecItemDelete((__bridge CFDictionaryRef)query);
}

@end


#pragma mark - Utility

static void HBShowAlert(UIViewController *vc,
                        NSString *title,
                        NSString *message)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:message
                                     preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction actionWithTitle:@"确定"
                                  style:UIAlertActionStyleDefault
                                handler:nil]];

        [vc presentViewController:alert
                         animated:YES
                       completion:nil];
    });
}


#pragma mark - API Key Controller

@interface HBVoiceAPIKeyViewController : UIViewController

@end

@implementation HBVoiceAPIKeyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    self.title = @"硅基流动 API";

    UILabel *tip = [[UILabel alloc] initWithFrame:CGRectMake(20, 25, self.view.bounds.size.width - 40, 80)];

    tip.text =
    @"请输入你自己的 SiliconFlow API Key。\n"
    @"Key 会保存到 iOS Keychain，不会写入插件源码。";

    tip.numberOfLines = 0;
    tip.font = [UIFont systemFontOfSize:14];
    tip.textColor = [UIColor secondaryLabelColor];

    [self.view addSubview:tip];

    UITextField *field =
    [[UITextField alloc] initWithFrame:CGRectMake(20, 120,
                                                   self.view.bounds.size.width - 40,
                                                   48)];

    field.backgroundColor = [UIColor secondarySystemBackgroundColor];
    field.layer.cornerRadius = 10;
    field.layer.masksToBounds = YES;

    field.leftView =
    [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 1)];

    field.leftViewMode = UITextFieldViewModeAlways;

    field.placeholder = @"sk-xxxxxxxx";
    field.secureTextEntry = YES;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;

    NSString *oldKey = [HBKeychain loadAPIKey];

    if (oldKey.length > 0) {
        field.text = oldKey;
    }

    [self.view addSubview:field];

    UIButton *save =
    [UIButton buttonWithType:UIButtonTypeSystem];

    save.frame = CGRectMake(20, 185,
                            self.view.bounds.size.width - 40,
                            48);

    save.backgroundColor = [UIColor systemBlueColor];
    save.layer.cornerRadius = 10;

    [save setTitle:@"保存 API Key"
          forState:UIControlStateNormal];

    [save setTitleColor:[UIColor whiteColor]
              forState:UIControlStateNormal];

    [save addTarget:self
             action:@selector(saveKey:)
   forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:save];

    UIButton *deleteButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    deleteButton.frame =
    CGRectMake(20, 245,
               self.view.bounds.size.width - 40,
               48);

    [deleteButton setTitle:@"删除 API Key"
                  forState:UIControlStateNormal];

    [deleteButton addTarget:self
                     action:@selector(deleteKey:)
           forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:deleteButton];
}

- (void)saveKey:(UIButton *)sender
{
    UITextField *field = nil;

    for (UIView *view in self.view.subviews) {

        if ([view isKindOfClass:[UITextField class]]) {
            field = (UITextField *)view;
            break;
        }
    }

    NSString *key = [field.text
                     stringByTrimmingCharactersInSet:
                     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (key.length == 0) {
        HBShowAlert(self, @"提示", @"API Key 不能为空。");
        return;
    }

    [HBKeychain saveAPIKey:key];

    HBShowAlert(self, @"保存成功", @"API Key 已保存到 Keychain。");
}

- (void)deleteKey:(UIButton *)sender
{
    [HBKeychain deleteAPIKey];

    for (UIView *view in self.view.subviews) {

        if ([view isKindOfClass:[UITextField class]]) {
            ((UITextField *)view).text = @"";
        }
    }

    HBShowAlert(self, @"完成", @"API Key 已删除。");
}

@end


#pragma mark - SiliconFlow TTS

@interface HBSiliconFlowTTS : NSObject

@property(nonatomic,strong) NSURLSessionDataTask *task;

+ (instancetype)shared;

- (void)synthesizeText:(NSString *)text
                 voice:(NSString *)voice
                 speed:(CGFloat)speed
                  gain:(CGFloat)gain
            completion:(void (^)(NSData *audioData,
                                 NSError *error))completion;

- (void)cancel;

@end


@implementation HBSiliconFlowTTS

+ (instancetype)shared
{
    static HBSiliconFlowTTS *instance;

    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        instance = [[HBSiliconFlowTTS alloc] init];
    });

    return instance;
}

- (void)synthesizeText:(NSString *)text
                 voice:(NSString *)voice
                 speed:(CGFloat)speed
                  gain:(CGFloat)gain
            completion:(void (^)(NSData *, NSError *))completion
{
    NSString *apiKey = [HBKeychain loadAPIKey];

    if (apiKey.length == 0) {

        NSError *error =
        [NSError errorWithDomain:@"HBVoice"
                            code:1001
                        userInfo:@{
            NSLocalizedDescriptionKey :
            @"还没有设置 SiliconFlow API Key。"
        }];

        if (completion) {
            completion(nil, error);
        }

        return;
    }

    [self cancel];

    NSURL *url =
    [NSURL URLWithString:
     @"https://api.siliconflow.cn/v1/audio/speech"];

    NSMutableURLRequest *request =
    [NSMutableURLRequest requestWithURL:url];

    request.HTTPMethod = @"POST";

    [request setValue:@"application/json"
   forHTTPHeaderField:@"Content-Type"];

    NSString *authorization =
    [NSString stringWithFormat:@"Bearer %@", apiKey];

    [request setValue:authorization
   forHTTPHeaderField:@"Authorization"];

    CGFloat realSpeed = MAX(0.25, MIN(4.0, speed));
    CGFloat realGain = MAX(-10.0, MIN(10.0, gain));

    NSDictionary *body = @{
        @"model" : @"fnlp/MOSS-TTSD-v0.5",

        @"input" : text,

        @"voice" :
        [NSString stringWithFormat:
         @"fnlp/MOSS-TTSD-v0.5:%@",
         voice.length > 0 ? voice : @"alex"],

        @"response_format" : @"mp3",

        @"speed" : @(realSpeed),

        @"gain" : @(realGain)
    };

    NSError *jsonError = nil;

    NSData *jsonData =
    [NSJSONSerialization dataWithJSONObject:body
                                    options:0
                                      error:&jsonError];

    if (!jsonData) {

        if (completion) {
            completion(nil, jsonError);
        }

        return;
    }

    request.HTTPBody = jsonData;

    NSURLSessionConfiguration *configuration =
    [NSURLSessionConfiguration defaultSessionConfiguration];

    configuration.timeoutIntervalForRequest = 120.0;
    configuration.timeoutIntervalForResource = 180.0;

    NSURLSession *session =
    [NSURLSession sessionWithConfiguration:configuration];

    __weak typeof(self) weakSelf = self;

    self.task =
    [session dataTaskWithRequest:request
               completionHandler:
     ^(NSData *data,
       NSURLResponse *response,
       NSError *error) {

        __strong typeof(weakSelf) strongSelf = weakSelf;

        dispatch_async(dispatch_get_main_queue(), ^{
            strongSelf.task = nil;
        });

        if (error) {

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, error);
                });
            }

            return;
        }

        NSHTTPURLResponse *httpResponse =
        (NSHTTPURLResponse *)response;

        NSInteger statusCode =
        httpResponse.statusCode;

        if (statusCode != 200) {

            NSString *message =
            [[NSString alloc] initWithData:data
                                  encoding:NSUTF8StringEncoding];

            if (message.length == 0) {
                message = @"服务器返回错误。";
            }

            NSError *serverError =
            [NSError errorWithDomain:@"HBSiliconFlow"
                                code:statusCode
                            userInfo:@{
                NSLocalizedDescriptionKey :
                [NSString stringWithFormat:
                 @"SiliconFlow HTTP %ld：%@",
                 (long)statusCode,
                 message]
            }];

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, serverError);
                });
            }

            return;
        }

        if (!data || data.length == 0) {

            NSError *emptyError =
            [NSError errorWithDomain:@"HBSiliconFlow"
                                code:1002
                            userInfo:@{
                NSLocalizedDescriptionKey :
                @"服务器返回了空音频。"
            }];

            if (completion) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil, emptyError);
                });
            }

            return;
        }

        if (completion) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(data, nil);
            });
        }
    }];

    [self.task resume];
}

- (void)cancel
{
    [self.task cancel];
    self.task = nil;
}

@end


#pragma mark - Text To Speech

@interface HBVoiceTextToSpeechViewController
    : UIViewController
    <AVAudioPlayerDelegate>

@property(nonatomic,strong) UITextView *textView;
@property(nonatomic,strong) UISlider *speedSlider;
@property(nonatomic,strong) UISlider *gainSlider;
@property(nonatomic,strong) UILabel *speedLabel;
@property(nonatomic,strong) UILabel *gainLabel;
@property(nonatomic,strong) UILabel *statusLabel;
@property(nonatomic,strong) UITextField *voiceField;
@property(nonatomic,strong) AVAudioPlayer *audioPlayer;

@end


@implementation HBVoiceTextToSpeechViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.view.backgroundColor =
    [UIColor systemGroupedBackgroundColor];

    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    self.title = @"文本转语音";

    CGFloat width = self.view.bounds.size.width;

    UILabel *textLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 20,
                                               width - 40, 25)];

    textLabel.text = @"输入文字";
    textLabel.font =
    [UIFont boldSystemFontOfSize:16];

    [self.view addSubview:textLabel];

    self.textView =
    [[UITextView alloc] initWithFrame:CGRectMake(20, 52,
                                                  width - 40, 150)];

    self.textView.backgroundColor =
    [UIColor secondarySystemBackgroundColor];

    self.textView.layer.cornerRadius = 10;

    self.textView.font =
    [UIFont systemFontOfSize:17];

    self.textView.text =
    @"你好，这是一段由 SiliconFlow MOSS-TTSD 生成的语音。";

    [self.view addSubview:self.textView];


    UILabel *voiceLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 218,
                                               80, 30)];

    voiceLabel.text = @"音色";
    voiceLabel.font =
    [UIFont systemFontOfSize:16];

    [self.view addSubview:voiceLabel];


    self.voiceField =
    [[UITextField alloc] initWithFrame:CGRectMake(95, 214,
                                                  width - 115, 40)];

    self.voiceField.backgroundColor =
    [UIColor secondarySystemBackgroundColor];

    self.voiceField.layer.cornerRadius = 8;

    self.voiceField.leftView =
    [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 1)];

    self.voiceField.leftViewMode =
    UITextFieldViewModeAlways;

    self.voiceField.text = @"alex";

    self.voiceField.placeholder = @"例如 alex";

    [self.view addSubview:self.voiceField];


    self.speedLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 270,
                                               width - 40, 25)];

    self.speedLabel.text = @"语速：1.00";
    self.speedLabel.font =
    [UIFont systemFontOfSize:15];

    [self.view addSubview:self.speedLabel];


    self.speedSlider =
    [[UISlider alloc] initWithFrame:CGRectMake(20, 298,
                                                width - 40, 35)];

    self.speedSlider.minimumValue = 0.25;
    self.speedSlider.maximumValue = 4.0;
    self.speedSlider.value = 1.0;

    [self.speedSlider addTarget:self
                         action:@selector(speedChanged:)
               forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.speedSlider];


    self.gainLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 345,
                                               width - 40, 25)];

    self.gainLabel.text = @"音量增益：0.0 dB";
    self.gainLabel.font =
    [UIFont systemFontOfSize:15];

    [self.view addSubview:self.gainLabel];


    self.gainSlider =
    [[UISlider alloc] initWithFrame:CGRectMake(20, 373,
                                                width - 40, 35)];

    self.gainSlider.minimumValue = -10.0;
    self.gainSlider.maximumValue = 10.0;
    self.gainSlider.value = 0.0;

    [self.gainSlider addTarget:self
                        action:@selector(gainChanged:)
              forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.gainSlider];


    UIButton *apiButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    apiButton.frame =
    CGRectMake(20, 425,
               (width - 50) / 2.0,
               48);

    apiButton.backgroundColor =
    [UIColor secondarySystemBackgroundColor];

    apiButton.layer.cornerRadius = 10;

    [apiButton setTitle:@"API 设置"
               forState:UIControlStateNormal];

    [apiButton addTarget:self
                  action:@selector(apiSetting:)
        forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:apiButton];


    UIButton *generateButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    generateButton.frame =
    CGRectMake(30 + (width - 50) / 2.0,
               425,
               (width - 50) / 2.0,
               48);

    generateButton.backgroundColor =
    [UIColor systemBlueColor];

    generateButton.layer.cornerRadius = 10;

    [generateButton setTitle:@"生成并播放"
                    forState:UIControlStateNormal];

    [generateButton setTitleColor:[UIColor whiteColor]
                         forState:UIControlStateNormal];

    [generateButton addTarget:self
                       action:@selector(generate:)
             forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:generateButton];


    UIButton *stopButton =
    [UIButton buttonWithType:UIButtonTypeSystem];

    stopButton.frame =
    CGRectMake(20, 485,
               width - 40,
               45);

    [stopButton setTitle:@"停止播放"
                forState:UIControlStateNormal];

    [stopButton addTarget:self
                   action:@selector(stop:)
         forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:stopButton];


    self.statusLabel =
    [[UILabel alloc] initWithFrame:CGRectMake(20, 540,
                                               width - 40, 50)];

    self.statusLabel.text =
    @"状态：等待生成";

    self.statusLabel.numberOfLines = 2;

    self.statusLabel.textAlignment =
    NSTextAlignmentCenter;

    self.statusLabel.textColor =
    [UIColor secondaryLabelColor];

    [self.view addSubview:self.statusLabel];
}

#pragma mark - Slider

- (void)speedChanged:(UISlider *)slider
{
    self.speedLabel.text =
    [NSString stringWithFormat:@"语速：%.2f",
     slider.value];
}

- (void)gainChanged:(UISlider *)slider
{
    self.gainLabel.text =
    [NSString stringWithFormat:@"音量增益：%.1f dB",
     slider.value];
}

#pragma mark - API

- (void)apiSetting:(UIButton *)sender
{
    HBVoiceAPIKeyViewController *vc =
    [[HBVoiceAPIKeyViewController alloc] init];

    [self.navigationController pushViewController:vc
                                         animated:YES];
}

#pragma mark - Generate

- (void)generate:(UIButton *)sender
{
    NSString *text =
    [self.textView.text
     stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (text.length == 0) {

        HBShowAlert(self,
                    @"提示",
                    @"请输入要转换的文字。");

        return;
    }

    NSString *apiKey = [HBKeychain loadAPIKey];

    if (apiKey.length == 0) {

        UIAlertController *alert =
        [UIAlertController
         alertControllerWithTitle:@"还没有 API Key"
         message:@"请先设置 SiliconFlow API Key。"
         preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"去设置"
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction *action) {

            [self apiSetting:nil];

        }]];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"取消"
          style:UIAlertActionStyleCancel
          handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];

        return;
    }

    [self.audioPlayer stop];

    [[HBSiliconFlowTTS shared] cancel];

    self.statusLabel.text =
    @"状态：正在生成语音……";

    CGFloat speed =
    self.speedSlider.value;

    CGFloat gain =
    self.gainSlider.value;

    NSString *voice =
    [self.voiceField.text
     stringByTrimmingCharactersInSet:
     [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (voice.length == 0) {
        voice = @"alex";
    }

    __weak typeof(self) weakSelf = self;

    [[HBSiliconFlowTTS shared]
     synthesizeText:text
     voice:voice
     speed:speed
     gain:gain
     completion:^(NSData *audioData,
                  NSError *error) {

        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) {
            return;
        }

        if (error) {

            strongSelf.statusLabel.text =
            @"状态：生成失败";

            HBShowAlert(strongSelf,
                        @"生成失败",
                        error.localizedDescription);

            return;
        }

        if (!audioData) {
            return;
        }

        NSString *directory =
        [NSSearchPathForDirectoriesInDomains(
            NSCachesDirectory,
            NSUserDomainMask,
            YES
        ) firstObject];

        NSString *fileName =
        [NSString stringWithFormat:
         @"HBVoice_%f.mp3",
         [[NSDate date] timeIntervalSince1970]];

        NSString *filePath =
        [directory stringByAppendingPathComponent:fileName];

        NSURL *fileURL =
        [NSURL fileURLWithPath:filePath];

        BOOL written =
        [audioData writeToURL:fileURL
                      options:NSDataWritingAtomic
                        error:&error];

        if (!written || error) {

            strongSelf.statusLabel.text =
            @"状态：保存音频失败";

            HBShowAlert(strongSelf,
                        @"保存失败",
                        error.localizedDescription);

            return;
        }

        NSError *playerError = nil;

        strongSelf.audioPlayer =
        [[AVAudioPlayer alloc]
         initWithContentsOfURL:fileURL
         error:&playerError];

        strongSelf.audioPlayer.delegate =
        strongSelf;

        if (playerError ||
            !strongSelf.audioPlayer) {

            strongSelf.statusLabel.text =
            @"状态：音频播放失败";

            HBShowAlert(strongSelf,
                        @"播放失败",
                        playerError.localizedDescription);

            return;
        }

        [strongSelf.audioPlayer prepareToPlay];

        BOOL success =
        [strongSelf.audioPlayer play];

        if (success) {

            strongSelf.statusLabel.text =
            @"状态：正在播放 SiliconFlow 语音";

        } else {

            strongSelf.statusLabel.text =
            @"状态：播放启动失败";
        }
    }];
}

#pragma mark - Stop

- (void)stop:(UIButton *)sender
{
    [[HBSiliconFlowTTS shared] cancel];

    [self.audioPlayer stop];

    self.statusLabel.text =
    @"状态：已停止";
}

#pragma mark - Audio

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player
                       successfully:(BOOL)flag
{
    self.statusLabel.text =
    flag ? @"状态：播放完成"
         : @"状态：播放异常";
}

@end


#pragma mark - Voice Tool

@interface HBVoiceToolViewController : UITableViewController
@end


@implementation HBVoiceToolViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = @"语音工具";

    self.tableView.backgroundColor =
    [UIColor systemGroupedBackgroundColor];
}

- (NSInteger)numberOfSectionsInTableView:
(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:
(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    return 3;
}

- (UITableViewCell *)tableView:
(UITableView *)tableView
 cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell =
    [[UITableViewCell alloc]
     initWithStyle:UITableViewCellStyleSubtitle
     reuseIdentifier:nil];

    if (indexPath.row == 0) {

        cell.textLabel.text = @"文本转语音";

        cell.detailTextLabel.text =
        @"SiliconFlow MOSS-TTSD";

        cell.accessoryType =
        UITableViewCellAccessoryDisclosureIndicator;

    } else if (indexPath.row == 1) {

        cell.textLabel.text = @"音频文件";

        cell.detailTextLabel.text =
        @"后续加入音频导入与管理";

        cell.textLabel.textColor =
        [UIColor secondaryLabelColor];

    } else {

        cell.textLabel.text = @"音色设置";

        cell.detailTextLabel.text =
        @"当前默认 alex";

        cell.accessoryType =
        UITableViewCellAccessoryDisclosureIndicator;
    }

    return cell;
}

- (void)tableView:
(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath
                              animated:YES];

    if (indexPath.row == 0) {

        HBVoiceTextToSpeechViewController *vc =
        [[HBVoiceTextToSpeechViewController alloc]
         init];

        [self.navigationController pushViewController:vc
                                             animated:YES];

    } else if (indexPath.row == 2) {

        UIAlertController *alert =
        [UIAlertController
         alertControllerWithTitle:@"音色"
         message:@"目前先使用 SiliconFlow 的 alex 音色。\n\n"
                 @"后面可以继续加入音色列表。"
         preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction actionWithTitle:@"确定"
                                  style:UIAlertActionStyleDefault
                                handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];
    }
}

@end


#pragma mark - Setting Hook

static void HBAddVoiceToolEntry(UIViewController *controller)
{
    if (![controller isKindOfClass:
          NSClassFromString(@"NewSettingViewController")]) {
        return;
    }

    UITableView *tableView = nil;

    for (UIView *view in controller.view.subviews) {

        if ([view isKindOfClass:
             [UITableView class]]) {

            tableView = (UITableView *)view;
            break;
        }
    }

    if (!tableView) {
        return;
    }

    // 避免重复添加
    for (NSInteger section = 0;
         section < [tableView numberOfSections];
         section++) {

        for (NSInteger row = 0;
             row < [tableView numberOfRowsInSection:section];
             row++) {

            NSIndexPath *indexPath =
            [NSIndexPath indexPathForRow:row
                               inSection:section];

            UITableViewCell *cell =
            [tableView cellForRowAtIndexPath:indexPath];

            if ([cell.textLabel.text isEqualToString:@"语音工具"]) {
                return;
            }
        }
    }

    // 找到 dataSource
    id dataSource = tableView.dataSource;

    if (!dataSource) {
        return;
    }

    // 创建自己的语音工具 cell
    UITableViewCell *cell =
    [[UITableViewCell alloc]
     initWithStyle:UITableViewCellStyleDefault
     reuseIdentifier:nil];

    cell.textLabel.text = @"语音工具";
    cell.textLabel.textColor = [UIColor systemBlueColor];

    cell.accessoryType =
    UITableViewCellAccessoryDisclosureIndicator;

    // 保存到 controller associated object
    objc_setAssociatedObject(
        controller,
        "HBVoiceToolCell",
        cell,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
}


#pragma mark - Swizzle viewDidAppear

static void HBOriginalViewDidAppear(
    UIViewController *self,
    SEL _cmd,
    BOOL animated)
{
    [self HB_original_viewDidAppear:animated];

    if ([self isKindOfClass:
         NSClassFromString(@"NewSettingViewController")]) {

        HBAddVoiceToolEntry(self);
    }
}

@interface UIViewController (HBVoiceHook)

- (void)HB_original_viewDidAppear:(BOOL)animated;

@end


@implementation UIViewController (HBVoiceHook)

- (void)HB_original_viewDidAppear:(BOOL)animated
{
    // 占位方法。
    // 实际实现由 runtime exchange 完成。
}

@end


#pragma mark - More Stable Hook

static void HBHookViewDidAppear(void)
{
    Class cls =
    NSClassFromString(@"NewSettingViewController");

    if (!cls) {
        NSLog(@"[HBVoice] NewSettingViewController not found");
        return;
    }

    SEL originalSEL =
    @selector(viewDidAppear:);

    SEL swizzledSEL =
    @selector(HB_viewDidAppear:);

    Method originalMethod =
    class_getInstanceMethod(cls, originalSEL);

    Method swizzledMethod =
    class_getInstanceMethod([UIViewController class],
                            @selector(HB_viewDidAppear:));

    if (!originalMethod || !swizzledMethod) {
        NSLog(@"[HBVoice] viewDidAppear hook failed");
        return;
    }

    method_exchangeImplementations(
        originalMethod,
        swizzledMethod
    );

    NSLog(@"[HBVoice] NewSettingViewController hooked");
}


#pragma mark - Actual Hook Category

@interface NewSettingViewController : UIViewController
@end


@implementation NewSettingViewController (HBVoiceActualHook)

- (void)HB_viewDidAppear:(BOOL)animated
{
    [self HB_viewDidAppear:animated];

    dispatch_after(
        dispatch_time(
            DISPATCH_TIME_NOW,
            (int64_t)(0.5 * NSEC_PER_SEC)
        ),
        dispatch_get_main_queue(),
        ^{

            [self HBInstallVoiceButton];
        }
    );
}

- (void)HBInstallVoiceButton
{
    // 如果已经存在就不重复安装
    if ([self.view viewWithTag:884233]) {
        return;
    }

    UIButton *button =
    [UIButton buttonWithType:UIButtonTypeSystem];

    button.tag = 884233;

    CGFloat width =
    self.view.bounds.size.width;

    button.frame =
    CGRectMake(20,
               self.view.bounds.size.height - 90,
               width - 40,
               48);

    button.backgroundColor =
    [UIColor secondarySystemBackgroundColor];

    button.layer.cornerRadius = 10;

    [button setTitle:@"🎙 语音工具"
            forState:UIControlStateNormal];

    button.titleLabel.font =
    [UIFont systemFontOfSize:16];

    [button addTarget:self
               action:@selector(HBOpenVoiceTool)
     forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:button];
}

- (void)HBOpenVoiceTool
{
    HBVoiceToolViewController *vc =
    [[HBVoiceToolViewController alloc] initWithStyle:
     UITableViewStyleInsetGrouped];

    UINavigationController *nav =
    [[UINavigationController alloc]
     initWithRootViewController:vc];

    [self presentViewController:nav
                       animated:YES
                     completion:nil];
}

@end


#pragma mark - Constructor

__attribute__((constructor))
static void HBVoicePluginInit(void)
{
    NSLog(@"=================================");
    NSLog(@"[HBVoice] Plugin V2.2 START");
    NSLog(@"[HBVoice] SiliconFlow TTS enabled");
    NSLog(@"=================================");

    dispatch_async(dispatch_get_main_queue(), ^{

        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                (int64_t)(2.0 * NSEC_PER_SEC)
            ),
            dispatch_get_main_queue(),
            ^{

                Class settingClass =
                NSClassFromString(@"NewSettingViewController");

                if (settingClass) {

                    Method original =
                    class_getInstanceMethod(
                        settingClass,
                        @selector(viewDidAppear:)
                    );

                    Method replacement =
                    class_getInstanceMethod(
                        settingClass,
                        @selector(HB_viewDidAppear:)
                    );

                    if (original && replacement) {

                        method_exchangeImplementations(
                            original,
                            replacement
                        );

                        NSLog(@"[HBVoice] Setting hook installed");

                    } else {

                        NSLog(@"[HBVoice] Method not found");
                    }

                } else {

                    NSLog(@"[HBVoice] NewSettingViewController not found");
                }
            }
        );
    });
}
