#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <stdarg.h>

static void VTLog(NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    NSLog(@"[VoiceTrace] %@", msg);
}

static void VTSwizzle(Class cls, SEL original, SEL replacement) {
    Method a = class_getInstanceMethod(cls, original);
    Method b = class_getInstanceMethod(cls, replacement);

    if (!a || !b) {
        VTLog(@"HOOK FAILED: %@ %@", NSStringFromClass(cls),
              NSStringFromSelector(original));
        return;
    }

    method_exchangeImplementations(a, b);

    VTLog(@"HOOK OK: %@ %@", NSStringFromClass(cls),
          NSStringFromSelector(original));
}

#pragma mark - NSURLSession

@interface NSURLSession (VoiceTrace)

- (NSURLSessionDataTask *)vt_dataTaskWithRequest:(NSURLRequest *)request
                               completionHandler:(void (^)(NSData *,
                                                           NSURLResponse *,
                                                           NSError *))completionHandler;

- (NSURLSessionDownloadTask *)vt_downloadTaskWithRequest:(NSURLRequest *)request
                                       completionHandler:(void (^)(NSURL *,
                                                                   NSURLResponse *,
                                                                   NSError *))completionHandler;

@end

@implementation NSURLSession (VoiceTrace)

- (NSURLSessionDataTask *)vt_dataTaskWithRequest:(NSURLRequest *)request
                               completionHandler:(void (^)(NSData *,
                                                           NSURLResponse *,
                                                           NSError *))completionHandler {

    VTLog(@"DATA URL = %@", request.URL.absoluteString ?: @"<nil>");
    VTLog(@"METHOD = %@", request.HTTPMethod ?: @"GET");

    if (request.HTTPBody.length > 0) {
        VTLog(@"BODY LENGTH = %lu",
              (unsigned long)request.HTTPBody.length);
    }

    if (request.allHTTPHeaderFields.count > 0) {
        VTLog(@"HEADER NAMES = %@",
              request.allHTTPHeaderFields.allKeys);
    }

    void (^wrapped)(NSData *, NSURLResponse *, NSError *) =
    ^(NSData *data, NSURLResponse *response, NSError *error) {

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {

            NSHTTPURLResponse *http =
                (NSHTTPURLResponse *)response;

            VTLog(@"RESPONSE = %ld",
                  (long)http.statusCode);

            VTLog(@"RESPONSE URL = %@",
                  response.URL.absoluteString ?: @"<nil>");

            VTLog(@"RESPONSE BYTES = %lu",
                  (unsigned long)data.length);
        }

        if (error) {
            VTLog(@"ERROR = %@", error.localizedDescription);
        }

        if (completionHandler) {
            completionHandler(data, response, error);
        }
    };

    return [self vt_dataTaskWithRequest:request
                      completionHandler:wrapped];
}

- (NSURLSessionDownloadTask *)vt_downloadTaskWithRequest:(NSURLRequest *)request
                                       completionHandler:(void (^)(NSURL *,
                                                                   NSURLResponse *,
                                                                   NSError *))completionHandler {

    VTLog(@"DOWNLOAD URL = %@",
          request.URL.absoluteString ?: @"<nil>");

    VTLog(@"METHOD = %@",
          request.HTTPMethod ?: @"GET");

    if (request.HTTPBody.length > 0) {
        VTLog(@"BODY LENGTH = %lu",
              (unsigned long)request.HTTPBody.length);
    }

    void (^wrapped)(NSURL *, NSURLResponse *, NSError *) =
    ^(NSURL *location, NSURLResponse *response, NSError *error) {

        if ([response isKindOfClass:[NSHTTPURLResponse class]]) {

            NSHTTPURLResponse *http =
                (NSHTTPURLResponse *)response;

            VTLog(@"DOWNLOAD RESPONSE = %ld",
                  (long)http.statusCode);

            VTLog(@"DOWNLOAD URL = %@",
                  response.URL.absoluteString ?: @"<nil>");
        }

        VTLog(@"TEMP FILE = %@",
              location.path ?: @"<nil>");

        if (error) {
            VTLog(@"DOWNLOAD ERROR = %@",
                  error.localizedDescription);
        }

        if (completionHandler) {
            completionHandler(location, response, error);
        }
    };

    return [self vt_downloadTaskWithRequest:request
                           completionHandler:wrapped];
}

@end

#pragma mark - File tracing

@interface NSFileManager (VoiceTrace)

- (BOOL)vt_fileExistsAtPath:(NSString *)path;

@end

@implementation NSFileManager (VoiceTrace)

- (BOOL)vt_fileExistsAtPath:(NSString *)path {

    BOOL result = [self vt_fileExistsAtPath:path];

    NSString *p = path.lowercaseString;

    if ([p containsString:@"voice"] ||
        [p containsString:@"model"] ||
        [p containsString:@"silk"] ||
        [p containsString:@"pcm"] ||
        [p containsString:@"senhang"] ||
        [p containsString:@"ovmodel"]) {

        VTLog(@"FILE CHECK = %@ => %@",
              path,
              result ? @"YES" : @"NO");
    }

    return result;
}

@end

#pragma mark - Constructor

__attribute__((constructor))
static void VoiceTraceLoaded(void) {

    @autoreleasepool {

        VTLog(@"==============================");
        VTLog(@"VoiceTrace loaded");
        VTLog(@"==============================");

        VTSwizzle([NSURLSession class],
                  @selector(dataTaskWithRequest:completionHandler:),
                  @selector(vt_dataTaskWithRequest:completionHandler:));

        VTSwizzle([NSURLSession class],
                  @selector(downloadTaskWithRequest:completionHandler:),
                  @selector(vt_downloadTaskWithRequest:completionHandler:));

        VTSwizzle([NSFileManager class],
                  @selector(fileExistsAtPath:),
                  @selector(vt_fileExistsAtPath:));

        VTLog(@"VoiceTrace READY");
    }
}
