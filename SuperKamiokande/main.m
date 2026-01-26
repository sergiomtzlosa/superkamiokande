#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"

int main(int argc, const char *argv[])
{
    @autoreleasepool {
        NSApplication *app = [NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];

        SKOAppDelegate *delegate = [[SKOAppDelegate alloc] init];
        [app setDelegate:delegate];
        [app run];
    }
    return EXIT_SUCCESS;
}
