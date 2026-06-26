#import <XCTest/XCTest.h>
#import "SKOHelpWindowController.h"

static void SKOCollectLabelText(NSView *view, NSMutableArray<NSString *> *text)
{
    if ([view isKindOfClass:[NSTextField class]]) {
        NSTextField *field = (NSTextField *)view;
        if (field.stringValue.length > 0) {
            [text addObject:field.stringValue];
        }
    }
    for (NSView *subview in view.subviews) {
        SKOCollectLabelText(subview, text);
    }
}

@interface SKOHelpWindowControllerTests : XCTestCase
@property (nonatomic, strong) SKOHelpWindowController *controller;
@end

@implementation SKOHelpWindowControllerTests

- (void)setUp
{
    [super setUp];
    if (!NSApp) {
        [NSApplication sharedApplication];
    }
    self.controller = [[SKOHelpWindowController alloc] init];
}

- (void)tearDown
{
    [self.controller close];
    self.controller = nil;
    [super tearDown];
}

- (void)testWindowConfiguration
{
    NSWindow *window = self.controller.window;
    XCTAssertNotNil(window);
    XCTAssertEqualObjects(window.title, @"Super-Kamiokande Help");
    XCTAssertTrue((window.styleMask & NSWindowStyleMaskClosable) != 0);
    XCTAssertTrue((window.styleMask & NSWindowStyleMaskResizable) != 0);
    XCTAssertGreaterThanOrEqual(window.minSize.width, 640.0);
    XCTAssertGreaterThanOrEqual(window.minSize.height, 520.0);
    XCTAssertEqualObjects(self.controller.titleLabel.stringValue, @"SUPER-KAMIOKANDE");
}

- (void)testHelpContentExplainsTheExplorer
{
    NSScrollView *scrollView = self.controller.scrollView;
    XCTAssertNotNil(scrollView);
    XCTAssertTrue(scrollView.hasVerticalScroller);
    XCTAssertNotNil(scrollView.documentView);

    [self.controller showRelativeToWindow:nil];
    [self.controller.window.contentView layoutSubtreeIfNeeded];

    NSMutableArray<NSString *> *text = [NSMutableArray array];
    SKOCollectLabelText(scrollView.documentView, text);
    NSString *allText = [text componentsJoinedByString:@"\n"];

    XCTAssertTrue([allText containsString:@"A working detector"]);
    XCTAssertTrue([allText containsString:@"Four ways to begin"]);
    XCTAssertTrue([allText containsString:@"What the events mean"]);
    XCTAssertTrue([allText containsString:@"Tuning the run"]);
    XCTAssertTrue([allText containsString:@"Scale and numbers"]);
    XCTAssertTrue([allText containsString:@"Shortcuts"]);
    XCTAssertTrue([allText containsString:@"11,129"]);
    XCTAssertTrue([allText containsString:@"50,000 t"]);
    XCTAssertTrue([allText containsString:@"Super-Kamiokande Help"]);
}

- (void)testHelpWindowCanBeShownRepeatedly
{
    [self.controller showRelativeToWindow:nil];
    NSWindow *window = self.controller.window;
    XCTAssertTrue(window.isVisible);
    [window close];
    XCTAssertFalse(window.isVisible);

    [self.controller showRelativeToWindow:nil];
    XCTAssertTrue(window.isVisible);
    XCTAssertEqual(self.controller.window, window);
}

@end
