#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
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

    /*
     * 兼容旧版 iOS
     */
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

- (NSInteger)tableView:(UITableView *)tableView
 numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 3;
    }

    return 2;
}

- (NSString *)tableView:(UITableView *)tableView
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
        [tableView dequeueReusableCellWithIdentifier:identifier];

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
            cell.textLabel.text = @"文本转语音";
            cell.detailTextLabel.text =
                @"将文字转换成语音";
        }
        else if (indexPath.row == 1)
        {
            cell.textLabel.text = @"音频文件";
            cell.detailTextLabel.text =
                @"选择本地音频";
        }
        else
        {
            cell.textLabel.text = @"音色设置";
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

- (void)tableView:(UITableView *)tableView
didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];

    HBWriteLog(
        @"点击语音工具项目 section=%ld row=%ld",
        (long)indexPath.section,
        (long)indexPath.row
    );

    /*
     * 第一项暂时作为测试
     */
    if (indexPath.section == 0 &&
        indexPath.row == 0)
    {
        UIAlertController *alert =
            [UIAlertController
             alertControllerWithTitle:@"文本转语音"
             message:@"文本转语音功能将在下一步实现"
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
        class_getInstanceMethod(settingsClass,
                                viewDidLoadSEL);

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
                           action:@selector(HBVoiceToolButtonPressed:)
                 forControlEvents:UIControlEventTouchUpInside];

                [self.view addSubview:button];

                HBWriteLog(
                    @"已在设置页面添加【语音工具】按钮"
                );
            }
        );

    method_setImplementation(method, newIMP);

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
        HBWriteLog(@"========================================");
        HBWriteLog(@"HB VOICE PLUGIN START");
        HBWriteLog(@"VERSION = 1.0");
        HBWriteLog(@"PID = %d", getpid());

        HBWriteLog(
            @"PROCESS = %@",
            [[NSProcessInfo processInfo] processName]
        );

        HBWriteLog(@"========================================");

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
