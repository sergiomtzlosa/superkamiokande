#import "SKOHelpWindowController.h"

#pragma mark - Local palette / label helpers

static NSColor *SKOHelpColor(CGFloat r, CGFloat g, CGFloat b, CGFloat a)
{
    return [NSColor colorWithSRGBRed:r green:g blue:b alpha:a];
}

static NSColor *SKOHelpPrimary(void)
{
    return SKOHelpColor(0.94, 0.96, 0.98, 1.0);
}

static NSColor *SKOHelpSecondary(void)
{
    return SKOHelpColor(0.62, 0.68, 0.75, 1.0);
}

static NSColor *SKOHelpFaint(void)
{
    return SKOHelpColor(0.40, 0.46, 0.54, 1.0);
}

static NSColor *SKOHelpAccent(void)
{
    return SKOHelpColor(0.16, 0.83, 0.90, 1.0);
}

static NSTextField *SKOHelpLabelWithAttributedString(NSAttributedString *text, BOOL wraps)
{
    NSTextField *label = [NSTextField labelWithString:@""];
    label.attributedStringValue = text;
    label.maximumNumberOfLines = wraps ? 0 : 1;
    label.lineBreakMode = wraps ? NSLineBreakByWordWrapping : NSLineBreakByTruncatingTail;
    label.usesSingleLineMode = !wraps;
    label.selectable = wraps;
    label.drawsBackground = NO;
    label.bordered = NO;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    if (wraps) {
        label.preferredMaxLayoutWidth = 620.0;
    }
    return label;
}

static NSTextField *SKOHelpLabel(NSString *text,
                                 CGFloat size,
                                 NSFontWeight weight,
                                 NSColor *color,
                                 BOOL wraps)
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = wraps ? 2.0 : 0.0;
    NSAttributedString *string = [[NSAttributedString alloc]
        initWithString:text ?: @""
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:size weight:weight],
                NSForegroundColorAttributeName: color,
                NSParagraphStyleAttributeName: style,
            }];
    return SKOHelpLabelWithAttributedString(string, wraps);
}

static NSTextField *SKOHelpBody(NSString *text)
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 2.3;
    NSAttributedString *string = [[NSAttributedString alloc]
        initWithString:text ?: @""
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:12.2 weight:NSFontWeightRegular],
                NSForegroundColorAttributeName: SKOHelpSecondary(),
                NSParagraphStyleAttributeName: style,
            }];
    return SKOHelpLabelWithAttributedString(string, YES);
}

static NSTextField *SKOHelpRichLabel(NSString *title, NSString *detail)
{
    NSMutableParagraphStyle *style = [[NSMutableParagraphStyle alloc] init];
    style.lineSpacing = 2.3;
    NSMutableAttributedString *string = [[NSMutableAttributedString alloc]
        initWithString:title ?: @""
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:12.2 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: SKOHelpPrimary(),
                NSParagraphStyleAttributeName: style,
            }];
    if (detail.length > 0) {
        [string appendAttributedString:[[NSAttributedString alloc]
            initWithString:[@"\n" stringByAppendingString:detail]
                attributes:@{
                    NSFontAttributeName: [NSFont systemFontOfSize:11.8
                                                       weight:NSFontWeightRegular],
                    NSForegroundColorAttributeName: SKOHelpSecondary(),
                    NSParagraphStyleAttributeName: style,
                }]];
    }
    return SKOHelpLabelWithAttributedString(string, YES);
}

static NSView *SKOHelpDivider(void)
{
    NSView *view = [[NSView alloc] initWithFrame:NSZeroRect];
    view.translatesAutoresizingMaskIntoConstraints = NO;
    view.wantsLayer = YES;
    view.layer.backgroundColor = SKOHelpColor(1.0, 1.0, 1.0, 0.08).CGColor;
    [view.heightAnchor constraintEqualToConstant:1.0].active = YES;
    return view;
}

#pragma mark - Background / flipped document views

@interface SKOHelpBackgroundView : NSView
@end

@implementation SKOHelpBackgroundView

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSGradient *gradient = [[NSGradient alloc]
        initWithStartingColor:SKOHelpColor(0.006, 0.009, 0.014, 1.0)
                endingColor:SKOHelpColor(0.055, 0.085, 0.120, 1.0)];
    [gradient drawInRect:self.bounds angle:90];

    NSGradient *glow = [[NSGradient alloc]
        initWithColorsAndLocations:
            SKOHelpColor(0.10, 0.46, 0.56, 0.12), 0.0,
            [NSColor clearColor], 1.0,
            nil];
    [glow drawInRect:NSMakeRect(NSWidth(self.bounds) - 520.0,
                                NSHeight(self.bounds) - 330.0,
                                620.0, 420.0)
        relativeCenterPosition:NSMakePoint(0.5, 0.6)];
}

@end

@interface SKOHelpDocumentView : NSView
@end

@implementation SKOHelpDocumentView

- (BOOL)isFlipped
{
    return YES;
}

@end

#pragma mark - Help window controller

@interface SKOHelpWindowController ()
@property (nonatomic, readwrite) NSScrollView *scrollView;
@property (nonatomic, readwrite) NSTextField *titleLabel;
@end

@implementation SKOHelpWindowController

- (instancetype)init
{
    NSWindow *window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 780, 720)
                  styleMask:NSWindowStyleMaskTitled
                          | NSWindowStyleMaskClosable
                          | NSWindowStyleMaskMiniaturizable
                          | NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                       defer:NO];
    window.title = @"Super-Kamiokande Help";
    window.minSize = NSMakeSize(640, 520);
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    [window setBackgroundColor:[NSColor blackColor]];
    [window setOpaque:YES];
    [window setHasShadow:YES];
    window.releasedWhenClosed = NO;
    window.restorable = NO;
    window.tabbingMode = NSWindowTabbingModeDisallowed;

    self = [super initWithWindow:window];
    if (self) {
        [self buildInterfaceInWindow:window];
    }
    return self;
}

- (void)showRelativeToWindow:(NSWindow *)parent
{
    NSWindow *window = self.window;
    if (!window) return;

    if (parent) {
        NSRect parentFrame = parent.frame;
        NSRect frame = window.frame;
        frame.origin.x = NSMidX(parentFrame) - NSWidth(frame) / 2.0;
        frame.origin.y = NSMidY(parentFrame) - NSHeight(frame) / 2.0;

        NSScreen *screen = parent.screen ?: window.screen;
        if (screen) {
            NSRect visible = screen.visibleFrame;
            frame.origin.x = MAX(NSMinX(visible) + 20.0,
                                 MIN(frame.origin.x, NSMaxX(visible) - NSWidth(frame) - 20.0));
            frame.origin.y = MAX(NSMinY(visible) + 20.0,
                                 MIN(frame.origin.y, NSMaxY(visible) - NSHeight(frame) - 20.0));
        }
        [window setFrame:frame display:NO];
    } else {
        [window center];
    }

    [self showWindow:nil];
    [window makeKeyAndOrderFront:nil];
}

- (void)buildInterfaceInWindow:(NSWindow *)window
{
    SKOHelpBackgroundView *root =
        [[SKOHelpBackgroundView alloc] initWithFrame:window.contentView.bounds];
    window.contentView = root;

    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.wantsLayer = YES;
    header.layer.backgroundColor = SKOHelpColor(0.0, 0.0, 0.0, 0.16).CGColor;
    [root addSubview:header];

    NSImageView *iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    iconView.image = NSApp.applicationIconImage ?: [NSImage imageNamed:NSImageNameApplicationIcon];
    iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    iconView.wantsLayer = YES;
    iconView.layer.cornerRadius = 10.0;
    iconView.layer.masksToBounds = YES;
    [header addSubview:iconView];

    self.titleLabel = SKOHelpLabel(@"SUPER-KAMIOKANDE",
                                   21.0, NSFontWeightHeavy, SKOHelpPrimary(), NO);
    [header addSubview:self.titleLabel];

    NSTextField *subtitle = SKOHelpLabel(@"3D DETECTOR EXPLORER  ·  HELP",
                                         9.5, NSFontWeightSemibold, SKOHelpAccent(), NO);
    subtitle.attributedStringValue = [[NSAttributedString alloc]
        initWithString:@"3D DETECTOR EXPLORER  ·  HELP"
            attributes:@{
                NSFontAttributeName: [NSFont systemFontOfSize:9.5 weight:NSFontWeightSemibold],
                NSForegroundColorAttributeName: SKOHelpAccent(),
                NSKernAttributeName: @1.25,
            }];
    [header addSubview:subtitle];

    NSTextField *hint = SKOHelpLabel(@"⌘?  ·  REOPEN ANYTIME",
                                     9.5, NSFontWeightMedium, SKOHelpFaint(), NO);
    [header addSubview:hint];

    NSView *headerDivider = SKOHelpDivider();
    [header addSubview:headerDivider];

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:root.topAnchor],
        [header.heightAnchor constraintEqualToConstant:108.0],

        [iconView.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:28.0],
        [iconView.topAnchor constraintEqualToAnchor:header.topAnchor constant:26.0],
        [iconView.widthAnchor constraintEqualToConstant:46.0],
        [iconView.heightAnchor constraintEqualToConstant:46.0],

        [self.titleLabel.leadingAnchor constraintEqualToAnchor:iconView.trailingAnchor constant:16.0],
        [self.titleLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:28.0],
        [subtitle.leadingAnchor constraintEqualToAnchor:self.titleLabel.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:3.0],

        [hint.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-28.0],
        [hint.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-27.0],

        [headerDivider.leadingAnchor constraintEqualToAnchor:header.leadingAnchor],
        [headerDivider.trailingAnchor constraintEqualToAnchor:header.trailingAnchor],
        [headerDivider.bottomAnchor constraintEqualToAnchor:header.bottomAnchor],
    ]];

    self.scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.drawsBackground = NO;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = NO;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.horizontalScrollElasticity = NSScrollElasticityNone;
    self.scrollView.scrollerStyle = NSScrollerStyleOverlay;
    [root addSubview:self.scrollView];

    SKOHelpDocumentView *document = [[SKOHelpDocumentView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = document;

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.distribution = NSStackViewDistributionFill;
    stack.spacing = 13.0;
    [document addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [self.scrollView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],

        [document.leadingAnchor constraintEqualToAnchor:self.scrollView.contentView.leadingAnchor],
        [document.topAnchor constraintEqualToAnchor:self.scrollView.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:self.scrollView.contentView.widthAnchor],

        [stack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:28.0],
        [stack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-28.0],
        [stack.topAnchor constraintEqualToAnchor:document.topAnchor constant:22.0],
        [stack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-28.0],
    ]];

    [self addCard:[self welcomeCard] toStack:stack];
    [self addCard:[self quickStartCard] toStack:stack];
    [self addCard:[self viewportCard] toStack:stack];
    [self addCard:[self simulationCard] toStack:stack];
    [self addCard:[self sidebarCard] toStack:stack];
    [self addCard:[self detectorCard] toStack:stack];
    [self addCard:[self keyboardCard] toStack:stack];

    NSTextField *footer = SKOHelpLabel(
        @"Educational visualization. Detector dimensions and PMT counts follow the published "
        @"Super-K design; event paths, optical effects, and timing are stylized for clarity.",
        10.0, NSFontWeightRegular, SKOHelpFaint(), YES);
    footer.alignment = NSTextAlignmentCenter;
    [stack addArrangedSubview:footer];
    [footer.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
}

- (void)addCard:(NSView *)card toStack:(NSStackView *)stack
{
    [stack addArrangedSubview:card];
    [card.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
}

- (NSView *)cardWithKicker:(NSString *)kicker
                     title:(NSString *)title
                   content:(NSArray<NSView *> *)content
{
    NSView *card = [[NSView alloc] initWithFrame:NSZeroRect];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.wantsLayer = YES;
    card.layer.backgroundColor = SKOHelpColor(0.045, 0.058, 0.075, 0.82).CGColor;
    card.layer.cornerRadius = 11.0;
    card.layer.borderWidth = 1.0;
    card.layer.borderColor = SKOHelpColor(1.0, 1.0, 1.0, 0.08).CGColor;

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.distribution = NSStackViewDistributionFill;
    stack.spacing = 6.0;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16.0],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16.0],
        [stack.topAnchor constraintEqualToAnchor:card.topAnchor constant:14.0],
        [stack.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-14.0],
    ]];

    NSTextField *kickerLabel = nil;
    NSTextField *titleLabel = nil;
    if (kicker.length > 0) {
        kickerLabel = SKOHelpLabel(kicker.uppercaseString,
                                   9.0, NSFontWeightSemibold, SKOHelpAccent(), NO);
        kickerLabel.attributedStringValue = [[NSAttributedString alloc]
            initWithString:kicker.uppercaseString
                attributes:@{
                    NSFontAttributeName: [NSFont systemFontOfSize:9.0
                                                       weight:NSFontWeightSemibold],
                    NSForegroundColorAttributeName: SKOHelpAccent(),
                    NSKernAttributeName: @1.15,
                }];
        [stack addArrangedSubview:kickerLabel];
        [kickerLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }
    if (title.length > 0) {
        titleLabel = SKOHelpLabel(title, 15.5, NSFontWeightSemibold,
                                   SKOHelpPrimary(), YES);
        [stack addArrangedSubview:titleLabel];
        [titleLabel.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }
    if (kickerLabel) {
        [stack setCustomSpacing:4.0 afterView:kickerLabel];
    }
    if (titleLabel) {
        [stack setCustomSpacing:9.0 afterView:titleLabel];
    }

    for (NSView *view in content) {
        [stack addArrangedSubview:view];
        [view.widthAnchor constraintEqualToAnchor:stack.widthAnchor].active = YES;
    }
    return card;
}

- (NSView *)welcomeCard
{
    NSView *body = SKOHelpBody(
        @"This is a live, interactive reconstruction of the Super-Kamiokande water-Cherenkov "
        @"detector. Orbit the tank, peel away its shell, inspect the two photomultiplier "
        @"arrays, and watch simulated neutrino interactions light up the inner detector.");
    NSView *body2 = SKOHelpBody(
        @"Everything is connected: the sidebar changes the model and the simulation, while "
        @"the callouts explain the parts you are looking at.");
    return [self cardWithKicker:@"WELCOME"
                          title:@"A working detector, not a static diagram"
                        content:@[body, body2]];
}

- (NSView *)quickStartCard
{
    NSArray<NSView *> *steps = @[
        [self stepRowWithNumber:@"01"
                          title:@"Orbit and zoom"
                         detail:@"Drag in the 3D view to rotate, scroll or pinch to zoom, "
                                @"and double-click the detector to recenter."],
        [self stepRowWithNumber:@"02"
                          title:@"Run or pause the detector"
                         detail:@"The simulation starts automatically. Use Pause simulation "
                                @"in the sidebar, or press P, to control new events."],
        [self stepRowWithNumber:@"03"
                          title:@"Open the tank"
                         detail:@"Use Cutaway, Labels, and Explode in the upper-right viewport "
                                @"bar to reveal the detector's layers."],
        [self stepRowWithNumber:@"04"
                          title:@"Change the physics"
                         detail:@"The sidebar sliders alter water level, fiducial volume, "
                                @"water transparency, PMT gain, event rate, and more."],
    ];
    return [self cardWithKicker:@"QUICK START"
                          title:@"Four ways to begin"
                        content:steps];
}

- (NSView *)viewportCard
{
    NSArray<NSView *> *rows = @[
        [self inlineRowWithKey:@"Center" detail:@"Reframes the detector with the default camera."],
        [self inlineRowWithKey:@"Cutaway" detail:@"Switches the stainless-steel shell between X-ray and solid."],
        [self inlineRowWithKey:@"Rotate" detail:@"Starts or stops a slow automatic orbit."],
        [self inlineRowWithKey:@"Explode" detail:@"Pulls the detector groups apart to inspect the ID/OD layers."],
        [self inlineRowWithKey:@"Labels" detail:@"Shows or hides the nine part callouts."],
        [self inlineRowWithKey:@"Help" detail:@"Opens this guide; the same command is in Help > Super-Kamiokande Help (⌘?)."],
    ];
    return [self cardWithKicker:@"VIEWPORT BAR"
                          title:@"Controls at the upper right"
                        content:rows];
}

- (NSView *)simulationCard
{
    NSArray<NSView *> *rows = @[
        [self legendRowWithTitle:@"Muon" color:SKOHelpColor(1.0, 0.42, 0.78, 1.0)
                          detail:@"A long pink track crossing the detector, with Cherenkov light along its path."],
        [self legendRowWithTitle:@"Electron" color:SKOHelpColor(0.16, 0.83, 0.90, 1.0)
                          detail:@"A compact cyan ring expanding across the photomultiplier wall."],
        [self legendRowWithTitle:@"Gamma" color:SKOHelpColor(0.95, 0.74, 0.30, 1.0)
                          detail:@"A gold ring produced by an electromagnetic shower."],
        [self inlineRowWithKey:@"PMT flashes" detail:@"Gold phototubes brighten where the Cherenkov cone intersects the inner detector."],
        [self inlineRowWithKey:@"HUD" detail:@"Top-left readouts show run state, total events, the last energy/type, and water conditions."],
    ];
    return [self cardWithKicker:@"SIMULATION"
                          title:@"What the events mean"
                        content:rows];
}

- (NSView *)sidebarCard
{
    NSArray<NSView *> *rows = @[
        [self inlineRowWithKey:@"Pause simulation" detail:@"Stops new event generation while keeping the scene interactive."],
        [self inlineRowWithKey:@"Reset events" detail:@"Clears the event counter and begins a fresh run."],
        [self inlineRowWithKey:@"Water fill" detail:@"Raises or lowers the ultra-pure water volume."],
        [self inlineRowWithKey:@"Fiducial radius" detail:@"Resizes the green analysis volume inside the tank."],
        [self inlineRowWithKey:@"Water transparency" detail:@"Controls how visible the water volume is."],
        [self inlineRowWithKey:@"Shell opacity" detail:@"Makes the outer tank solid or X-ray-transparent."],
        [self inlineRowWithKey:@"PMT gain" detail:@"Brightens the flashes when a phototube is hit."],
        [self inlineRowWithKey:@"Event rate" detail:@"Sets the number of simulated events per second."],
        [self inlineRowWithKey:@"Rotation speed" detail:@"Sets how quickly the auto-orbit rotates."],
    ];
    return [self cardWithKicker:@"SIDEBAR"
                          title:@"Tuning the run"
                        content:rows];
}

- (NSView *)detectorCard
{
    NSView *metrics = [self metricRow];
    NSView *body = SKOHelpBody(
        @"The detector sits about 1,000 m underground in the Kamioka mine. The inner detector "
        @"uses 11,129 20-inch PMTs; the outer detector adds 1,885 8-inch PMTs. The fiducial "
        @"volume is the clean inner region used for physics analysis.");
    return [self cardWithKicker:@"DETECTOR"
                          title:@"Scale and numbers"
                        content:@[metrics, body]];
}

- (NSView *)keyboardCard
{
    NSArray<NSView *> *rows = @[
        [self shortcutRowWithKey:@"⌘?" detail:@"Open this help window"],
        [self shortcutRowWithKey:@"P" detail:@"Run / pause the simulation"],
        [self shortcutRowWithKey:@"K" detail:@"Reset the event counter"],
        [self shortcutRowWithKey:@"R" detail:@"Reset the camera"],
        [self shortcutRowWithKey:@"T" detail:@"Toggle the cutaway shell"],
        [self shortcutRowWithKey:@"A" detail:@"Toggle auto-rotate"],
        [self shortcutRowWithKey:@"L" detail:@"Toggle part labels"],
        [self shortcutRowWithKey:@"S" detail:@"Toggle the control sidebar"],
        [self shortcutRowWithKey:@"E" detail:@"Explode / assemble the detector"],
        [self shortcutRowWithKey:@"⌃⌘F" detail:@"Toggle full screen"],
    ];
    return [self cardWithKicker:@"KEYBOARD"
                          title:@"Shortcuts"
                        content:rows];
}

- (NSView *)inlineRowWithKey:(NSString *)key detail:(NSString *)detail
{
    NSTextField *keyLabel = SKOHelpLabel(key, 11.5, NSFontWeightSemibold,
                                         SKOHelpPrimary(), NO);
    [keyLabel.widthAnchor constraintEqualToConstant:152.0].active = YES;

    NSTextField *detailLabel = SKOHelpBody(detail);
    [detailLabel setContentHuggingPriority:NSLayoutPriorityDefaultLow
                            forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 14.0;
    [row addArrangedSubview:keyLabel];
    [row addArrangedSubview:detailLabel];
    return row;
}

- (NSView *)stepRowWithNumber:(NSString *)number
                        title:(NSString *)title
                       detail:(NSString *)detail
{
    NSView *badge = [[NSView alloc] initWithFrame:NSZeroRect];
    badge.translatesAutoresizingMaskIntoConstraints = NO;
    badge.wantsLayer = YES;
    badge.layer.cornerRadius = 11.0;
    badge.layer.backgroundColor = SKOHelpColor(0.16, 0.83, 0.90, 0.12).CGColor;
    badge.layer.borderWidth = 1.0;
    badge.layer.borderColor = SKOHelpColor(0.16, 0.83, 0.90, 0.30).CGColor;
    [badge.widthAnchor constraintEqualToConstant:24.0].active = YES;
    [badge.heightAnchor constraintEqualToConstant:24.0].active = YES;

    NSTextField *numberLabel = SKOHelpLabel(number, 9.0, NSFontWeightBold,
                                             SKOHelpAccent(), NO);
    numberLabel.alignment = NSTextAlignmentCenter;
    [badge addSubview:numberLabel];
    [NSLayoutConstraint activateConstraints:@[
        [numberLabel.centerXAnchor constraintEqualToAnchor:badge.centerXAnchor],
        [numberLabel.centerYAnchor constraintEqualToAnchor:badge.centerYAnchor constant:-0.5],
    ]];

    NSTextField *text = SKOHelpRichLabel(title, detail);
    [text setContentHuggingPriority:NSLayoutPriorityDefaultLow
                     forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 12.0;
    [row addArrangedSubview:badge];
    [row addArrangedSubview:text];
    return row;
}

- (NSView *)legendRowWithTitle:(NSString *)title
                         color:(NSColor *)color
                        detail:(NSString *)detail
{
    NSView *swatch = [[NSView alloc] initWithFrame:NSZeroRect];
    swatch.translatesAutoresizingMaskIntoConstraints = NO;
    swatch.wantsLayer = YES;
    swatch.layer.cornerRadius = 4.0;
    swatch.layer.backgroundColor = color.CGColor;
    swatch.layer.shadowColor = color.CGColor;
    swatch.layer.shadowOpacity = 0.55;
    swatch.layer.shadowRadius = 4.0;
    swatch.layer.shadowOffset = NSMakeSize(0, 0);
    [swatch.widthAnchor constraintEqualToConstant:8.0].active = YES;
    [swatch.heightAnchor constraintEqualToConstant:8.0].active = YES;

    NSView *swatchSlot = [[NSView alloc] initWithFrame:NSZeroRect];
    swatchSlot.translatesAutoresizingMaskIntoConstraints = NO;
    [swatchSlot.widthAnchor constraintEqualToConstant:24.0].active = YES;
    [swatchSlot.heightAnchor constraintEqualToConstant:24.0].active = YES;
    [swatchSlot addSubview:swatch];
    [NSLayoutConstraint activateConstraints:@[
        [swatch.centerXAnchor constraintEqualToAnchor:swatchSlot.centerXAnchor],
        [swatch.centerYAnchor constraintEqualToAnchor:swatchSlot.centerYAnchor],
    ]];

    NSTextField *titleLabel = SKOHelpLabel(title, 11.5, NSFontWeightSemibold,
                                            SKOHelpPrimary(), NO);
    [titleLabel.widthAnchor constraintEqualToConstant:126.0].active = YES;
    titleLabel.alignment = NSTextAlignmentLeft;

    NSTextField *detailLabel = SKOHelpBody(detail);
    [detailLabel setContentHuggingPriority:NSLayoutPriorityDefaultLow
                            forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 8.0;
    [row addArrangedSubview:swatchSlot];
    [row addArrangedSubview:titleLabel];
    [row addArrangedSubview:detailLabel];
    return row;
}

- (NSView *)metricRow
{
    NSArray<NSArray<NSString *> *> *metrics = @[
        @[@"41.4 m", @"HEIGHT"],
        @[@"39.3 m", @"DIAMETER"],
        @[@"50,000 t", @"PURE WATER"],
        @[@"11,129", @"ID PMTS"],
    ];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeTop;
    row.distribution = NSStackViewDistributionFillEqually;
    row.spacing = 8.0;

    for (NSArray<NSString *> *metric in metrics) {
        NSView *box = [[NSView alloc] initWithFrame:NSZeroRect];
        box.translatesAutoresizingMaskIntoConstraints = NO;
        box.wantsLayer = YES;
        box.layer.backgroundColor = SKOHelpColor(1.0, 1.0, 1.0, 0.035).CGColor;
        box.layer.cornerRadius = 8.0;
        box.layer.borderWidth = 1.0;
        box.layer.borderColor = SKOHelpColor(1.0, 1.0, 1.0, 0.07).CGColor;

        NSTextField *value = SKOHelpLabel(metric[0], 20.0, NSFontWeightSemibold,
                                           SKOHelpPrimary(), NO);
        value.font = [NSFont monospacedDigitSystemFontOfSize:20.0
                                                      weight:NSFontWeightSemibold];
        value.alignment = NSTextAlignmentCenter;
        NSTextField *caption = SKOHelpLabel(metric[1], 8.5, NSFontWeightSemibold,
                                             SKOHelpFaint(), NO);
        caption.alignment = NSTextAlignmentCenter;

        NSStackView *metricStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
        metricStack.translatesAutoresizingMaskIntoConstraints = NO;
        metricStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        metricStack.alignment = NSLayoutAttributeCenterX;
        metricStack.distribution = NSStackViewDistributionFill;
        metricStack.spacing = 2.0;
        [metricStack addArrangedSubview:value];
        [metricStack addArrangedSubview:caption];
        [box addSubview:metricStack];

        [NSLayoutConstraint activateConstraints:@[
            [box.heightAnchor constraintEqualToConstant:66.0],
            [metricStack.centerXAnchor constraintEqualToAnchor:box.centerXAnchor],
            [metricStack.centerYAnchor constraintEqualToAnchor:box.centerYAnchor],
        ]];
        [row addArrangedSubview:box];
    }
    return row;
}

- (NSView *)shortcutRowWithKey:(NSString *)key detail:(NSString *)detail
{
    NSView *keycap = [[NSView alloc] initWithFrame:NSZeroRect];
    keycap.translatesAutoresizingMaskIntoConstraints = NO;
    keycap.wantsLayer = YES;
    keycap.layer.backgroundColor = SKOHelpColor(1.0, 1.0, 1.0, 0.06).CGColor;
    keycap.layer.cornerRadius = 5.0;
    keycap.layer.borderWidth = 1.0;
    keycap.layer.borderColor = SKOHelpColor(1.0, 1.0, 1.0, 0.10).CGColor;
    [keycap.widthAnchor constraintEqualToConstant:96.0].active = YES;
    [keycap.heightAnchor constraintEqualToConstant:23.0].active = YES;

    NSTextField *keyLabel = SKOHelpLabel(key, 10.5, NSFontWeightSemibold,
                                          SKOHelpAccent(), NO);
    keyLabel.font = [NSFont monospacedSystemFontOfSize:10.5 weight:NSFontWeightSemibold];
    keyLabel.alignment = NSTextAlignmentCenter;
    [keycap addSubview:keyLabel];
    [NSLayoutConstraint activateConstraints:@[
        [keyLabel.centerXAnchor constraintEqualToAnchor:keycap.centerXAnchor],
        [keyLabel.centerYAnchor constraintEqualToAnchor:keycap.centerYAnchor],
    ]];

    NSTextField *detailLabel = SKOHelpBody(detail);
    [detailLabel setContentHuggingPriority:NSLayoutPriorityDefaultLow
                            forOrientation:NSLayoutConstraintOrientationHorizontal];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 14.0;
    [row addArrangedSubview:keycap];
    [row addArrangedSubview:detailLabel];
    return row;
}

@end
