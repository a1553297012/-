#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <Security/Security.h>
#import <objc/runtime.h>

#pragma mark - Keychain

@interface HBKeychain : NSObject
+ (BOOL)saveAPIKey:(NSString *)key;
+ (NSString *)loadAPIKey;
+ (BOOL)deleteAPIKey;
@end

@implementation HBKeychain

+ (NSString *)service {
    return @"com.hb.voiceplugin.siliconflow";
}

+ (NSString *)account {
    return @"api_key";
}

+ (BOOL)saveAPIKey:(NSString *)key {
    if (!key || key.length == 0) {
        return NO;
    }

    NSData *data = [key dataUsingEncoding:NSUTF8StringEncoding];

    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: [self service],
        (__bridge id)kSecAttrAccount: [self account]
    };

    SecItemDelete((__bridge CFDictionaryRef)query);

    NSMutableDictionary *item = [query mutableCopy];
    item[(__bridge id)kSecValueData] = data;

    OSStatus status = SecItemAdd(
        (__bridge CFDictionaryRef)item,
        NULL
    );

    return status == errSecSuccess;
}

+ (NSString *)loadAPIKey {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: [self service],
        (__bridge id)kSecAttrAccount: [self account],
        (__bridge id)kSecReturnData: @YES,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
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

    return [[NSString alloc] initWithData:data
                                encoding:NSUTF8StringEncoding];
}

+ (BOOL)deleteAPIKey {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: [self service],
        (__bridge id)kSecAttrAccount: [self account]
    };

    OSStatus status = SecItemDelete(
        (__bridge CFDictionaryRef)query
    );

    return status == errSecSuccess ||
           status == errSecItemNotFound;
}

@end


#pragma mark - SiliconFlow TTS

@interface HBSiliconFlowTTS : NSObject

+ (void)synthesizeText:(NSString *)text
                apiKey:(NSString *)apiKey
                 voice:(NSString *)voice
                 speed:(float)speed
                  gain:(float)gain
            completion:(void (^)(NSData *audioData,
                                 NSError *error))completion;

@end

@implementation HBSiliconFlowTTS

+ (void)synthesizeText:(NSString *)text
                apiKey:(NSString *)apiKey
                 voice:(NSString *)voice
                 speed:(float)speed
                  gain:(float)gain
            completion:(void (^)(NSData *audioData,
                                 NSError *error))completion {

    if (!text || text.length == 0) {
        NSError *error = [NSError errorWithDomain:@"HBVoicePlugin"
                                             code:1001
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"请输入文字"
        }];

        if (completion) {
            completion(nil, error);
        }

        return;
    }

    if (!apiKey || apiKey.length == 0) {
        NSError *error = [NSError errorWithDomain:@"HBVoicePlugin"
                                             code:1002
                                         userInfo:@{
            NSLocalizedDescriptionKey: @"还没有设置 SiliconFlow API Key"
        }];

        if (completion) {
            completion(nil, error);
        }

        return;
    }

    if (!voice || voice.length == 0) {
        voice = @"fnlp/MOSS-TTSD-v0.5:alex";
    }

    if (speed < 0.25) {
        speed = 0.25;
    }

    if (speed > 4.0) {
        speed = 4.0;
    }

    if (gain < -10.0) {
        gain = -10.0;
    }

    if (gain > 10.0) {
        gain = 10.0;
    }

    NSURL *url = [NSURL URLWithString:
                  @"https://api.siliconflow.cn/v1/audio/speech"];

    NSMutableURLRequest *request =
        [NSMutableURLRequest requestWithURL:url];

    request.HTTPMethod = @"POST";

    [request setValue:
        [NSString stringWithFormat:@"Bearer %@", apiKey]
        forHTTPHeaderField:@"Authorization"];

    [request setValue:@"application/json"
   forHTTPHeaderField:@"Content-Type"];

    NSDictionary *body = @{
        @"model": @"fnlp/MOSS-TTSD-v0.5",
        @"input": text,
        @"voice": voice,
        @"response_format": @"mp3",
        @"speed": @(speed),
        @"gain": @(gain)
    };

    NSError *jsonError = nil;

    NSData *jsonData =
        [NSJSONSerialization dataWithJSONObject:body
                                        options:0
                                          error:&jsonError];

    if (jsonError) {
        if (completion) {
            completion(nil, jsonError);
        }
        return;
    }

    request.HTTPBody = jsonData;

    NSURLSessionConfiguration *configuration =
        [NSURLSessionConfiguration defaultSessionConfiguration];

    NSURLSession *session =
        [NSURLSession sessionWithConfiguration:configuration];

    NSURLSessionDataTask *task =
        [session dataTaskWithRequest:request
                   completionHandler:
         ^(NSData *data,
           NSURLResponse *response,
           NSError *error) {

        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, error);
                }
            });

            return;
        }

        NSHTTPURLResponse *httpResponse =
            (NSHTTPURLResponse *)response;

        NSInteger statusCode = httpResponse.statusCode;

        if (statusCode != 200) {

            NSString *message = nil;

            if (data.length > 0) {
                id json =
                    [NSJSONSerialization JSONObjectWithData:data
                                                    options:0
                                                      error:nil];

                if ([json isKindOfClass:[NSDictionary class]]) {

                    message = json[@"message"];

                    if (!message) {
                        id dataMessage = json[@"data"];

                        if ([dataMessage isKindOfClass:
                             [NSString class]]) {
                            message = dataMessage;
                        }
                    }
                }

                if (!message) {
                    message =
                        [[NSString alloc]
                         initWithData:data
                         encoding:NSUTF8StringEncoding];
                }
            }

            if (!message || message.length == 0) {
                message =
                    [NSString stringWithFormat:
                     @"服务器返回 HTTP %ld",
                     (long)statusCode];
            }

            NSError *serverError =
                [NSError errorWithDomain:@"SiliconFlow"
                                    code:statusCode
                                userInfo:@{
                NSLocalizedDescriptionKey: message
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, serverError);
                }
            });

            return;
        }

        if (!data || data.length == 0) {

            NSError *emptyError =
                [NSError errorWithDomain:@"SiliconFlow"
                                    code:1003
                                userInfo:@{
                NSLocalizedDescriptionKey:
                    @"服务器返回了空音频"
            }];

            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) {
                    completion(nil, emptyError);
                }
            });

            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            if (completion) {
                completion(data, nil);
            }
        });
    }];

    [task resume];
}

@end


#pragma mark - API Key ViewController

@interface HBVoiceAPIKeyViewController : UIViewController

@property (nonatomic, strong) UITextField *keyField;

@end

@implementation HBVoiceAPIKeyViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"SiliconFlow";

    self.view.backgroundColor =
        [UIColor groupTableViewBackgroundColor];

    UILabel *titleLabel =
        [[UILabel alloc] initWithFrame:
         CGRectMake(20, 30, 340, 30)];

    titleLabel.text = @"SiliconFlow API Key";
    titleLabel.font =
        [UIFont boldSystemFontOfSize:18];

    [self.view addSubview:titleLabel];

    UILabel *tip =
        [[UILabel alloc] initWithFrame:
         CGRectMake(20, 65, 340, 65)];

    tip.numberOfLines = 0;
    tip.font =
        [UIFont systemFontOfSize:13];

    tip.text =
        @"请输入你的 SiliconFlow API Key。\n"
         "Key 会保存到 iOS Keychain，不会写入源码。";

    [self.view addSubview:tip];

    self.keyField =
        [[UITextField alloc]
         initWithFrame:
         CGRectMake(20, 145, 340, 45)];

    self.keyField.borderStyle =
        UITextBorderStyleRoundedRect;

    self.keyField.placeholder =
        @"sk-xxxxxxxx";

    self.keyField.secureTextEntry = YES;

    NSString *oldKey =
        [HBKeychain loadAPIKey];

    if (oldKey.length > 0) {
        self.keyField.text = oldKey;
    }

    [self.view addSubview:self.keyField];

    UIButton *saveButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    saveButton.frame =
        CGRectMake(20, 210, 340, 45);

    [saveButton setTitle:@"保存 API Key"
                forState:UIControlStateNormal];

    saveButton.backgroundColor =
        [UIColor colorWithWhite:0.92 alpha:1.0];

    [saveButton addTarget:self
                   action:@selector(saveKey)
         forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:saveButton];

    UIButton *deleteButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    deleteButton.frame =
        CGRectMake(20, 270, 340, 45);

    [deleteButton setTitle:@"删除 API Key"
                  forState:UIControlStateNormal];

    [deleteButton addTarget:self
                     action:@selector(deleteKey)
           forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:deleteButton];
}

- (void)saveKey {

    NSString *key =
        [self.keyField.text
         stringByTrimmingCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (key.length == 0) {
        [self showMessage:@"请输入 API Key"];
        return;
    }

    BOOL success =
        [HBKeychain saveAPIKey:key];

    if (success) {
        [self showMessage:@"API Key 已保存"];
    } else {
        [self showMessage:@"保存失败"];
    }
}

- (void)deleteKey {

    [HBKeychain deleteAPIKey];

    self.keyField.text = @"";

    [self showMessage:@"API Key 已删除"];
}

- (void)showMessage:(NSString *)message {

    UIAlertController *alert =
        [UIAlertController
         alertControllerWithTitle:@"语音插件"
         message:message
         preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
     [UIAlertAction
      actionWithTitle:@"确定"
      style:UIAlertActionStyleDefault
      handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

@end


#pragma mark - Voice Text To Speech

@interface HBVoiceTextToSpeechViewController : UIViewController

@property (nonatomic, strong) UITextView *textView;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UISlider *gainSlider;
@property (nonatomic, strong) UILabel *speedLabel;
@property (nonatomic, strong) UILabel *gainLabel;
@property (nonatomic, strong) UIButton *generateButton;
@property (nonatomic, strong) UIButton *stopButton;

@property (nonatomic, strong) AVAudioPlayer *audioPlayer;

@end

@implementation HBVoiceTextToSpeechViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"文本转语音";

    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.extendedLayoutIncludesOpaqueBars = NO;

    self.view.backgroundColor =
        [UIColor groupTableViewBackgroundColor];

    UILabel *inputLabel =
        [[UILabel alloc]
         initWithFrame:CGRectMake(20, 15, 340, 30)];

    inputLabel.text = @"输入文字";
    inputLabel.font =
        [UIFont boldSystemFontOfSize:17];

    [self.view addSubview:inputLabel];

    self.textView =
        [[UITextView alloc]
         initWithFrame:CGRectMake(20, 50, 340, 150)];

    self.textView.backgroundColor =
        [UIColor whiteColor];

    self.textView.layer.cornerRadius = 8;

    self.textView.font =
        [UIFont systemFontOfSize:16];

    self.textView.text =
        @"你好，这是 SiliconFlow 语音测试。";

    [self.view addSubview:self.textView];

    UILabel *voiceLabel =
        [[UILabel alloc]
         initWithFrame:CGRectMake(20, 215, 340, 30)];

    voiceLabel.text =
        @"音色：alex";

    voiceLabel.font =
        [UIFont systemFontOfSize:15];

    [self.view addSubview:voiceLabel];

    self.speedLabel =
        [[UILabel alloc]
         initWithFrame:CGRectMake(20, 255, 100, 30)];

    self.speedLabel.text = @"倍速：1.0";

    [self.view addSubview:self.speedLabel];

    self.speedSlider =
        [[UISlider alloc]
         initWithFrame:CGRectMake(115, 255, 245, 30)];

    self.speedSlider.minimumValue = 0.25;
    self.speedSlider.maximumValue = 4.0;
    self.speedSlider.value = 1.0;

    [self.speedSlider addTarget:self
                         action:@selector(speedChanged:)
               forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.speedSlider];

    self.gainLabel =
        [[UILabel alloc]
         initWithFrame:CGRectMake(20, 300, 100, 30)];

    self.gainLabel.text = @"音量：0 dB";

    [self.view addSubview:self.gainLabel];

    self.gainSlider =
        [[UISlider alloc]
         initWithFrame:CGRectMake(115, 300, 245, 30)];

    self.gainSlider.minimumValue = -10.0;
    self.gainSlider.maximumValue = 10.0;
    self.gainSlider.value = 0.0;

    [self.gainSlider addTarget:self
                        action:@selector(gainChanged:)
              forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.gainSlider];

    self.generateButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.generateButton.frame =
        CGRectMake(20, 350, 165, 50);

    [self.generateButton
     setTitle:@"生成语音"
     forState:UIControlStateNormal];

    self.generateButton.backgroundColor =
        [UIColor colorWithWhite:0.90 alpha:1.0];

    self.generateButton.layer.cornerRadius = 8;

    [self.generateButton addTarget:self
                            action:@selector(generateVoice)
                  forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.generateButton];

    self.stopButton =
        [UIButton buttonWithType:UIButtonTypeSystem];

    self.stopButton.frame =
        CGRectMake(195, 350, 165, 50);

    [self.stopButton
     setTitle:@"停止播放"
     forState:UIControlStateNormal];

    self.stopButton.backgroundColor =
        [UIColor colorWithWhite:0.90 alpha:1.0];

    self.stopButton.layer.cornerRadius = 8;

    [self.stopButton addTarget:self
                        action:@selector(stopVoice)
              forControlEvents:UIControlEventTouchUpInside];

    [self.view addSubview:self.stopButton];
}

- (void)speedChanged:(UISlider *)slider {

    float value =
        roundf(slider.value * 4.0) / 4.0;

    slider.value = value;

    self.speedLabel.text =
        [NSString stringWithFormat:@"倍速：%.2f", value];
}

- (void)gainChanged:(UISlider *)slider {

    float value =
        roundf(slider.value);

    slider.value = value;

    self.gainLabel.text =
        [NSString stringWithFormat:@"音量：%.0f dB", value];
}

- (void)generateVoice {

    NSString *text =
        [self.textView.text
         stringByTrimmingCharactersInSet:
         [NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (text.length == 0) {
        [self showMessage:@"请输入文字"];
        return;
    }

    NSString *apiKey =
        [HBKeychain loadAPIKey];

    if (apiKey.length == 0) {

        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:@"还没有 API Key"
             message:@"请先设置 SiliconFlow API Key"
             preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"设置"
          style:UIAlertActionStyleDefault
          handler:^(UIAlertAction *action) {

            HBVoiceAPIKeyViewController *vc =
                [[HBVoiceAPIKeyViewController alloc]
                 init];

            [self.navigationController
             pushViewController:vc
             animated:YES];
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

    self.generateButton.enabled = NO;

    [self.generateButton
     setTitle:@"生成中..."
     forState:UIControlStateNormal];

    float speed = self.speedSlider.value;
    float gain = self.gainSlider.value;

    __weak typeof(self) weakSelf = self;

    [HBSiliconFlowTTS
     synthesizeText:text
     apiKey:apiKey
     voice:@"fnlp/MOSS-TTSD-v0.5:alex"
     speed:speed
     gain:gain
     completion:^(NSData *audioData,
                  NSError *error) {

        __strong typeof(weakSelf) strongSelf = weakSelf;

        if (!strongSelf) {
            return;
        }

        strongSelf.generateButton.enabled = YES;

        [strongSelf.generateButton
         setTitle:@"生成语音"
         forState:UIControlStateNormal];

        if (error) {

            NSString *message =
                error.localizedDescription;

            [strongSelf showMessage:
             [NSString stringWithFormat:
              @"生成失败：\n%@", message]];

            return;
        }

        NSError *audioError = nil;

        strongSelf.audioPlayer =
            [[AVAudioPlayer alloc]
             initWithData:audioData
             error:&audioError];

        if (audioError ||
            !strongSelf.audioPlayer) {

            [strongSelf showMessage:
             [NSString stringWithFormat:
              @"音频播放失败：\n%@",
              audioError.localizedDescription]];

            return;
        }

        [strongSelf.audioPlayer prepareToPlay];

        BOOL played =
            [strongSelf.audioPlayer play];

        if (!played) {
            [strongSelf showMessage:@"播放失败"];
        }
    }];
}

- (void)stopVoice {

    if (self.audioPlayer.playing) {
        [self.audioPlayer stop];
    }
}

- (void)showMessage:(NSString *)message {

    UIAlertController *alert =
        [UIAlertController
         alertControllerWithTitle:@"语音插件"
         message:message
         preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:
     [UIAlertAction
      actionWithTitle:@"确定"
      style:UIAlertActionStyleDefault
      handler:nil]];

    [self presentViewController:alert
                       animated:YES
                     completion:nil];
}

@end


#pragma mark - Voice Tool

@interface HBVoiceToolViewController : UITableViewController
@end

@implementation HBVoiceToolViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = @"语音工具";

    self.tableView =
        [[UITableView alloc]
         initWithFrame:CGRectZero
         style:UITableViewStyleGrouped];

    [self.tableView registerClass:
     [UITableViewCell class]
     forCellReuseIdentifier:@"Cell"];
}

- (NSInteger)numberOfSectionsInTableView:
    (UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section {

    if (section == 0) {
        return 1;
    }

    return 2;
}

- (NSString *)tableView:(UITableView *)tableView
 titleForHeaderInSection:(NSInteger)section {

    if (section == 0) {
        return @"语音生成";
    }

    return @"设置";
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:
         (NSIndexPath *)indexPath {

    UITableViewCell *cell =
        [tableView dequeueReusableCellWithIdentifier:@"Cell"
                                        forIndexPath:indexPath];

    cell.accessoryType =
        UITableViewCellAccessoryDisclosureIndicator;

    if (indexPath.section == 0) {

        cell.textLabel.text =
            @"文本转语音";

    } else if (indexPath.row == 0) {

        cell.textLabel.text =
            @"SiliconFlow API Key";

    } else {

        cell.textLabel.text =
            @"音频文件";
    }

    return cell;
}

- (void)tableView:(UITableView *)tableView
 didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];

    if (indexPath.section == 0) {

        HBVoiceTextToSpeechViewController *vc =
            [[HBVoiceTextToSpeechViewController alloc]
             init];

        [self.navigationController
         pushViewController:vc
         animated:YES];

        return;
    }

    if (indexPath.section == 1 &&
        indexPath.row == 0) {

        HBVoiceAPIKeyViewController *vc =
            [[HBVoiceAPIKeyViewController alloc]
             init];

        [self.navigationController
         pushViewController:vc
         animated:YES];

        return;
    }

    if (indexPath.section == 1 &&
        indexPath.row == 1) {

        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:@"音频文件"
             message:@"这个功能下一版加入"
             preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
         [UIAlertAction
          actionWithTitle:@"确定"
          style:UIAlertActionStyleDefault
          handler:nil]];

        [self presentViewController:alert
                           animated:YES
                         completion:nil];
    }
}

@end


#pragma mark - WeChat Setting Hook

static IMP HBOriginalViewDidAppearIMP = NULL;

static void HBOpenVoiceTool(id self, SEL _cmd) {

    UIViewController *vc =
        (UIViewController *)self;

    HBVoiceToolViewController *toolVC =
        [[HBVoiceToolViewController alloc]
         initWithStyle:UITableViewStyleGrouped];

    UINavigationController *nav =
        [[UINavigationController alloc]
         initWithRootViewController:toolVC];

    [vc presentViewController:nav
                     animated:YES
                   completion:nil];
}


static void HBVoiceViewDidAppear(id self,
                                 SEL _cmd,
                                 BOOL animated) {

    if (HBOriginalViewDidAppearIMP) {

        ((void (*)(id, SEL, BOOL))
         HBOriginalViewDidAppearIMP)
        (self, _cmd, animated);
    }

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW,
                      (int64_t)(0.3 * NSEC_PER_SEC)),
        dispatch_get_main_queue(),
        ^{

        UIViewController *vc =
            (UIViewController *)self;

        if (!vc.view) {
            return;
        }

        UIView *oldButton =
            [vc.view viewWithTag:884233];

        if (oldButton) {
            return;
        }

        UIButton *button =
            [UIButton buttonWithType:UIButtonTypeSystem];

        button.tag = 884233;

        button.frame =
            CGRectMake(20,
                       vc.view.bounds.size.height - 60,
                       vc.view.bounds.size.width - 40,
                       44);

        button.autoresizingMask =
            UIViewAutoresizingFlexibleWidth |
            UIViewAutoresizingFlexibleTopMargin;

        [button setTitle:@"🎙️ 语音工具"
                forState:UIControlStateNormal];

        button.backgroundColor =
            [UIColor colorWithWhite:0.94 alpha:1.0];

        button.layer.cornerRadius = 8;

        [button addTarget:vc
                   action:@selector(HBOpenVoiceTool)
         forControlEvents:UIControlEventTouchUpInside];

        [vc.view addSubview:button];
    });
}


static void HBInstallSettingHook(void) {

    Class cls =
        NSClassFromString(@"NewSettingViewController");

    if (!cls) {

        NSLog(@"[HBVoicePlugin] NewSettingViewController not found");

        return;
    }

    SEL originalSEL =
        @selector(viewDidAppear:);

    SEL replacementSEL =
        @selector(HBVoice_viewDidAppear:);

    Method originalMethod =
        class_getInstanceMethod(cls, originalSEL);

    if (!originalMethod) {

        NSLog(@"[HBVoicePlugin] viewDidAppear not found");

        return;
    }

    BOOL added =
        class_addMethod(
            cls,
            replacementSEL,
            (IMP)HBVoiceViewDidAppear,
            "v@:B"
        );

    if (!added) {

        NSLog(@"[HBVoicePlugin] replacement method already exists");
    }

    class_addMethod(
        cls,
        @selector(HBOpenVoiceTool),
        (IMP)HBOpenVoiceTool,
        "v@:"
    );

    HBOriginalViewDidAppearIMP =
        method_getImplementation(originalMethod);

    Method replacementMethod =
        class_getInstanceMethod(
            cls,
            replacementSEL
        );

    if (!replacementMethod) {

        NSLog(@"[HBVoicePlugin] replacementMethod missing");

        return;
    }

    method_exchangeImplementations(
        originalMethod,
        replacementMethod
    );

    NSLog(@"[HBVoicePlugin] Setting hook installed");
}


#pragma mark - Constructor

__attribute__((constructor))
static void HBVoicePluginInit(void) {

    NSLog(@"================================");
    NSLog(@"[HBVoicePlugin] V2.3 START");
    NSLog(@"[HBVoicePlugin] Process = %@",
          [[NSProcessInfo processInfo] processName]);
    NSLog(@"================================");

    dispatch_async(
        dispatch_get_main_queue(),
        ^{

        dispatch_after(
            dispatch_time(DISPATCH_TIME_NOW,
                          (int64_t)(2.0 * NSEC_PER_SEC)),
            dispatch_get_main_queue(),
            ^{

            HBInstallSettingHook();

        });
    });
}
