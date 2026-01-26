#import <Cocoa/Cocoa.h>
#import "AppDelegate.h"
#import "ViewController.h"
#import "SKOHelpWindowController.h"

/// Application delegate: creates the main window (file's owner equivalent in
/// code) and hosts the split view with the 3D scene + control sidebar.
@interface SKOAppDelegate () <NSWindowDelegate>
@end

@implementation SKOAppDelegate
{
    NSWindow            *_window;
    ViewController      *_viewController;
}

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
    [NSApplication sharedApplication];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    NSRect frame = NSMakeRect(0, 0, 1440, 900);
    NSUInteger style = NSWindowStyleMaskTitled
                     | NSWindowStyleMaskClosable
                     | NSWindowStyleMaskMiniaturizable
                     | NSWindowStyleMaskResizable;

    _window = [[NSWindow alloc] initWithContentRect:frame
                                          styleMask:style
                                            backing:NSBackingStoreBuffered
                                               defer:NO];
    [_window setTitle:@"Super-Kamiokande — 3D Detector Explorer"];
    _window.delegate = self;
    // Six equal-width viewport controls need room beside the 304-point HUD.
    _window.minSize = NSMakeSize(1200, 700);
    [_window setFrameAutosaveName:@"SKOMainWindow"];
    [_window center];

    // Immersive dark chrome. The content still starts below the titlebar; the
    // title itself is hidden so the traffic lights sit on a clean black strip.
    _window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    _window.titlebarAppearsTransparent = YES;
    _window.titleVisibility = NSWindowTitleHidden;
    [_window setBackgroundColor:[NSColor blackColor]];
    [_window setOpaque:YES];
    [_window setHasShadow:YES];

    _viewController = [[ViewController alloc] init];
    _window.contentViewController = _viewController;

    NSDictionary<NSString *, NSString *> *environment =
        NSProcessInfo.processInfo.environment;
    if (environment[@"SKO_START_COLLAPSED"].boolValue) {
        [_viewController toggleSidebar:nil];
    }
    if (environment[@"SKO_START_LABELS_HIDDEN"].boolValue) {
        [_viewController toggleLabels:nil];
    }
    NSMenu *menu = [self makeMenu];
    NSApp.menu = menu;

    [_window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    if (environment[@"SKO_START_HELP"].boolValue) {
        [_viewController showHelp:nil];
    }

    [self scheduleSmokeTestIfRequested];
}

- (NSMenu *)makeMenu
{
    NSMenu *main = [[NSMenu alloc] init];
    NSMenuItem *appItem  = [[NSMenuItem alloc] init];
    NSMenuItem *editItem = [[NSMenuItem alloc] init];
    NSMenuItem *simItem  = [[NSMenuItem alloc] init];
    NSMenuItem *viewItem = [[NSMenuItem alloc] init];
    NSMenuItem *helpItem = [[NSMenuItem alloc] init];
    [main addItem:appItem];
    [main addItem:editItem];
    [main addItem:simItem];
    [main addItem:viewItem];
    [main addItem:helpItem];

    NSString *name = NSProcessInfo.processInfo.processName;
    NSMenu *appMenu = [[NSMenu alloc] initWithTitle:name];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"About %@", name]
                       action:@selector(orderFrontStandardAboutPanel:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Hide %@", name]
                       action:@selector(hide:)
                keyEquivalent:@"h"];
    NSMenuItem *hideOthers = [appMenu addItemWithTitle:@"Hide Others"
                                                action:@selector(hideOtherApplications:)
                                         keyEquivalent:@"h"];
    hideOthers.keyEquivalentModifierMask = NSEventModifierFlagOption | NSEventModifierFlagCommand;
    [appMenu addItemWithTitle:@"Show All"
                       action:@selector(unhideAllApplications:)
                keyEquivalent:@""];
    [appMenu addItem:[NSMenuItem separatorItem]];
    [appMenu addItemWithTitle:[NSString stringWithFormat:@"Quit %@", name]
                       action:@selector(terminate:)
                keyEquivalent:@"q"];
    appItem.title = name;
    appItem.submenu = appMenu;

    editItem.title = @"Edit";
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;

    // Simulation commands target the view controller directly so they work
    // regardless of which view has focus.
    NSMenu *simMenu = [[NSMenu alloc] initWithTitle:@"Simulation"];
    NSArray<NSArray<NSString *> *> *commands = @[
        @[@"Run / Pause",          @"toggleRun:",      @"p"],
        @[@"Reset event counter",  @"resetCounter:",   @"k"],
        @[@"Reset camera",         @"resetCamera:",    @"r"],
        @[@"Toggle cutaway",       @"toggleCutaway:",  @"t"],
        @[@"Toggle auto-rotate",   @"toggleRotate:",   @"a"],
        @[@"Toggle labels",        @"toggleLabels:",   @"l"],
        @[@"Toggle controls",      @"toggleSidebar:",  @"s"],
        @[@"Explode view",         @"toggleExplode:",  @"e"],
        @[@"Center model",         @"centerModel:",    @""],
    ];
    for (NSArray<NSString *> *command in commands) {
        NSMenuItem *item = [simMenu addItemWithTitle:command[0]
                                             action:NSSelectorFromString(command[1])
                                      keyEquivalent:command[2]];
        item.target = _viewController;
    }
    simItem.title = @"Simulation";
    simItem.submenu = simMenu;

    NSMenu *viewMenu = [[NSMenu alloc] initWithTitle:@"View"];
    NSMenuItem *fullScreen = [viewMenu addItemWithTitle:@"Toggle Full Screen"
                                                  action:@selector(toggleFullScreen:)
                                           keyEquivalent:@"f"];
    fullScreen.keyEquivalentModifierMask = NSEventModifierFlagControl | NSEventModifierFlagCommand;
    viewItem.title = @"View";
    viewItem.submenu = viewMenu;

    NSMenu *helpMenu = [[NSMenu alloc] initWithTitle:@"Help"];
    NSMenuItem *help = [helpMenu addItemWithTitle:@"Super-Kamiokande Help"
                                           action:@selector(showHelp:)
                                    keyEquivalent:@"?"];
    help.target = _viewController;
    helpItem.title = @"Help";
    helpItem.submenu = helpMenu;
    NSApp.helpMenu = helpMenu;
    return main;
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    return YES;
}

- (void)windowWillClose:(NSNotification *)notification
{
    [_viewController.helpWindowController close];
    _window = nil;
}

#pragma mark - Automated launch / screenshot support

- (void)scheduleSmokeTestIfRequested
{
    NSDictionary<NSString *, NSString *> *environment =
        NSProcessInfo.processInfo.environment;
    NSString *screenshotPath = environment[@"SKO_SCREENSHOT"];
    BOOL smokeTest = environment[@"SKO_SMOKE_TEST"].boolValue;
    if (screenshotPath.length == 0 && !smokeTest) return;

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (screenshotPath.length > 0) {
            [self saveWindowScreenshotToPath:screenshotPath];
        }
        if (smokeTest || screenshotPath.length > 0) {
            NSLog(@"SKO smoke: window=%@ scene=%@ sidebar=%@ labels=%@ sidebarVisible=%@ labelsVisible=%@ helpVisible=%@",
                  self->_window != nil ? @"yes" : @"no",
                  self->_viewController.sceneView != nil ? @"yes" : @"no",
                  self->_viewController.sidebar != nil ? @"yes" : @"no",
                  self->_viewController.labelsOverlay != nil ? @"yes" : @"no",
                  self->_viewController.sidebarVisible ? @"yes" : @"no",
                  self->_viewController.labelsVisible ? @"yes" : @"no",
                  self->_viewController.helpWindowController.window.isVisible ? @"yes" : @"no");
            [NSApp terminate:nil];
        }
    });
}

- (void)saveWindowScreenshotToPath:(NSString *)path
{
    NSView *content = _window.contentView;
    if (!content) return;

    // Help is pure AppKit, so its window can be captured directly as well.
    NSWindow *helpWindow = _viewController.helpWindowController.window;
    if (helpWindow.isVisible) {
        NSString *helpPath = [[path stringByDeletingPathExtension]
                              stringByAppendingString:@"-help.png"];
        NSView *helpContent = helpWindow.contentView;
        NSBitmapImageRep *helpBitmap =
            [helpContent bitmapImageRepForCachingDisplayInRect:helpContent.bounds];
        if (helpBitmap) {
            [helpContent cacheDisplayInRect:helpContent.bounds
                         toBitmapImageRep:helpBitmap];
            NSData *helpPNG = [helpBitmap representationUsingType:NSBitmapImageFileTypePNG
                                                       properties:@{}];
            if (helpPNG) {
                [helpPNG writeToFile:helpPath atomically:YES];
                NSLog(@"SKO help screenshot: %@", helpPath);
            }
        }
    }

    // The 3D layer is also exported on its own so the Metal scene can be checked
    // even if the window backing store refuses to composite it.
    NSString *scenePath = [path.stringByDeletingPathExtension
                           stringByAppendingString:@"-scene.png"];
    NSImage *sceneImage = [_viewController.sceneView snapshot];
    if (sceneImage) {
        NSBitmapImageRep *sceneRep =
            [NSBitmapImageRep imageRepWithData:sceneImage.TIFFRepresentation];
        NSData *scenePNG = [sceneRep representationUsingType:NSBitmapImageFileTypePNG
                                                   properties:@{}];
        [scenePNG writeToFile:scenePath atomically:YES];
    }

    NSBitmapImageRep *bitmap =
        [content bitmapImageRepForCachingDisplayInRect:content.bounds];
    if (!bitmap) return;
    [content cacheDisplayInRect:content.bounds toBitmapImageRep:bitmap];
    NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG
                                       properties:@{}];
    if (png) {
        [png writeToFile:path atomically:YES];
        NSLog(@"SKO screenshot: %@", path);
    }
}

@end
