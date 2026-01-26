#import "ViewController.h"
#import "SKOTankBuilder.h"
#import "SKOCommon.h"
#import "SKOHelpWindowController.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Palette helpers

static NSColor *SKOColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a)
{
    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
}

static NSColor *SKOAccent(void)      { return SKOColor(0.16, 0.83, 0.90, 1.0); }
static NSColor *SKOTextPrimary(void) { return SKOColor(0.94, 0.96, 0.98, 1.0); }
static NSColor *SKOTextSecondary(void){ return SKOColor(0.62, 0.67, 0.73, 1.0); }
static NSColor *SKOTextFaint(void)   { return SKOColor(0.42, 0.46, 0.52, 1.0); }
static NSColor *SKOPanelDark(void)   { return SKOColor(0.035, 0.045, 0.060, 0.92); }

static NSTextField *SKOMakeLabel(NSString *text,
                                 CGFloat size,
                                 NSFontWeight weight,
                                 NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.maximumNumberOfLines = 1;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.selectable = NO;
    label.drawsBackground = NO;
    label.bordered = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

static NSTextField *SKOSectionTitle(NSString *text)
{
    NSTextField *label = [NSTextField labelWithString:@""];
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentLeft;
    label.attributedStringValue = [[NSAttributedString alloc]
        initWithString:text.uppercaseString
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: SKOTextFaint(),
                NSKernAttributeName: @1.25,
                NSParagraphStyleAttributeName: style,
            }];
    label.selectable = NO;
    label.drawsBackground = NO;
    label.bordered = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

static NSView *SKODivider(void)
{
    NSView *view = [[NSView alloc] initWithFrame:NSZeroRect];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.wantsLayer = YES;
    view.layer.backgroundColor = SKOColor(1.0, 1.0, 1.0, 0.07).CGColor;
    [view.heightAnchor constraintEqualToConstant:1.0].active = YES;
    return view;
}

static void SKOStyleGlassPanel(NSVisualEffectView *view, CGFloat radius)
{
    view.wantsLayer = YES;
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;
    view.layer.borderWidth = 1.0;
    view.layer.borderColor = SKOColor(1.0, 1.0, 1.0, 0.10).CGColor;
}

#pragma mark - Flat button

@interface SKOFlatButton : NSButton
@property (nonatomic, assign) BOOL active;
@property (nonatomic, assign) BOOL hovering;
@property (nonatomic, assign) CGFloat contentPadding;
@property (nonatomic, strong) NSColor *fillColor;
@property (nonatomic, strong) NSColor *hoverFillColor;
@property (nonatomic, strong) NSColor *activeFillColor;
@property (nonatomic, strong) NSColor *strokeColor;
@property (nonatomic, strong) NSColor *activeStrokeColor;
@property (nonatomic, strong) NSColor *normalTextColor;
@property (nonatomic, strong) NSColor *activeTextColor;
@property (nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@end

@implementation SKOFlatButton

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.bordered = NO;
        self.bezelStyle = NSBezelStyleRounded;
        self.focusRingType = NSFocusRingTypeNone;
        self.wantsLayer = YES;
        self.layer.cornerRadius = 7.0;
        self.layer.masksToBounds = YES;
        self.layer.borderWidth = 1.0;
        self.contentPadding = 9.0;
        self.normalTextColor = SKOTextPrimary();
        self.activeTextColor = SKOTextPrimary();
        self.fillColor = SKOColor(1.0, 1.0, 1.0, 0.06);
        self.hoverFillColor = SKOColor(1.0, 1.0, 1.0, 0.12);
        self.activeFillColor = SKOColor(0.10, 0.50, 0.57, 0.70);
        self.strokeColor = SKOColor(1.0, 1.0, 1.0, 0.10);
        self.activeStrokeColor = SKOColor(0.28, 0.92, 0.98, 0.85);
        self.imagePosition = NSImageLeading;
        self.imageHugsTitle = YES;
        self.imageScaling = NSImageScaleProportionallyDown;
        self.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    }
    return self;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event
{
    (void)event;
    return YES;
}

- (BOOL)wantsUpdateLayer
{
    return YES;
}

- (void)updateLayer
{
    [super updateLayer];
    NSColor *fill = self.active ? self.activeFillColor
                                : (self.hovering ? self.hoverFillColor : self.fillColor);
    NSColor *stroke = self.active ? self.activeStrokeColor : self.strokeColor;
    self.layer.backgroundColor = fill.CGColor;
    self.layer.borderColor = stroke.CGColor;
    self.layer.borderWidth = 1.0;
}

- (void)setActive:(BOOL)active
{
    if (_active == active) return;
    _active = active;
    [self refreshStyledTitle];
    self.needsDisplay = YES;
}

- (void)setHovering:(BOOL)hovering
{
    if (_hovering == hovering) return;
    _hovering = hovering;
    self.needsDisplay = YES;
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    if (self.hoverTrackingArea) {
        [self removeTrackingArea:self.hoverTrackingArea];
    }
    self.hoverTrackingArea = [[NSTrackingArea alloc]
        initWithRect:NSZeroRect
             options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow |
                     NSTrackingInVisibleRect
               owner:self
            userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}

- (void)mouseEntered:(NSEvent *)event
{
    (void)event;
    self.hovering = YES;
}

- (void)mouseExited:(NSEvent *)event
{
    (void)event;
    self.hovering = NO;
}

- (void)setStyledTitle:(NSString *)title symbol:(NSString *)symbol
{
    self.title = title ?: @"";
    NSImage *image = nil;
    if (symbol.length > 0) {
        image = [NSImage imageWithSystemSymbolName:symbol
                          accessibilityDescription:title];
        NSImageSymbolConfiguration *config =
            [NSImageSymbolConfiguration configurationWithPointSize:11.5
                                                            weight:NSFontWeightSemibold];
        image = [image imageWithSymbolConfiguration:config];
        image.template = YES;
    }
    self.image = image;
    self.contentTintColor = self.normalTextColor;
    [self refreshStyledTitle];
    [self invalidateIntrinsicContentSize];
}

- (void)refreshStyledTitle
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.alignment = NSTextAlignmentCenter;
    NSColor *color = self.active ? self.activeTextColor : self.normalTextColor;
    self.contentTintColor = color;
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: color,
        NSParagraphStyleAttributeName: style,
    };
    self.attributedTitle = [[NSAttributedString alloc] initWithString:self.title
                                                           attributes:attrs];
}

- (NSSize)intrinsicContentSize
{
    NSSize cell = [self.cell cellSize];
    cell.width += self.contentPadding * 2.0;
    cell.height = MAX(cell.height, 26.0);
    return cell;
}

@end

#pragma mark - Scene view (custom orbit, no SceneKit camera rig)

@interface SKOSceneView : SCNView
@property (nonatomic, copy) void (^orbitBlock)(CGFloat dx, CGFloat dy);
@property (nonatomic, copy) void (^zoomBlock)(CGFloat factor);
@property (nonatomic, copy) void (^doubleClickBlock)(void);
@end

@implementation SKOSceneView

- (BOOL)acceptsFirstResponder
{
    return YES;
}

- (void)mouseDown:(NSEvent *)event
{
    if (event.clickCount == 2 && self.doubleClickBlock) {
        self.doubleClickBlock();
        return;
    }
    [super mouseDown:event];
}

- (void)mouseDragged:(NSEvent *)event
{
    if (self.orbitBlock) {
        self.orbitBlock(event.deltaX, event.deltaY);
    }
}

- (void)scrollWheel:(NSEvent *)event
{
    if (self.zoomBlock) {
        CGFloat factor = 1.0 - event.scrollingDeltaY * 0.006;
        self.zoomBlock(factor);
    } else {
        [super scrollWheel:event];
    }
}

- (void)magnifyWithEvent:(NSEvent *)event
{
    if (self.zoomBlock) {
        self.zoomBlock(1.0 - event.magnification * 0.75);
    } else {
        [super magnifyWithEvent:event];
    }
}

@end

#pragma mark - Passthrough overlay view

@interface SKOPassthroughView : NSView
@end

@implementation SKOPassthroughView
- (NSView *)hitTest:(NSPoint)point
{
    (void)point;
    return nil;
}
@end

#pragma mark - Flipped document view

@interface SKOFlippedView : NSView
@end

@implementation SKOFlippedView
- (BOOL)isFlipped
{
    return YES;
}
@end

#pragma mark - Part label pill

@interface SKOLabelPillView : NSView
@property (nonatomic, strong) NSTextField *titleLabel;
@property (nonatomic, strong) NSTextField *detailLabel;
@property (nonatomic, strong) NSColor *accentColor;
- (void)setTitle:(NSString *)title detail:(NSString *)detail;
@end

@implementation SKOLabelPillView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        self.wantsLayer = YES;
        self.layer.shadowColor = [NSColor blackColor].CGColor;
        self.layer.shadowOpacity = 0.45;
        self.layer.shadowRadius = 9.0;
        self.layer.shadowOffset = NSMakeSize(0, -3);
        self.accentColor = SKOAccent();

        self.titleLabel = SKOMakeLabel(@"", 11.0, NSFontWeightSemibold, SKOTextPrimary());
        self.detailLabel = SKOMakeLabel(@"", 9.2, NSFontWeightRegular, SKOTextSecondary());
        [self addSubview:self.titleLabel];
        [self addSubview:self.detailLabel];

        [NSLayoutConstraint activateConstraints:@[
            [self.titleLabel.leadingAnchor constraintEqualToAnchor:self.leadingAnchor
                                                          constant:14],
            [self.titleLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor
                                                           constant:-8],
            [self.titleLabel.topAnchor constraintEqualToAnchor:self.topAnchor constant:5],
            [self.detailLabel.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
            [self.detailLabel.trailingAnchor constraintEqualToAnchor:self.titleLabel.trailingAnchor],
            [self.detailLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor
                                                       constant:1],
        ]];
    }
    return self;
}

- (void)setTitle:(NSString *)title detail:(NSString *)detail
{
    self.titleLabel.stringValue = title;
    self.detailLabel.stringValue = detail;
    self.toolTip = [NSString stringWithFormat:@"%@ — %@", title, detail];
    self.accessibilityLabel = [NSString stringWithFormat:@"%@, %@", title, detail];
}

- (void)setAccentColor:(NSColor *)accentColor
{
    _accentColor = accentColor;
    self.needsDisplay = YES;
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSRect bounds = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:bounds
                                                       xRadius:7.5
                                                       yRadius:7.5];
    [SKOPanelDark() setFill];
    [bg fill];
    [SKOColor(1.0, 1.0, 1.0, 0.12) setStroke];
    bg.lineWidth = 1.0;
    [bg stroke];

    NSRect accent = NSMakeRect(NSMinX(self.bounds) + 1.0,
                               NSMinY(self.bounds) + 8.0,
                               2.5,
                               MAX(1.0, NSHeight(self.bounds) - 16.0));
    NSBezierPath *bar = [NSBezierPath bezierPathWithRoundedRect:accent
                                                        xRadius:1.25
                                                        yRadius:1.25];
    [self.accentColor setFill];
    [bar fill];
}

@end

#pragma mark - Label spec

@interface SKOLabelSpec : NSObject
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *detail;
@property (nonatomic, copy) NSString *groupName;
@property (nonatomic, assign) SCNVector3 localAnchor;
@property (nonatomic, assign) NSInteger column;   // 0 left, 1 right, 2 bottom
@property (nonatomic, assign) NSInteger slot;
@property (nonatomic, strong) NSColor *accentColor;
@end

@implementation SKOLabelSpec
@end

#pragma mark - Slider row

@interface SKOSliderRow : NSView
@property (nonatomic, strong) NSSlider *slider;
@property (nonatomic, strong) NSTextField *valueLabel;
@property (nonatomic, copy) NSString *(^formatter)(CGFloat value);
- (instancetype)initWithTitle:(NSString *)title
                       slider:(NSSlider *)slider
                    formatter:(NSString *(^)(CGFloat value))formatter;
- (void)refreshValue;
@end

@implementation SKOSliderRow

- (instancetype)initWithTitle:(NSString *)title
                       slider:(NSSlider *)slider
                    formatter:(NSString *(^)(CGFloat value))formatter
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        self.formatter = formatter;

        NSTextField *name = SKOMakeLabel(title, 12.0, NSFontWeightMedium, SKOTextPrimary());
        self.valueLabel = SKOMakeLabel(@"", 11.0, NSFontWeightMedium, SKOAccent());
        self.valueLabel.font = [NSFont monospacedDigitSystemFontOfSize:11.0
                                                                weight:NSFontWeightMedium];
        self.valueLabel.alignment = NSTextAlignmentRight;
        [self.valueLabel setContentHuggingPriority:NSLayoutPriorityRequired
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
        self.slider = slider;
        self.slider.translatesAutoresizingMaskIntoConstraints = NO;
        self.slider.continuous = YES;
        self.slider.controlSize = NSControlSizeSmall;
        self.slider.toolTip = title;
        self.slider.accessibilityLabel = title;

        [self addSubview:name];
        [self addSubview:self.valueLabel];
        [self addSubview:self.slider];

        [NSLayoutConstraint activateConstraints:@[
            [name.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [name.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.valueLabel.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.valueLabel.centerYAnchor constraintEqualToAnchor:name.centerYAnchor],
            [self.valueLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:name.trailingAnchor
                                                                       constant:8],
            [self.slider.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.slider.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.slider.topAnchor constraintEqualToAnchor:name.bottomAnchor constant:5],
            [self.slider.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        ]];
        [self refreshValue];
    }
    return self;
}

- (void)refreshValue
{
    if (self.formatter) {
        self.valueLabel.stringValue = self.formatter(self.slider.doubleValue);
    }
}

@end

#pragma mark - View controller

@interface ViewController () <SKOEventEngineDelegate>
@property (nonatomic, strong) NSVisualEffectView *hudPanel;
@property (nonatomic, strong) NSView *hudStatusDot;
@property (nonatomic, strong) SKOFlatButton *revealButton;
@property (nonatomic, strong) NSLayoutConstraint *sidebarLeadingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *sidebarWidthConstraint;
@property (nonatomic, strong) NSLayoutConstraint *revealTopConstraint;
@property (nonatomic, strong) NSMutableDictionary<NSString *, SKOSliderRow *> *sliderRows;
@property (nonatomic, strong) NSMutableArray<SKOLabelSpec *> *labelSpecs;
@property (nonatomic, strong) NSMutableArray<SKOLabelPillView *> *labelPills;
@property (nonatomic, strong) CAShapeLayer *leaderLayer;
@property (nonatomic, strong) CAShapeLayer *anchorLayer;
@property (nonatomic, strong) NSTimer *hudTimer;
@property (nonatomic, strong) NSTimer *labelTimer;
@property (nonatomic, strong) NSTimer *rotateTimer;
@property (nonatomic, assign) CGFloat lastEnergyGeV;
@property (nonatomic, assign) SKOEventKind lastKind;
@property (nonatomic, assign) CGFloat cameraAzimuth;
@property (nonatomic, assign) CGFloat cameraElevation;
@property (nonatomic, assign) CGFloat cameraDistance;
@end

@implementation ViewController

static const CGFloat kSidebarExpandedWidth = 308.0;
static const CGFloat kOverlayButtonWidth = 86.0;
static const CGFloat kLabelWidth = 208.0;
static const CGFloat kLabelHeight = 40.0;

- (instancetype)init
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _sidebarVisible = YES;
        _labelsVisible = YES;
        _cutawayOn = YES;
        _autoStartSimulation = YES;
        _autoRotate = NO;
        _autoRotateSpeed = 0.35;
        _cameraAzimuth = 0.70;
        _cameraElevation = 0.24;
        _cameraDistance = 100.0;
        _lastEnergyGeV = 0.0;
        _lastKind = SKOEventKindElectron;
        _sliderRows = [NSMutableDictionary dictionary];
        _labelSpecs = [NSMutableArray array];
        _labelPills = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    [self.engine stop];
    [self.helpWindowController close];
    [self.hudTimer invalidate];
    [self.labelTimer invalidate];
    [self.rotateTimer invalidate];
}

- (void)loadView
{
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 1440, 900)];
    root.wantsLayer = YES;
    root.layer.backgroundColor = [NSColor blackColor].CGColor;
    self.view = root;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];

    [self buildScene];
    [self buildSidebar];
    [self buildSceneView];
    [self buildLabels];
    [self buildHUDPanel];
    [self buildViewControls];

    [self.engine attachSceneRoot:self.rootGroup];
    if (self.autoStartSimulation) {
        [self.engine start];
    }
    [self refreshAllReadouts];
    [self startHUDTimer];

    __weak typeof(self) weakSelf = self;
    self.labelTimer = [NSTimer timerWithTimeInterval:1.0 / 30.0
                                            repeats:YES
                                              block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf updateLabelPositions];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.labelTimer forMode:NSRunLoopCommonModes];
}

- (void)viewDidLayout
{
    [super viewDidLayout];
    [self updateSidebarRevealPosition];
    [self updateLabelPositions];
}

#pragma mark - Scene

- (void)buildScene
{
    self.scene = [SCNScene scene];
    self.scene.background.contents = [self backdropImage];
    self.scene.fogStartDistance = 112.0;
    self.scene.fogEndDistance = 240.0;
    self.scene.fogColor = SKOColor(0.01, 0.015, 0.02, 1.0);

    NSString *environmentPath = [[NSBundle mainBundle]
        pathForResource:@"CavernEnvironment" ofType:@"jpg" inDirectory:@"Textures"];
    if (!environmentPath) {
        environmentPath = @"SuperKamiokande/Textures/CavernEnvironment.jpg";
    }
    NSImage *environment = [[NSImage alloc] initWithContentsOfFile:environmentPath];
    if (environment) {
        self.scene.lightingEnvironment.contents = environment;
        self.scene.lightingEnvironment.intensity = 0.48;
    }

    self.rootGroup = [SCNNode node];
    self.rootGroup.name = @"detectorRoot";
    [self.scene.rootNode addChildNode:self.rootGroup];
    [SKOTankBuilder buildIntoRoot:self.rootGroup];
    [SKOTankBuilder setShellOpacity:0.14 rootNode:self.rootGroup];

    // Key / fill / rim lighting for the cavern and steel.
    SCNNode *ambientNode = [SCNNode node];
    SCNLight *ambient = [SCNLight light];
    ambient.type = SCNLightTypeAmbient;
    ambient.color = SKOColor(0.54, 0.64, 0.78, 1.0);
    ambient.intensity = 360;
    ambientNode.light = ambient;
    [self.scene.rootNode addChildNode:ambientNode];

    SCNNode *keyNode = [SCNNode node];
    SCNLight *key = [SCNLight light];
    key.type = SCNLightTypeDirectional;
    key.color = SKOColor(0.93, 0.96, 1.0, 1.0);
    key.intensity = 1150;
    keyNode.light = key;
    keyNode.eulerAngles = SCNVector3Make(-0.78, 0.62, 0);
    [self.scene.rootNode addChildNode:keyNode];

    SCNNode *fillNode = [SCNNode node];
    SCNLight *fill = [SCNLight light];
    fill.type = SCNLightTypeDirectional;
    fill.color = SKOColor(0.35, 0.70, 0.95, 1.0);
    fill.intensity = 520;
    fillNode.light = fill;
    fillNode.eulerAngles = SCNVector3Make(-0.18, -1.15, 0);
    [self.scene.rootNode addChildNode:fillNode];

    SCNNode *rimNode = [SCNNode node];
    SCNLight *rim = [SCNLight light];
    rim.type = SCNLightTypeDirectional;
    rim.color = SKOColor(0.42, 0.67, 1.0, 1.0);
    rim.intensity = 650;
    rimNode.light = rim;
    rimNode.eulerAngles = SCNVector3Make(0.35, 2.45, 0);
    [self.scene.rootNode addChildNode:rimNode];

    self.lookTarget = [SCNNode node];
    self.lookTarget.position = SCNVector3Make(0, SKOTankHeight / 2.0, 0);
    [self.scene.rootNode addChildNode:self.lookTarget];

    self.cameraNode = [SCNNode node];
    SCNCamera *camera = [SCNCamera camera];
    camera.fieldOfView = 52.0;
    camera.zNear = 0.15;
    camera.zFar = 500.0;
    camera.wantsHDR = YES;
    camera.bloomIntensity = 0.85;
    camera.bloomThreshold = 0.82;
    camera.bloomBlurRadius = 7.0;
    self.cameraNode.camera = camera;
    SCNLookAtConstraint *lookAt = [SCNLookAtConstraint lookAtConstraintWithTarget:self.lookTarget];
    lookAt.gimbalLockEnabled = YES;
    self.cameraNode.constraints = @[lookAt];
    [self.scene.rootNode addChildNode:self.cameraNode];
    [self updateCamera];

    self.engine = [[SKOEventEngine alloc] init];
    self.engine.delegate = self;
    self.engine.eventRate = 3.0;
    self.engine.fiducialRadius = 8.0;
    self.engine.pmtSensitivity = 1.0;
}

- (NSImage *)backdropImage
{
    NSSize size = NSMakeSize(1024, 1024);
    return [NSImage imageWithSize:size
                           flipped:NO
                    drawingHandler:^BOOL(NSRect rect) {
        [[NSColor blackColor] setFill];
        NSRectFill(rect);
        NSGradient *gradient = [[NSGradient alloc]
            initWithColors:@[SKOColor(0.045, 0.075, 0.115, 1.0),
                             SKOColor(0.005, 0.008, 0.012, 1.0)]];
        [gradient drawInRect:rect relativeCenterPosition:NSMakePoint(0.0, 0.18)];
        return YES;
    }];
}

- (void)buildSidebar
{
    NSVisualEffectView *sidebar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    sidebar.material = NSVisualEffectMaterialSidebar;
    sidebar.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    sidebar.state = NSVisualEffectStateActive;
    sidebar.translatesAutoresizingMaskIntoConstraints = NO;
    sidebar.wantsLayer = YES;
    [self.view addSubview:sidebar];
    self.sidebar = sidebar;

    NSView *border = [[NSView alloc] initWithFrame:NSZeroRect];
    border.translatesAutoresizingMaskIntoConstraints = NO;
    border.wantsLayer = YES;
    border.layer.backgroundColor = SKOColor(1.0, 1.0, 1.0, 0.06).CGColor;
    [sidebar addSubview:border];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.borderType = NSNoBorder;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.scrollerStyle = NSScrollerStyleOverlay;
    [sidebar addSubview:scroll];

    NSView *document = [[SKOFlippedView alloc] initWithFrame:NSMakeRect(0, 0, 300, 820)];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll setDocumentView:document];

    NSStackView *mainStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    mainStack.translatesAutoresizingMaskIntoConstraints = NO;
    mainStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    mainStack.alignment = NSLayoutAttributeLeading;
    mainStack.distribution = NSStackViewDistributionFill;
    mainStack.spacing = 0;
    [document addSubview:mainStack];

    [NSLayoutConstraint activateConstraints:@[
        [border.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [border.topAnchor constraintEqualToAnchor:sidebar.topAnchor],
        [border.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor],
        [border.widthAnchor constraintEqualToConstant:1.0],

        [scroll.leadingAnchor constraintEqualToAnchor:sidebar.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:sidebar.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:sidebar.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:sidebar.bottomAnchor],

        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],

        [mainStack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:20],
        [mainStack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-20],
        [mainStack.topAnchor constraintEqualToAnchor:document.topAnchor constant:20],
        [mainStack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-24],
    ]];

    NSLayoutConstraint *width = [sidebar.widthAnchor constraintEqualToConstant:kSidebarExpandedWidth];
    NSLayoutConstraint *leading = [sidebar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor];
    self.sidebarWidthConstraint = width;
    self.sidebarLeadingConstraint = leading;
    [NSLayoutConstraint activateConstraints:@[
        leading,
        [sidebar.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sidebar.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        width,
    ]];

    [self buildSidebarContentInStack:mainStack];
}

- (void)buildSidebarContentInStack:(NSStackView *)stack
{
    [self addSection:[self buildHeaderView] toStack:stack];
    [self addSection:[self buildRunSection] toStack:stack];
    [self addSection:[self buildDetectorSection] toStack:stack];
    [self addSection:[self buildMotionSection] toStack:stack];
    [self addSection:[self buildFooterView] toStack:stack];
}

- (void)addSection:(NSView *)section toStack:(NSStackView *)stack
{
    section.translatesAutoresizingMaskIntoConstraints = NO;
    [stack addArrangedSubview:section];
    [section.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    [stack setCustomSpacing:16 afterView:section];
}

- (NSStackView *)verticalSection
{
    NSStackView *section = [[NSStackView alloc] initWithFrame:NSZeroRect];
    section.translatesAutoresizingMaskIntoConstraints = NO;
    section.orientation = NSUserInterfaceLayoutOrientationVertical;
    section.alignment = NSLayoutAttributeLeading;
    section.distribution = NSStackViewDistributionFill;
    section.spacing = 9;
    return section;
}

- (void)addFullWidthView:(NSView *)view toSection:(NSStackView *)section
{
    view.translatesAutoresizingMaskIntoConstraints = NO;
    [section addArrangedSubview:view];
    [view.widthAnchor constraintEqualToAnchor:section.widthAnchor].active = YES;
}

- (NSView *)buildHeaderView
{
    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    icon.image = NSApp.applicationIconImage ?: [self placeholderIcon];
    icon.imageScaling = NSImageScaleProportionallyUpOrDown;
    icon.wantsLayer = YES;
    icon.layer.cornerRadius = 9;
    icon.layer.masksToBounds = YES;
    [header addSubview:icon];

    NSTextField *title = SKOMakeLabel(@"SUPER-KAMIOKANDE", 15.0, NSFontWeightHeavy, SKOTextPrimary());
    title.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"SUPER-KAMIOKANDE"
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:14.0 weight:NSFontWeightHeavy],
                NSForegroundColorAttributeName: SKOTextPrimary(),
                NSKernAttributeName: @0.35,
            }];
    NSTextField *subtitle = SKOMakeLabel(@"3D DETECTOR EXPLORER", 9.0, NSFontWeightSemibold,
                                         SKOTextSecondary());
    subtitle.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"3D DETECTOR EXPLORER"
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:9.0 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: SKOTextSecondary(),
                NSKernAttributeName: @1.05,
            }];
    [header addSubview:title];
    [header addSubview:subtitle];

    SKOFlatButton *collapse = [[SKOFlatButton alloc] initWithFrame:NSZeroRect];
    collapse.translatesAutoresizingMaskIntoConstraints = NO;
    collapse.contentPadding = 6;
    collapse.fillColor = SKOColor(1.0, 1.0, 1.0, 0.04);
    collapse.hoverFillColor = SKOColor(1.0, 1.0, 1.0, 0.11);
    collapse.strokeColor = SKOColor(1.0, 1.0, 1.0, 0.07);
    [collapse setStyledTitle:@"" symbol:@"sidebar.left"];
    collapse.target = self;
    collapse.action = @selector(toggleSidebar:);
    collapse.toolTip = @"Hide controls";
    collapse.accessibilityLabel = @"Hide controls";
    collapse.identifier = @"sidebarCollapseButton";
    self.sidebarCollapseButton = collapse;
    [header addSubview:collapse];

    [NSLayoutConstraint activateConstraints:@[
        [header.heightAnchor constraintEqualToConstant:54],
        [icon.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:42],
        [icon.heightAnchor constraintEqualToConstant:42],
        [title.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:12],
        [title.topAnchor constraintEqualToAnchor:header.topAnchor constant:5],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [collapse.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [collapse.topAnchor constraintEqualToAnchor:header.topAnchor],
        [collapse.widthAnchor constraintEqualToConstant:26],
        [collapse.heightAnchor constraintEqualToConstant:26],
    ]];

    return header;
}

- (NSImage *)placeholderIcon
{
    return [NSImage imageWithSize:NSMakeSize(128, 128)
                           flipped:NO
                    drawingHandler:^BOOL(NSRect rect) {
        NSBezierPath *bg = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 4, 4)
                                                           xRadius:28
                                                           yRadius:28];
        NSGradient *gradient = [[NSGradient alloc]
            initWithColors:@[SKOColor(0.10, 0.36, 0.46, 1.0),
                             SKOColor(0.02, 0.09, 0.16, 1.0)]];
        [gradient drawInRect:rect angle:-90];
        [SKOColor(0.35, 0.92, 1.0, 1.0) setStroke];
        bg.lineWidth = 5;
        [bg stroke];
        NSDictionary *attrs = @{
            NSFontAttributeName: [NSFont systemFontOfSize:50 weight:NSFontWeightHeavy],
            NSForegroundColorAttributeName: [NSColor whiteColor],
        };
        [@"SK" drawAtPoint:NSMakePoint(28, 38) withAttributes:attrs];
        return YES;
    }];
}

- (NSView *)buildRunSection
{
    NSStackView *section = [self verticalSection];
    [self addFullWidthView:SKOSectionTitle(@"SIMULATION") toSection:section];

    SKOFlatButton *run = [[SKOFlatButton alloc] initWithFrame:NSZeroRect];
    run.fillColor = SKOColor(0.07, 0.42, 0.48, 1.0);
    run.hoverFillColor = SKOColor(0.09, 0.53, 0.60, 1.0);
    run.strokeColor = SKOColor(0.25, 0.88, 0.94, 0.55);
    run.contentPadding = 12;
    [run setStyledTitle:@"Pause simulation" symbol:@"pause.fill"];
    run.target = self;
    run.action = @selector(toggleRun:);
    run.identifier = @"runButton";
    [run.heightAnchor constraintEqualToConstant:38].active = YES;
    self.runButton = run;
    [self addFullWidthView:run toSection:section];

    self.statusLabel = SKOMakeLabel(@"Running · 3.0 events/s", 10.5, NSFontWeightRegular,
                                    SKOTextSecondary());
    [self addFullWidthView:self.statusLabel toSection:section];

    SKOFlatButton *reset = [[SKOFlatButton alloc] initWithFrame:NSZeroRect];
    [reset setStyledTitle:@"Reset events" symbol:@"arrow.counterclockwise"];
    reset.target = self;
    reset.action = @selector(resetCounter:);
    reset.identifier = @"resetButton";
    [reset.heightAnchor constraintEqualToConstant:30].active = YES;
    self.resetButton = reset;

    SKOFlatButton *camera = [[SKOFlatButton alloc] initWithFrame:NSZeroRect];
    [camera setStyledTitle:@"Reset camera" symbol:@"viewfinder"];
    camera.target = self;
    camera.action = @selector(resetCamera:);
    camera.identifier = @"cameraButton";
    [camera.heightAnchor constraintEqualToConstant:30].active = YES;
    self.cameraButton = camera;

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.distribution = NSStackViewDistributionFillEqually;
    row.spacing = 8;
    [row addArrangedSubview:reset];
    [row addArrangedSubview:camera];
    [self addFullWidthView:row toSection:section];

    return section;
}

- (NSSlider *)makeSliderWithValue:(CGFloat)value
                              min:(CGFloat)minValue
                              max:(CGFloat)maxValue
                           action:(SEL)action
{
    NSSlider *slider = [NSSlider sliderWithValue:value
                                        minValue:minValue
                                        maxValue:maxValue
                                          target:self
                                          action:action];
    slider.continuous = YES;
    slider.controlSize = NSControlSizeSmall;
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    return slider;
}

- (void)addSliderRow:(NSString *)key
               title:(NSString *)title
              slider:(NSSlider *)slider
           formatter:(NSString *(^)(CGFloat))formatter
               toSection:(NSStackView *)section
{
    SKOSliderRow *row = [[SKOSliderRow alloc] initWithTitle:title
                                                     slider:slider
                                                  formatter:formatter];
    self.sliderRows[key] = row;
    [self addFullWidthView:row toSection:section];
}

- (NSView *)buildDetectorSection
{
    NSStackView *section = [self verticalSection];
    [self addFullWidthView:SKOSectionTitle(@"DETECTOR") toSection:section];

    self.waterSlider = [self makeSliderWithValue:1.0 min:0.0 max:1.0
                                           action:@selector(waterChanged:)];
    self.waterSlider.identifier = @"waterSlider";
    [self addSliderRow:@"water" title:@"Water fill" slider:self.waterSlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.0f %%", value * 100.0];
    } toSection:section];

    self.fiducialSlider = [self makeSliderWithValue:8.0 min:2.0 max:16.0
                                              action:@selector(fiducialChanged:)];
    self.fiducialSlider.identifier = @"fiducialSlider";
    [self addSliderRow:@"fiducial" title:@"Fiducial radius" slider:self.fiducialSlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.1f m", value];
    } toSection:section];

    self.transparencySlider = [self makeSliderWithValue:0.30 min:0.05 max:1.0
                                                  action:@selector(transparencyChanged:)];
    self.transparencySlider.identifier = @"transparencySlider";
    [self addSliderRow:@"transparency" title:@"Water transparency" slider:self.transparencySlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.0f %%", value * 100.0];
    } toSection:section];

    self.cutawaySlider = [self makeSliderWithValue:0.14 min:0.05 max:1.0
                                             action:@selector(cutawayChanged:)];
    self.cutawaySlider.identifier = @"cutawaySlider";
    [self addSliderRow:@"cutaway" title:@"Shell opacity" slider:self.cutawaySlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.0f %%", value * 100.0];
    } toSection:section];

    self.sensitivitySlider = [self makeSliderWithValue:1.0 min:0.0 max:2.0
                                                 action:@selector(sensitivityChanged:)];
    self.sensitivitySlider.identifier = @"sensitivitySlider";
    [self addSliderRow:@"sensitivity" title:@"PMT gain" slider:self.sensitivitySlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.2f×", value];
    } toSection:section];

    return section;
}

- (NSView *)buildMotionSection
{
    NSStackView *section = [self verticalSection];
    [self addFullWidthView:SKOSectionTitle(@"BEAM & MOTION") toSection:section];

    self.rateSlider = [self makeSliderWithValue:3.0 min:0.0 max:20.0
                                          action:@selector(rateChanged:)];
    self.rateSlider.identifier = @"rateSlider";
    [self addSliderRow:@"rate" title:@"Event rate" slider:self.rateSlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.1f /s", value];
    } toSection:section];

    self.rotationSlider = [self makeSliderWithValue:0.35 min:0.0 max:1.0
                                              action:@selector(rotationChanged:)];
    self.rotationSlider.identifier = @"rotationSlider";
    [self addSliderRow:@"rotation" title:@"Rotation speed" slider:self.rotationSlider
             formatter:^NSString *(CGFloat value) {
        return [NSString stringWithFormat:@"%.2f×", value];
    } toSection:section];

    return section;
}

- (NSView *)buildFooterView
{
    NSStackView *section = [self verticalSection];
    section.spacing = 4;
    NSView *divider = SKODivider();
    [self addFullWidthView:divider toSection:section];

    NSTextField *line1 = SKOMakeLabel(@"11,129 ID PMTs  ·  1,885 OD PMTs", 9.5,
                                       NSFontWeightRegular, SKOTextSecondary());
    line1.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"11,129 ID PMTs  ·  1,885 OD PMTs"
            attributes:@{
                NSFontAttributeName: [NSFont monospacedDigitSystemFontOfSize:9.5
                                                                      weight:NSFontWeightRegular],
                NSForegroundColorAttributeName: SKOTextSecondary(),
            }];
    [self addFullWidthView:line1 toSection:section];

    NSTextField *line2 = SKOMakeLabel(@"50,000 t ultra-pure water  ·  1,000 m overburden",
                                      9.0, NSFontWeightRegular, SKOTextFaint());
    [self addFullWidthView:line2 toSection:section];

    return section;
}

- (void)buildSceneView
{
    SKOSceneView *sceneView = [[SKOSceneView alloc] initWithFrame:NSZeroRect];
    sceneView.translatesAutoresizingMaskIntoConstraints = NO;
    sceneView.scene = self.scene;
    sceneView.backgroundColor = [NSColor blackColor];
    sceneView.antialiasingMode = SCNAntialiasingModeMultisampling4X;
    sceneView.preferredFramesPerSecond = 60;
    sceneView.rendersContinuously = YES;
    sceneView.allowsCameraControl = NO;
    sceneView.autoenablesDefaultLighting = NO;
    sceneView.pointOfView = self.cameraNode;
    self.sceneView = sceneView;

    __weak typeof(self) weakSelf = self;
    sceneView.orbitBlock = ^(CGFloat dx, CGFloat dy) {
        ViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.cameraAzimuth -= dx * 0.007;
        strongSelf.cameraElevation = MIN(MAX(strongSelf.cameraElevation + dy * 0.006, -0.10), 1.15);
        [strongSelf updateCamera];
    };
    sceneView.zoomBlock = ^(CGFloat factor) {
        ViewController *strongSelf = weakSelf;
        if (!strongSelf) return;
        strongSelf.cameraDistance = MIN(MAX(strongSelf.cameraDistance * factor, 68.0), 185.0);
        [strongSelf updateCamera];
    };
    sceneView.doubleClickBlock = ^{
        [weakSelf centerModel:nil];
    };

    [self.view addSubview:sceneView];
    [NSLayoutConstraint activateConstraints:@[
        [sceneView.leadingAnchor constraintEqualToAnchor:self.sidebar.trailingAnchor],
        [sceneView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [sceneView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [sceneView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)updateCamera
{
    if (!self.cameraNode || !self.lookTarget) return;
    CGFloat cosine = cos(self.cameraElevation);
    SCNVector3 target = self.lookTarget.position;
    self.cameraNode.position = SCNVector3Make(
        target.x + self.cameraDistance * cosine * sin(self.cameraAzimuth),
        target.y + self.cameraDistance * sin(self.cameraElevation),
        target.z + self.cameraDistance * cosine * cos(self.cameraAzimuth));
}

#pragma mark - Overlay UI

- (void)buildHUDPanel
{
    NSVisualEffectView *hud = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    hud.translatesAutoresizingMaskIntoConstraints = NO;
    hud.material = NSVisualEffectMaterialHUDWindow;
    hud.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    hud.state = NSVisualEffectStateActive;
    SKOStyleGlassPanel(hud, 13.0);
    [self.sceneView addSubview:hud];
    self.hudPanel = hud;

    NSView *tint = [[NSView alloc] initWithFrame:NSZeroRect];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.wantsLayer = YES;
    tint.layer.backgroundColor = SKOColor(0.0, 0.0, 0.0, 0.34).CGColor;
    [hud addSubview:tint];

    NSView *dot = [[NSView alloc] initWithFrame:NSZeroRect];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.wantsLayer = YES;
    dot.layer.cornerRadius = 4.0;
    dot.layer.backgroundColor = SKOColor(0.22, 0.92, 0.55, 1.0).CGColor;
    dot.layer.shadowColor = SKOColor(0.22, 0.92, 0.55, 1.0).CGColor;
    dot.layer.shadowOpacity = 0.8;
    dot.layer.shadowRadius = 6;
    dot.layer.shadowOffset = NSMakeSize(0, 0);
    [hud addSubview:dot];
    self.hudStatusDot = dot;

    self.hudStatusLabel = SKOMakeLabel(@"DETECTOR ONLINE", 10.0, NSFontWeightSemibold,
                                       SKOColor(0.59, 0.95, 0.73, 1.0));
    self.hudStatusLabel.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"DETECTOR ONLINE"
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:10.0 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: SKOColor(0.59, 0.95, 0.73, 1.0),
                NSKernAttributeName: @1.0,
            }];
    [hud addSubview:self.hudStatusLabel];

    self.hudEventLabel = SKOMakeLabel(@"0", 34.0, NSFontWeightBold, SKOTextPrimary());
    self.hudEventLabel.font = [NSFont monospacedDigitSystemFontOfSize:34.0
                                                               weight:NSFontWeightBold];
    [hud addSubview:self.hudEventLabel];

    NSTextField *caption = SKOMakeLabel(@"EVENTS RECORDED", 9.0, NSFontWeightSemibold,
                                        SKOTextFaint());
    caption.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"EVENTS RECORDED"
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:9.0 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: SKOTextFaint(),
                NSKernAttributeName: @0.8,
            }];
    [hud addSubview:caption];

    self.hudDetailLabel = SKOMakeLabel(@"Awaiting first event", 11.0, NSFontWeightRegular,
                                        SKOTextSecondary());
    [hud addSubview:self.hudDetailLabel];

    NSView *divider = SKODivider();
    [hud addSubview:divider];

    self.hudEnvLabel = SKOMakeLabel(@"Water 12.0 °C  ·  Fiducial 8.0 m", 9.8,
                                    NSFontWeightRegular, SKOTextFaint());
    [hud addSubview:self.hudEnvLabel];

    [NSLayoutConstraint activateConstraints:@[
        [hud.leadingAnchor constraintEqualToAnchor:self.sceneView.leadingAnchor constant:16],
        [hud.topAnchor constraintEqualToAnchor:self.sceneView.topAnchor constant:16],
        [hud.widthAnchor constraintEqualToConstant:304],

        [tint.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor],
        [tint.trailingAnchor constraintEqualToAnchor:hud.trailingAnchor],
        [tint.topAnchor constraintEqualToAnchor:hud.topAnchor],
        [tint.bottomAnchor constraintEqualToAnchor:hud.bottomAnchor],

        [dot.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor constant:16],
        [dot.topAnchor constraintEqualToAnchor:hud.topAnchor constant:15],
        [dot.widthAnchor constraintEqualToConstant:8],
        [dot.heightAnchor constraintEqualToConstant:8],

        [self.hudStatusLabel.leadingAnchor constraintEqualToAnchor:dot.trailingAnchor constant:8],
        [self.hudStatusLabel.centerYAnchor constraintEqualToAnchor:dot.centerYAnchor],

        [self.hudEventLabel.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor constant:16],
        [self.hudEventLabel.topAnchor constraintEqualToAnchor:self.hudStatusLabel.bottomAnchor
                                                      constant:5],
        [caption.leadingAnchor constraintEqualToAnchor:self.hudEventLabel.trailingAnchor
                                               constant:7],
        [caption.firstBaselineAnchor constraintEqualToAnchor:self.hudEventLabel.firstBaselineAnchor],

        [self.hudDetailLabel.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor constant:16],
        [self.hudDetailLabel.trailingAnchor constraintEqualToAnchor:hud.trailingAnchor constant:-16],
        [self.hudDetailLabel.topAnchor constraintEqualToAnchor:self.hudEventLabel.bottomAnchor
                                                       constant:0],

        [divider.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor constant:16],
        [divider.trailingAnchor constraintEqualToAnchor:hud.trailingAnchor constant:-16],
        [divider.topAnchor constraintEqualToAnchor:self.hudDetailLabel.bottomAnchor constant:9],
        [divider.heightAnchor constraintEqualToConstant:1],

        [self.hudEnvLabel.leadingAnchor constraintEqualToAnchor:hud.leadingAnchor constant:16],
        [self.hudEnvLabel.trailingAnchor constraintEqualToAnchor:hud.trailingAnchor constant:-16],
        [self.hudEnvLabel.topAnchor constraintEqualToAnchor:divider.bottomAnchor constant:7],
        [self.hudEnvLabel.bottomAnchor constraintEqualToAnchor:hud.bottomAnchor constant:-13],
    ]];
}

- (SKOFlatButton *)overlayButtonWithTitle:(NSString *)title
                                   symbol:(NSString *)symbol
                                   action:(SEL)action
                               identifier:(NSString *)identifier
{
    SKOFlatButton *button = [[SKOFlatButton alloc] initWithFrame:NSZeroRect];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.contentPadding = 8;
    [button setStyledTitle:title symbol:symbol];
    button.target = self;
    button.action = action;
    button.identifier = identifier;
    button.accessibilityLabel = title;
    [button.heightAnchor constraintEqualToConstant:29].active = YES;
    return button;
}

- (void)buildViewControls
{
    NSVisualEffectView *bar = [[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
    bar.translatesAutoresizingMaskIntoConstraints = NO;
    bar.material = NSVisualEffectMaterialHUDWindow;
    bar.blendingMode = NSVisualEffectBlendingModeBehindWindow;
    bar.state = NSVisualEffectStateActive;
    SKOStyleGlassPanel(bar, 10.0);
    [self.sceneView addSubview:bar];

    NSView *tint = [[NSView alloc] initWithFrame:NSZeroRect];
    tint.translatesAutoresizingMaskIntoConstraints = NO;
    tint.wantsLayer = YES;
    tint.layer.backgroundColor = SKOColor(0.0, 0.0, 0.0, 0.30).CGColor;
    [bar addSubview:tint];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 3;
    [bar addSubview:row];

    self.centerButton = [self overlayButtonWithTitle:@"Center" symbol:@"viewfinder"
                                              action:@selector(centerModel:)
                                          identifier:@"centerButton"];
    self.cutawayButton = [self overlayButtonWithTitle:@"Cutaway"
                                               symbol:@"circle.lefthalf.filled"
                                               action:@selector(toggleCutaway:)
                                           identifier:@"cutawayButton"];
    self.rotateButton = [self overlayButtonWithTitle:@"Rotate"
                                              symbol:@"arrow.triangle.2.circlepath"
                                              action:@selector(toggleRotate:)
                                          identifier:@"rotateButton"];
    self.explodeButton = [self overlayButtonWithTitle:@"Explode"
                                               symbol:@"arrow.up.left.and.arrow.down.right"
                                               action:@selector(toggleExplode:)
                                           identifier:@"explodeButton"];
    self.labelsButton = [self overlayButtonWithTitle:@"Labels"
                                              symbol:@"tag"
                                              action:@selector(toggleLabels:)
                                          identifier:@"labelsButton"];

    SKOFlatButton *help = [self overlayButtonWithTitle:@"Help"
                                                symbol:@"questionmark.circle"
                                                action:@selector(showHelp:)
                                            identifier:@"helpButton"];
    help.toolTip = @"Super-Kamiokande Help (⌘?)";
    help.accessibilityLabel = @"Super-Kamiokande Help";
    self.helpButton = help;

    NSArray<SKOFlatButton *> *overlayButtons = @[
        self.centerButton, self.cutawayButton, self.rotateButton,
        self.explodeButton, self.labelsButton, help,
    ];
    for (SKOFlatButton *button in overlayButtons) {
        [button.widthAnchor constraintEqualToConstant:kOverlayButtonWidth].active = YES;
    }

    for (SKOFlatButton *button in @[self.centerButton, self.cutawayButton,
                                    self.rotateButton, self.explodeButton,
                                    self.labelsButton]) {
        [row addArrangedSubview:button];
    }

    NSView *separator = [[NSView alloc] initWithFrame:NSZeroRect];
    separator.translatesAutoresizingMaskIntoConstraints = NO;
    separator.wantsLayer = YES;
    separator.layer.backgroundColor = SKOColor(1.0, 1.0, 1.0, 0.12).CGColor;
    [separator.widthAnchor constraintEqualToConstant:1.0].active = YES;
    [separator.heightAnchor constraintEqualToConstant:17.0].active = YES;
    [row addArrangedSubview:separator];
    [row addArrangedSubview:help];

    [NSLayoutConstraint activateConstraints:@[
        [bar.trailingAnchor constraintEqualToAnchor:self.sceneView.trailingAnchor constant:-16],
        [bar.topAnchor constraintEqualToAnchor:self.sceneView.topAnchor constant:16],
        [tint.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor],
        [tint.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor],
        [tint.topAnchor constraintEqualToAnchor:bar.topAnchor],
        [tint.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor],
        [row.leadingAnchor constraintEqualToAnchor:bar.leadingAnchor constant:5],
        [row.trailingAnchor constraintEqualToAnchor:bar.trailingAnchor constant:-5],
        [row.topAnchor constraintEqualToAnchor:bar.topAnchor constant:4],
        [row.bottomAnchor constraintEqualToAnchor:bar.bottomAnchor constant:-4],
    ]];

    SKOFlatButton *reveal = [[SKOFlatButton alloc] initWithFrame:NSZeroRect];
    reveal.translatesAutoresizingMaskIntoConstraints = NO;
    reveal.contentPadding = 8;
    reveal.fillColor = SKOColor(0.05, 0.32, 0.38, 0.90);
    reveal.hoverFillColor = SKOColor(0.07, 0.44, 0.51, 0.95);
    reveal.strokeColor = SKOColor(0.28, 0.88, 0.94, 0.55);
    [reveal setStyledTitle:@"Controls" symbol:@"sidebar.right"];
    reveal.target = self;
    reveal.action = @selector(toggleSidebar:);
    reveal.identifier = @"sidebarRevealButton";
    reveal.toolTip = @"Show controls";
    reveal.accessibilityLabel = @"Show controls";
    reveal.hidden = YES;
    [self.sceneView addSubview:reveal];
    self.revealButton = reveal;
    self.sidebarRevealButton = reveal;

    self.revealTopConstraint = [reveal.topAnchor constraintEqualToAnchor:self.hudPanel.bottomAnchor
                                                                constant:12];
    [NSLayoutConstraint activateConstraints:@[
        [reveal.leadingAnchor constraintEqualToAnchor:self.sceneView.leadingAnchor constant:16],
        self.revealTopConstraint,
        [reveal.widthAnchor constraintEqualToConstant:kOverlayButtonWidth],
        [reveal.heightAnchor constraintEqualToConstant:31],
    ]];
    [self.view layoutSubtreeIfNeeded];

    ((SKOFlatButton *)self.cutawayButton).active = self.cutawayOn;
    ((SKOFlatButton *)self.rotateButton).active = self.autoRotate;
    ((SKOFlatButton *)self.explodeButton).active = self.exploded;
    ((SKOFlatButton *)self.labelsButton).active = self.labelsVisible;
}

- (void)updateSidebarRevealPosition
{
    if (self.revealButton) {
        self.revealButton.hidden = self.sidebarVisible;
    }
}

#pragma mark - Labels

- (void)buildLabels
{
    SKOPassthroughView *overlay = [[SKOPassthroughView alloc] initWithFrame:NSZeroRect];
    overlay.translatesAutoresizingMaskIntoConstraints = NO;
    overlay.wantsLayer = YES;
    overlay.layer.masksToBounds = YES;
    [self.sceneView addSubview:overlay];
    [NSLayoutConstraint activateConstraints:@[
        [overlay.leadingAnchor constraintEqualToAnchor:self.sceneView.leadingAnchor],
        [overlay.trailingAnchor constraintEqualToAnchor:self.sceneView.trailingAnchor],
        [overlay.topAnchor constraintEqualToAnchor:self.sceneView.topAnchor],
        [overlay.bottomAnchor constraintEqualToAnchor:self.sceneView.bottomAnchor],
    ]];
    self.labelsOverlay = overlay;

    self.leaderLayer = [CAShapeLayer layer];
    self.leaderLayer.fillColor = [NSColor clearColor].CGColor;
    self.leaderLayer.strokeColor = SKOColor(1.0, 1.0, 1.0, 0.30).CGColor;
    self.leaderLayer.lineWidth = 1.0;
    self.leaderLayer.lineCap = kCALineCapRound;
    [overlay.layer addSublayer:self.leaderLayer];

    self.anchorLayer = [CAShapeLayer layer];
    self.anchorLayer.fillColor = SKOColor(0.70, 0.95, 1.0, 0.95).CGColor;
    self.anchorLayer.strokeColor = [NSColor clearColor].CGColor;
    [overlay.layer addSublayer:self.anchorLayer];

    [self addLabelSpecWithTitle:@"Stainless-steel tank"
                         detail:@"41.4 m high  ·  39.3 m diameter"
                      groupName:@"shell"
                    localAnchor:SCNVector3Make(-19.0, 32.0, 6.0)
                         column:0 slot:0
                    accentColor:SKOColor(0.58, 0.73, 0.88, 1.0)];
    [self addLabelSpecWithTitle:@"Ultra-pure water"
                         detail:@"50,000 t  ·  11 m deep"
                      groupName:@"water"
                    localAnchor:SCNVector3Make(0, 34.0, 16.0)
                         column:0 slot:1
                    accentColor:SKOColor(0.24, 0.62, 1.0, 1.0)];
    [self addLabelSpecWithTitle:@"Access tunnel"
                         detail:@"service gallery  ·  1,000 m rock"
                      groupName:@"tunnel"
                    localAnchor:SCNVector3Make(-30.0, 38.2, 4.6)
                         column:0 slot:2
                    accentColor:SKOColor(0.58, 0.62, 0.68, 1.0)];

    [self addLabelSpecWithTitle:@"Control room"
                         detail:@"data acquisition  ·  shift deck"
                      groupName:@"facility"
                    localAnchor:SCNVector3Make(33.0, 45.0, -12.9)
                         column:1 slot:0
                    accentColor:SKOColor(0.30, 0.82, 1.0, 1.0)];
    [self addLabelSpecWithTitle:@"Top dome access"
                         detail:@"service shaft  ·  ladder"
                      groupName:@"facility"
                    localAnchor:SCNVector3Make(10.0, 47.2, -7.0)
                         column:1 slot:1
                    accentColor:SKOColor(0.75, 0.80, 0.86, 1.0)];
    [self addLabelSpecWithTitle:@"Inner detector"
                         detail:@"11,129  ×  20-inch PMTs"
                      groupName:@"wallPMT"
                    localAnchor:SCNVector3Make(6.0, 22.0, 18.5)
                         column:1 slot:2
                    accentColor:SKOColor(0.95, 0.74, 0.30, 1.0)];
    [self addLabelSpecWithTitle:@"Outer detector"
                         detail:@"1,885  ×  8-inch PMTs"
                      groupName:@"outerPMT"
                    localAnchor:SCNVector3Make(20.5, 30.0, 12.0)
                         column:1 slot:3
                    accentColor:SKOColor(0.80, 0.65, 0.32, 1.0)];
    [self addLabelSpecWithTitle:@"Fiducial volume"
                         detail:@"22.5 kt  ·  event vertex region"
                      groupName:@"fiducial"
                    localAnchor:SCNVector3Make(0, 19.0, 8.0)
                         column:1 slot:4
                    accentColor:SKOColor(0.25, 0.95, 0.48, 1.0)];

    [self addLabelSpecWithTitle:@"Water purification"
                         detail:@"ultra-pure loop  ·  readout"
                      groupName:@"facility"
                    localAnchor:SCNVector3Make(28.0, 3.1, 13.0)
                         column:2 slot:0
                    accentColor:SKOColor(0.22, 0.80, 0.76, 1.0)];

    for (SKOLabelPillView *pill in self.labelPills) {
        [overlay addSubview:pill];
    }
    self.labelsOverlay.hidden = !self.labelsVisible;
}

- (void)addLabelSpecWithTitle:(NSString *)title
                        detail:(NSString *)detail
                     groupName:(NSString *)groupName
                   localAnchor:(SCNVector3)anchor
                        column:(NSInteger)column
                          slot:(NSInteger)slot
                   accentColor:(NSColor *)accent
{
    SKOLabelSpec *spec = [[SKOLabelSpec alloc] init];
    spec.title = title;
    spec.detail = detail;
    spec.groupName = groupName;
    spec.localAnchor = anchor;
    spec.column = column;
    spec.slot = slot;
    spec.accentColor = accent;
    [self.labelSpecs addObject:spec];

    SKOLabelPillView *pill = [[SKOLabelPillView alloc]
        initWithFrame:NSMakeRect(0, 0, kLabelWidth, kLabelHeight)];
    [pill setTitle:title detail:detail];
    pill.accentColor = accent;
    [self.labelPills addObject:pill];
}

- (void)updateLabelPositions
{
    if (!self.labelsVisible || !self.labelsOverlay || !self.labelsOverlay.window) return;

    NSSize size = self.labelsOverlay.bounds.size;
    if (size.width < 10 || size.height < 10) return;

    CGMutablePathRef leaderPath = CGPathCreateMutable();
    CGMutablePathRef anchorPath = CGPathCreateMutable();
    SCNVector3 cameraPosition = self.cameraNode.worldPosition;
    SCNVector3 forward = self.cameraNode.worldFront;

    for (NSUInteger i = 0; i < self.labelSpecs.count; ++i) {
        SKOLabelSpec *spec = self.labelSpecs[i];
        SKOLabelPillView *pill = self.labelPills[i];

        SCNNode *groupNode = spec.groupName.length > 0
            ? [self.rootGroup childNodeWithName:spec.groupName recursively:YES] : nil;
        if (!groupNode) {
            pill.hidden = YES;
            continue;
        }
        SCNVector3 world = [groupNode convertPosition:spec.localAnchor toNode:self.scene.rootNode];
        SCNVector3 toPoint = SCNVector3Make(world.x - cameraPosition.x,
                                            world.y - cameraPosition.y,
                                            world.z - cameraPosition.z);
        CGFloat facing = toPoint.x * forward.x + toPoint.y * forward.y + toPoint.z * forward.z;
        if (facing <= 0.5) {
            pill.hidden = YES;
            continue;
        }
        SCNVector3 projected = [self.sceneView projectPoint:world];
        if (projected.x < -40 || projected.x > size.width + 40 ||
            projected.y < -40 || projected.y > size.height + 40) {
            pill.hidden = YES;
            continue;
        }

        CGFloat x;
        CGFloat y;
        if (spec.column == 0) {
            x = 22.0;
            y = size.height * 0.60 - spec.slot * 52.0;
        } else if (spec.column == 1) {
            x = size.width - kLabelWidth - 22.0;
            y = size.height * 0.66 - spec.slot * 52.0;
        } else {
            x = (size.width - kLabelWidth) / 2.0;
            y = 18.0;
        }
        y = MIN(MAX(y, 16.0), size.height - kLabelHeight - 16.0);
        pill.frame = NSMakeRect(round(x), round(y), kLabelWidth, kLabelHeight);
        pill.hidden = NO;

        CGFloat attachX = MIN(MAX(projected.x, NSMinX(pill.frame)), NSMaxX(pill.frame));
        CGFloat attachY = MIN(MAX(projected.y, NSMinY(pill.frame)), NSMaxY(pill.frame));
        CGPathMoveToPoint(leaderPath, NULL, projected.x, projected.y);
        CGPathAddLineToPoint(leaderPath, NULL, attachX, attachY);
        CGPathAddEllipseInRect(anchorPath, NULL,
                               CGRectMake(projected.x - 2.6, projected.y - 2.6, 5.2, 5.2));
    }

    self.leaderLayer.path = leaderPath;
    self.anchorLayer.path = anchorPath;
    CGPathRelease(leaderPath);
    CGPathRelease(anchorPath);
}

#pragma mark - HUD / readouts

- (void)startHUDTimer
{
    [self.hudTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.hudTimer = [NSTimer timerWithTimeInterval:0.5
                                           repeats:YES
                                             block:^(NSTimer *timer) {
        (void)timer;
        [weakSelf refreshHUD];
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.hudTimer forMode:NSRunLoopCommonModes];
}

- (NSString *)formattedEventCount:(NSUInteger)count
{
    static NSNumberFormatter *formatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        formatter.usesGroupingSeparator = YES;
    });
    return [formatter stringFromNumber:@(count)] ?: @"0";
}

- (void)refreshHUD
{
    if (!self.engine) return;
    BOOL running = self.engine.running;
    self.hudEventLabel.stringValue = [self formattedEventCount:self.engine.totalEvents];
    self.hudStatusLabel.stringValue = running ? @"DETECTOR ONLINE" : @"DETECTOR PAUSED";
    NSColor *statusColor = running ? SKOColor(0.59, 0.95, 0.73, 1.0)
                                   : SKOColor(1.0, 0.76, 0.30, 1.0);
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    self.hudStatusLabel.attributedStringValue = [[NSAttributedString alloc]
        initWithString:self.hudStatusLabel.stringValue
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:10.0 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: statusColor,
                NSKernAttributeName: @1.0,
                NSParagraphStyleAttributeName: style,
            }];
    self.hudStatusDot.layer.backgroundColor = statusColor.CGColor;
    self.hudStatusDot.layer.shadowColor = statusColor.CGColor;

    if (self.lastEnergyGeV > 0.0) {
        self.hudDetailLabel.stringValue = [NSString stringWithFormat:@"Last event  ·  %.1f GeV %@",
                                           self.lastEnergyGeV, SKOEventKindSymbol(self.lastKind)];
    } else {
        self.hudDetailLabel.stringValue = @"Awaiting first event";
    }
    self.hudEnvLabel.stringValue = [NSString stringWithFormat:
        @"Water %.2f °C  ·  Fiducial %.1f m  ·  %.1f events/s",
        self.engine.waterTemperatureCelsius, self.engine.fiducialRadius,
        self.engine.eventRate];

    if (running) {
        self.statusLabel.stringValue = [NSString stringWithFormat:
            @"Running · %.1f events/s", self.engine.eventRate];
    } else {
        self.statusLabel.stringValue = @"Paused · detector idle";
    }
}

- (void)refreshAllReadouts
{
    [self refreshHUD];
    for (SKOSliderRow *row in self.sliderRows.allValues) {
        [row refreshValue];
    }
    [self refreshToggleButtons];
}

- (void)refreshToggleButtons
{
    ((SKOFlatButton *)self.cutawayButton).active = self.cutawayOn;
    ((SKOFlatButton *)self.rotateButton).active = self.autoRotate;
    ((SKOFlatButton *)self.explodeButton).active = self.exploded;
    ((SKOFlatButton *)self.labelsButton).active = self.labelsVisible;
}

- (void)engineDidSpawnEventWithEnergy:(CGFloat)energyGeV
                                 kind:(SKOEventKind)kind
                             ringNode:(SCNNode *)ringNode
                          totalEvents:(NSUInteger)total
{
    (void)ringNode;
    self.lastEnergyGeV = energyGeV;
    self.lastKind = kind;
    self.hudEventLabel.stringValue = [self formattedEventCount:total];
    self.hudDetailLabel.stringValue = [NSString stringWithFormat:@"Last event  ·  %.1f GeV %@",
                                       energyGeV, SKOEventKindSymbol(kind)];
    self.hudEnvLabel.stringValue = [NSString stringWithFormat:
        @"Water %.2f °C  ·  Fiducial %.1f m  ·  %.1f events/s",
        self.engine.waterTemperatureCelsius, self.engine.fiducialRadius,
        self.engine.eventRate];
}

#pragma mark - Actions

- (void)toggleRun:(id)sender
{
    (void)sender;
    if (self.engine.running) {
        [self.engine stop];
    } else {
        [self.engine start];
    }
    [self refreshHUD];
    if (self.engine.running) {
        [(SKOFlatButton *)self.runButton setStyledTitle:@"Pause simulation" symbol:@"pause.fill"];
    } else {
        [(SKOFlatButton *)self.runButton setStyledTitle:@"Resume simulation" symbol:@"play.fill"];
    }
}

- (void)resetCounter:(id)sender
{
    (void)sender;
    [self.engine resetCount];
    self.lastEnergyGeV = 0.0;
    [self refreshHUD];
}

- (void)resetCamera:(id)sender
{
    [self centerModel:sender];
}

- (void)centerModel:(id)sender
{
    (void)sender;
    self.cameraAzimuth = 0.70;
    self.cameraElevation = 0.24;
    self.cameraDistance = 100.0;
    [self updateCamera];
    [self updateLabelPositions];
}

- (void)toggleCutaway:(id)sender
{
    (void)sender;
    self.cutawayOn = !self.cutawayOn;
    CGFloat opacity = self.cutawayOn ? 0.14 : 0.92;
    [SKOTankBuilder setShellOpacity:opacity rootNode:self.rootGroup];
    self.cutawaySlider.doubleValue = opacity;
    [self refreshAllReadouts];
}

- (void)toggleRotate:(id)sender
{
    (void)sender;
    self.autoRotate = !self.autoRotate;
    if (self.autoRotate) {
        [self startRotateTimer];
    } else {
        [self.rotateTimer invalidate];
        self.rotateTimer = nil;
    }
    [self refreshToggleButtons];
}

- (void)toggleExplode:(id)sender
{
    (void)sender;
    self.exploded = !self.exploded;
    [SCNTransaction begin];
    [SCNTransaction setAnimationDuration:0.55];
    [SKOTankBuilder setExplodeAmount:self.exploded ? 1.0 : 0.0
                            rootNode:self.rootGroup];
    [SCNTransaction commit];
    [self refreshToggleButtons];
}

- (void)toggleLabels:(id)sender
{
    (void)sender;
    self.labelsVisible = !self.labelsVisible;
    self.labelsOverlay.hidden = !self.labelsVisible;
    if (self.labelsVisible) {
        [self updateLabelPositions];
    }
    [self refreshToggleButtons];
}

- (void)showHelp:(id)sender
{
    if (!self.helpWindowController) {
        self.helpWindowController = [[SKOHelpWindowController alloc] init];
    }
    [self.helpWindowController showRelativeToWindow:self.view.window];
}

- (void)toggleSidebar:(id)sender
{
    (void)sender;
    self.sidebarVisible = !self.sidebarVisible;
    BOOL show = self.sidebarVisible;
    CGFloat newLeading = show ? 0.0 : -kSidebarExpandedWidth;
    self.revealButton.hidden = show;

    // Slide the whole sidebar offscreen instead of shrinking it to width 0.
    // Its internal stack keeps its natural width, so Auto Layout has no
    // zero-width conflicts, and the scene view expands into the gap.
    if (self.view.window) {
        if (show) {
            self.sidebar.hidden = NO;
        }
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            context.duration = 0.24;
            context.timingFunction =
                [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
            context.allowsImplicitAnimation = YES;
            self.sidebarLeadingConstraint.constant = newLeading;
            [self.view layoutSubtreeIfNeeded];
        } completionHandler:^{
            self.sidebar.hidden = !show;
            [self updateLabelPositions];
        }];
    } else {
        self.sidebarLeadingConstraint.constant = newLeading;
        self.sidebar.hidden = !show;
        [self.view layoutSubtreeIfNeeded];
    }

    self.sidebarCollapseButton.toolTip = show ? @"Hide controls" : @"Show controls";
}

- (void)waterChanged:(NSSlider *)sender
{
    [SKOTankBuilder setWaterFill:sender.doubleValue rootNode:self.rootGroup];
    [self refreshAllReadouts];
}

- (void)fiducialChanged:(NSSlider *)sender
{
    [SKOTankBuilder setFiducialRadius:sender.doubleValue rootNode:self.rootGroup];
    self.engine.fiducialRadius = sender.doubleValue;
    [self refreshAllReadouts];
}

- (void)transparencyChanged:(NSSlider *)sender
{
    [SKOTankBuilder setWaterTransparency:sender.doubleValue rootNode:self.rootGroup];
    [self refreshAllReadouts];
}

- (void)cutawayChanged:(NSSlider *)sender
{
    [SKOTankBuilder setShellOpacity:sender.doubleValue rootNode:self.rootGroup];
    self.cutawayOn = sender.doubleValue < 0.55;
    [self refreshAllReadouts];
}

- (void)sensitivityChanged:(NSSlider *)sender
{
    self.engine.pmtSensitivity = sender.doubleValue;
    [self refreshAllReadouts];
}

- (void)rateChanged:(NSSlider *)sender
{
    self.engine.eventRate = sender.doubleValue;
    [self refreshAllReadouts];
}

- (void)rotationChanged:(NSSlider *)sender
{
    self.autoRotateSpeed = sender.doubleValue;
    [self refreshAllReadouts];
}

#pragma mark - Auto rotation

- (void)startRotateTimer
{
    [self.rotateTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.rotateTimer = [NSTimer timerWithTimeInterval:1.0 / 60.0
                                               repeats:YES
                                                 block:^(NSTimer *timer) {
        (void)timer;
        ViewController *strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.autoRotate) return;
        CGFloat radians = strongSelf.autoRotateSpeed * 0.80 / 60.0;
        SCNVector3 angles = strongSelf.rootGroup.eulerAngles;
        angles.y += radians;
        strongSelf.rootGroup.eulerAngles = angles;
    }];
    [[NSRunLoop mainRunLoop] addTimer:self.rotateTimer forMode:NSRunLoopCommonModes];
}

@end
