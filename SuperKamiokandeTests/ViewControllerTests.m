#import <XCTest/XCTest.h>
#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>
#import "ViewController.h"
#import "SKOCommon.h"
#import "SKOHelpWindowController.h"

@interface ViewControllerTests : XCTestCase
@property (nonatomic, strong) ViewController *controller;
@end

@implementation ViewControllerTests

- (void)setUp
{
    [super setUp];
    if (!NSApp) {
        [NSApplication sharedApplication];
    }

    self.controller = [[ViewController alloc] init];
    self.controller.autoStartSimulation = NO;

    // Force viewDidLoad and resolve the initial split-view layout.
    self.controller.view.frame = NSMakeRect(0, 0, 1440, 900);
    [self.controller.view layoutSubtreeIfNeeded];
}

- (void)tearDown
{
    [self.controller.engine stop];
    [self.controller.helpWindowController close];
    self.controller = nil;
    [super tearDown];
}

- (void)testCoreInterfaceIsBuilt
{
    ViewController *vc = self.controller;
    XCTAssertNotNil(vc.sceneView);
    XCTAssertNotNil(vc.scene);
    XCTAssertNotNil(vc.rootGroup);
    XCTAssertNotNil(vc.cameraNode);
    XCTAssertNotNil(vc.engine);
    XCTAssertNotNil(vc.sidebar);
    XCTAssertNotNil(vc.statusLabel);
    XCTAssertNotNil(vc.hudStatusLabel);
    XCTAssertNotNil(vc.hudEventLabel);
    XCTAssertNotNil(vc.hudDetailLabel);
    XCTAssertNotNil(vc.hudEnvLabel);
    XCTAssertNotNil(vc.helpButton);
    XCTAssertNil(vc.helpWindowController);
    XCTAssertTrue([vc.sceneView.scene isEqual:vc.scene]);
    XCTAssertTrue([vc.sceneView.subviews containsObject:vc.labelsOverlay]);
    XCTAssertEqual(vc.labelsOverlay.subviews.count, 9); // 3 left, 5 right, 1 bottom
}

- (void)testControlBarSitsInTheUpperRightOfTheViewport
{
    ViewController *vc = self.controller;
    [vc.view layoutSubtreeIfNeeded];

    NSView *sceneView = vc.sceneView;
    NSRect sceneBounds = sceneView.bounds;
    NSRect buttonRect = [vc.helpButton convertRect:vc.helpButton.bounds toView:sceneView];

    XCTAssertGreaterThan(NSWidth(sceneBounds), 900.0);
    XCTAssertGreaterThan(NSMaxX(buttonRect), NSWidth(sceneBounds) - 60.0);
    XCTAssertGreaterThan(NSMaxY(buttonRect), NSHeight(sceneBounds) - 60.0);
    XCTAssertLessThan(NSMinX(buttonRect), NSWidth(sceneBounds));
}

- (void)testOverlayButtonsShareWidthAndHelpIncludesItsWord
{
    ViewController *vc = self.controller;
    [vc.view layoutSubtreeIfNeeded];

    NSArray<NSButton *> *buttons = @[
        vc.centerButton, vc.cutawayButton, vc.rotateButton,
        vc.explodeButton, vc.labelsButton, vc.helpButton,
        vc.sidebarRevealButton,
    ];
    CGFloat commonWidth = NSWidth(vc.centerButton.frame);
    XCTAssertGreaterThan(commonWidth, 80.0);

    for (NSButton *button in buttons) {
        XCTAssertEqualWithAccuracy(NSWidth(button.frame), commonWidth, 0.5,
                                   @"Overlay button %@ must share the common width",
                                   button.identifier);
    }

    XCTAssertEqualObjects(vc.helpButton.title, @"Help");
    XCTAssertNotNil(vc.helpButton.image);
}

- (void)testSidebarHidesAndRevealsTheScene
{
    ViewController *vc = self.controller;
    [vc.view layoutSubtreeIfNeeded];
    CGFloat expandedWidth = NSWidth(vc.sceneView.frame);
    XCTAssertTrue(vc.sidebarVisible);
    XCTAssertFalse(vc.sidebar.hidden);
    XCTAssertTrue(vc.sidebarRevealButton.hidden);

    [vc toggleSidebar:nil];
    [vc.view layoutSubtreeIfNeeded];
    XCTAssertFalse(vc.sidebarVisible);
    XCTAssertTrue(vc.sidebar.hidden);
    XCTAssertFalse(vc.sidebarRevealButton.hidden);
    XCTAssertGreaterThan(NSWidth(vc.sceneView.frame), expandedWidth);

    [vc toggleSidebar:nil];
    [vc.view layoutSubtreeIfNeeded];
    XCTAssertTrue(vc.sidebarVisible);
    XCTAssertFalse(vc.sidebar.hidden);
    XCTAssertTrue(vc.sidebarRevealButton.hidden);
    XCTAssertEqualWithAccuracy(NSWidth(vc.sceneView.frame), expandedWidth, 0.5);
}

- (void)testLabelsOverlayToggle
{
    ViewController *vc = self.controller;
    XCTAssertTrue(vc.labelsVisible);
    XCTAssertFalse(vc.labelsOverlay.hidden);
    XCTAssertEqual(vc.labelsOverlay.subviews.count, 9);
    XCTAssertNil([vc.labelsOverlay hitTest:NSMakePoint(50, 50)],
                 @"Labels must not steal mouse input from the orbit view");

    [vc toggleLabels:nil];
    XCTAssertFalse(vc.labelsVisible);
    XCTAssertTrue(vc.labelsOverlay.hidden);

    [vc toggleLabels:nil];
    XCTAssertTrue(vc.labelsVisible);
    XCTAssertFalse(vc.labelsOverlay.hidden);
}

- (void)testViewToggleButtons
{
    ViewController *vc = self.controller;
    XCTAssertTrue(vc.cutawayOn);
    [vc toggleCutaway:nil];
    XCTAssertFalse(vc.cutawayOn);
    XCTAssertEqualWithAccuracy(vc.cutawaySlider.doubleValue, 0.92, 0.001);
    [vc toggleCutaway:nil];
    XCTAssertTrue(vc.cutawayOn);
    XCTAssertEqualWithAccuracy(vc.cutawaySlider.doubleValue, 0.14, 0.001);

    XCTAssertFalse(vc.autoRotate);
    [vc toggleRotate:nil];
    XCTAssertTrue(vc.autoRotate);
    [vc toggleRotate:nil];
    XCTAssertFalse(vc.autoRotate);

    XCTAssertFalse(vc.exploded);
    [vc toggleExplode:nil];
    XCTAssertTrue(vc.exploded);
    [vc toggleExplode:nil];
    XCTAssertFalse(vc.exploded);
}

- (void)testSliderActionsDriveTheModelAndEngine
{
    ViewController *vc = self.controller;

    vc.waterSlider.doubleValue = 0.5;
    [vc.waterSlider sendAction:vc.waterSlider.action to:vc.waterSlider.target];
    SCNNode *waterBody = [vc.rootGroup childNodeWithName:@"waterBody" recursively:YES];
    XCTAssertNotNil(waterBody);
    XCTAssertEqualWithAccuracy(((SCNCylinder *)waterBody.geometry).height,
                               (SKOTankHeight - 1.0) * 0.5, 0.01);

    vc.fiducialSlider.doubleValue = 12.0;
    [vc.fiducialSlider sendAction:vc.fiducialSlider.action to:vc.fiducialSlider.target];
    SCNNode *fiducial = [vc.rootGroup childNodeWithName:@"fiducialBody" recursively:YES];
    XCTAssertEqualWithAccuracy(((SCNCylinder *)fiducial.geometry).radius, 12.0, 0.01);
    XCTAssertEqualWithAccuracy(vc.engine.fiducialRadius, 12.0, 0.01);

    vc.transparencySlider.doubleValue = 0.55;
    [vc.transparencySlider sendAction:vc.transparencySlider.action
                                   to:vc.transparencySlider.target];
    XCTAssertEqualWithAccuracy(waterBody.geometry.materials.firstObject.transparency,
                               0.55, 0.001);

    vc.cutawaySlider.doubleValue = 0.80;
    [vc.cutawaySlider sendAction:vc.cutawaySlider.action to:vc.cutawaySlider.target];
    XCTAssertFalse(vc.cutawayOn);
    SCNNode *shell = [vc.rootGroup childNodeWithName:@"shell" recursively:YES];
    for (SCNNode *child in shell.childNodes) {
        XCTAssertEqualWithAccuracy(child.opacity, 0.80, 0.001);
    }

    vc.sensitivitySlider.doubleValue = 1.35;
    [vc.sensitivitySlider sendAction:vc.sensitivitySlider.action
                                  to:vc.sensitivitySlider.target];
    XCTAssertEqualWithAccuracy(vc.engine.pmtSensitivity, 1.35, 0.001);

    vc.rateSlider.doubleValue = 9.0;
    [vc.rateSlider sendAction:vc.rateSlider.action to:vc.rateSlider.target];
    XCTAssertEqualWithAccuracy(vc.engine.eventRate, 9.0, 0.001);

    vc.rotationSlider.doubleValue = 0.62;
    [vc.rotationSlider sendAction:vc.rotationSlider.action to:vc.rotationSlider.target];
    XCTAssertEqualWithAccuracy(vc.autoRotateSpeed, 0.62, 0.001);
}

- (void)testRunPauseAndReset
{
    ViewController *vc = self.controller;
    XCTAssertFalse(vc.engine.running);

    [vc toggleRun:nil];
    XCTAssertTrue(vc.engine.running);
    XCTAssertTrue([vc.runButton.title containsString:@"Pause"]);

    [vc toggleRun:nil];
    XCTAssertFalse(vc.engine.running);
    XCTAssertTrue([vc.runButton.title containsString:@"Resume"]);

    [vc.engine fireOnce];
    XCTAssertEqual(vc.engine.totalEvents, 1);
    [vc resetCounter:nil];
    XCTAssertEqual(vc.engine.totalEvents, 0);
    XCTAssertEqualObjects(vc.hudEventLabel.stringValue, @"0");
}

- (void)testEventUpdatesHUD
{
    ViewController *vc = self.controller;
    XCTAssertEqualObjects(vc.hudDetailLabel.stringValue, @"Awaiting first event");
    [vc.engine fireOnce];
    XCTAssertTrue([vc.hudDetailLabel.stringValue containsString:@"Last event"]);
    XCTAssertTrue([vc.hudEnvLabel.stringValue containsString:@"Water"]);
}

- (void)testControlsExposeStableIdentifiersAndAccessibilityText
{
    ViewController *vc = self.controller;
    XCTAssertEqualObjects(vc.runButton.identifier, @"runButton");
    XCTAssertEqualObjects(vc.resetButton.identifier, @"resetButton");
    XCTAssertEqualObjects(vc.cameraButton.identifier, @"cameraButton");
    XCTAssertEqualObjects(vc.centerButton.identifier, @"centerButton");
    XCTAssertEqualObjects(vc.cutawayButton.identifier, @"cutawayButton");
    XCTAssertEqualObjects(vc.rotateButton.identifier, @"rotateButton");
    XCTAssertEqualObjects(vc.explodeButton.identifier, @"explodeButton");
    XCTAssertEqualObjects(vc.labelsButton.identifier, @"labelsButton");
    XCTAssertEqualObjects(vc.helpButton.identifier, @"helpButton");
    XCTAssertEqualObjects(vc.sidebarCollapseButton.identifier, @"sidebarCollapseButton");
    XCTAssertEqualObjects(vc.sidebarRevealButton.identifier, @"sidebarRevealButton");

    for (NSSlider *slider in @[vc.waterSlider, vc.fiducialSlider,
                               vc.transparencySlider, vc.cutawaySlider,
                               vc.sensitivitySlider, vc.rateSlider,
                               vc.rotationSlider]) {
        XCTAssertTrue(slider.accessibilityLabel.length > 0);
    }
    XCTAssertEqualObjects(vc.labelsButton.accessibilityLabel, @"Labels");
    XCTAssertEqualObjects(vc.helpButton.accessibilityLabel, @"Super-Kamiokande Help");
}

- (void)testHelpWindowIsCreatedOnceAndReused
{
    ViewController *vc = self.controller;
    XCTAssertNil(vc.helpWindowController);

    [vc showHelp:nil];
    XCTAssertNotNil(vc.helpWindowController);
    NSWindow *window = vc.helpWindowController.window;
    XCTAssertEqualObjects(window.title, @"Super-Kamiokande Help");
    XCTAssertTrue(window.isVisible);

    [vc showHelp:nil];
    XCTAssertEqual(vc.helpWindowController.window, window);
}

@end
