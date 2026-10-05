#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <mach-o/loader.h>
#import <mach/mach.h>

static void ScanOpenVoiceImages(void) {
    NSMutableString *result = [NSMutableString string];

    uint32_t count = _dyld_image_count();

    [result appendFormat:@"扫描 Mach-O 镜像：%u 个\n\n", count];

    int found = 0;

    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;

        const struct mach_header_64 *header =
            (const struct mach_header_64 *)_dyld_get_image_header(i);

        if (!header || header->magic != MH_MAGIC_64)
            continue;

        const struct section_64 *section =
            getsectbynamefromheader_64(header, "__DATA", "__ovmodel");

        if (!section) {
            section =
                getsectbynamefromheader_64(header, "__TEXT", "__ovmodel");
        }

        if (!section) {
            section =
                getsectbynamefromheader_64(header, "__DATA_CONST", "__ovmodel");
        }

        if (section) {
            found++;

            [result appendFormat:
                @"🔥 找到 __ovmodel\n"
                 @"镜像：%s\n"
                 @"地址：0x%llx\n"
                 @"大小：%llu bytes\n\n",
                name,
                section->addr,
                section->size];
        }
    }

    if (found == 0) {
        [result appendString:@"❌ 当前没有发现 __ovmodel\n\n"];
    } else {
        [result appendFormat:@"\n✅ 共发现 %d 个 __ovmodel\n", found];
    }

    // 检查预期模型缓存目录
    NSString *cache =
        [NSHomeDirectory() stringByAppendingPathComponent:
         @"Library/Caches/SenHangVoiceModels"];

    [result appendFormat:
        @"\n模型缓存目录：\n%@\n",
        cache];

    NSFileManager *fm = [NSFileManager defaultManager];

    BOOL isDir = NO;
    BOOL exists = [fm fileExistsAtPath:cache isDirectory:&isDir];

    if (!exists) {
        [result appendString:@"❌ 缓存目录不存在\n"];
    } else {
        [result appendFormat:@"✅ 缓存目录存在（目录=%@）\n",
         isDir ? @"YES" : @"NO"];

        NSArray *items = [fm contentsOfDirectoryAtPath:cache error:nil];

        [result appendFormat:@"项目数量：%lu\n",
         (unsigned long)items.count];

        for (NSString *item in items) {
            [result appendFormat:@"  %@\n", item];
        }
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert =
            [UIAlertController alertControllerWithTitle:@"OpenVoice 模型扫描"
                                                message:result
                                         preferredStyle:UIAlertControllerStyleAlert];

        [alert addAction:
            [UIAlertAction actionWithTitle:@"复制结果"
                                     style:UIAlertActionStyleDefault
                                   handler:^(UIAlertAction *action) {
            UIPasteboard.generalPasteboard.string = result;
        }]];

        [alert addAction:
            [UIAlertAction actionWithTitle:@"关闭"
                                     style:UIAlertActionStyleCancel
                                   handler:nil]];

        UIViewController *vc = UIApplication.sharedApplication.keyWindow.rootViewController;

        while (vc.presentedViewController)
            vc = vc.presentedViewController;

        [vc presentViewController:alert animated:YES completion:nil];
    });
}

__attribute__((constructor))
static void VoiceScanInit(void) {
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
            ScanOpenVoiceImages();
        }
    );
}
