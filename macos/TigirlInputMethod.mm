#import <InputMethodKit/InputMethodKit.h>
#import <Carbon/Carbon.h>
#include <cstring>
#include <filesystem>
#include "Dictionary.h"
#include "TigirlSentence.hpp"

@interface TigirlInputController : IMKInputController
@end

static OSStatus enableTigirlMode(bool selectIt) {
    CFArrayRef sources = TISCreateInputSourceList(nullptr, true);
    if (!sources) return paramErr;
    OSStatus result = fnfErr;
    CFStringRef wanted = CFSTR("com.viui.inputmethod.Tigirl.Hans");
    for (CFIndex i = 0; i < CFArrayGetCount(sources); ++i) {
        TISInputSourceRef source = (TISInputSourceRef)CFArrayGetValueAtIndex(sources, i);
        CFStringRef sourceID = (CFStringRef)TISGetInputSourceProperty(source, kTISPropertyInputSourceID);
        if (sourceID && CFEqual(sourceID, wanted)) {
            result = TISEnableInputSource(source);
            if (result == noErr && selectIt) result = TISSelectInputSource(source);
            break;
        }
    }
    CFRelease(sources);
    return result;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc > 1 && strcmp(argv[1], "--register-input-source") == 0) {
            NSURL *bundleURL = [NSBundle mainBundle].bundleURL;
            OSStatus status = TISRegisterInputSource((__bridge CFURLRef)bundleURL);
            NSLog(@"Tigirl TISRegisterInputSource: %@ (%@)", status == noErr ? @"success" : @"failure", bundleURL.path);
            return status == noErr ? 0 : 1;
        }
        if (argc > 1 && strcmp(argv[1], "--enable-input-source") == 0) {
            OSStatus status = enableTigirlMode(argc > 2 && strcmp(argv[2], "--select") == 0);
            NSLog(@"Tigirl enable input source: %@", status == noErr ? @"success" : @"failure");
            return status == noErr ? 0 : 1;
        }
        NSApplication *app = [NSApplication sharedApplication];
        NSString *connection = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"InputMethodConnectionName"];
        IMKServer *server = [[IMKServer alloc] initWithName:connection
                                           bundleIdentifier:[[NSBundle mainBundle] bundleIdentifier]];
        (void)server;
        // Create the IMK server first so the input method is reachable as early
        // as possible; warm the 42 MB dictionary mapping afterwards.
        @autoreleasepool {
            NSString *warm = [[NSBundle mainBundle] pathForResource:@"tiger-v2" ofType:@"tcd"];
            if (warm.length) {
                try { tiger::Dictionary::Open(std::filesystem::path(warm.UTF8String)); } catch (...) {}
            }
        }
        [app run];
    }
    return 0;
}
