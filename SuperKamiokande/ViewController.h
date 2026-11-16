#import <Cocoa/Cocoa.h>
#import <SceneKit/SceneKit.h>
#import "SKOEventEngine.h"

@class SKOHelpWindowController;
@class SKOFlatButton;

NS_ASSUME_NONNULL_BEGIN

/// Hosts the SceneKit detector view, the live HUD, the part-label overlay and
/// the control sidebar. The sidebar can be collapsed completely, and the view
/// controls sit in a translucent row over the upper-right of the 3D scene.
@interface ViewController : NSViewController

@property (nonatomic, strong) SCNView  *sceneView;
@property (nonatomic, strong) SCNScene *scene;
@property (nonatomic, strong) SCNNode  *rootGroup;
@property (nonatomic, strong) SCNNode  *cameraNode;
@property (nonatomic, strong) SCNNode  *lookTarget;
@property (nonatomic, strong) SKOEventEngine *engine;

/// Start the event simulation automatically when the view first loads.
/// Defaults to YES; tests can disable it before accessing the view.
@property (nonatomic, assign) BOOL autoStartSimulation;

@property (nonatomic, strong) NSVisualEffectView *sidebar;
@property (nonatomic, assign) BOOL       sidebarVisible;
@property (nonatomic, strong) NSButton  *sidebarCollapseButton;
@property (nonatomic, strong) NSButton  *sidebarRevealButton;

@property (nonatomic, strong) NSTextField *statusLabel;
@property (nonatomic, strong) NSTextField *hudStatusLabel;
@property (nonatomic, strong) NSTextField *hudEventLabel;
@property (nonatomic, strong) NSTextField *hudDetailLabel;
@property (nonatomic, strong) NSTextField *hudEnvLabel;

@property (nonatomic, strong) NSSlider *waterSlider;
@property (nonatomic, strong) NSSlider *fiducialSlider;
@property (nonatomic, strong) NSSlider *transparencySlider;
@property (nonatomic, strong) NSSlider *rateSlider;
@property (nonatomic, strong) NSSlider *sensitivitySlider;
@property (nonatomic, strong) NSSlider *cutawaySlider;
@property (nonatomic, strong) NSSlider *rotationSlider;

@property (nonatomic, strong) SKOFlatButton *runButton;
@property (nonatomic, strong) NSButton *resetButton;
@property (nonatomic, strong) NSButton *cameraButton;
@property (nonatomic, strong) SKOFlatButton *cutawayButton;
@property (nonatomic, strong) SKOFlatButton *rotateButton;
@property (nonatomic, strong) SKOFlatButton *explodeButton;
@property (nonatomic, strong) SKOFlatButton *centerButton;
@property (nonatomic, strong) SKOFlatButton *labelsButton;
@property (nonatomic, strong) SKOFlatButton *helpButton;

@property (nonatomic, strong, nullable) SKOHelpWindowController *helpWindowController;

@property (nonatomic, strong) NSView *labelsOverlay;
@property (nonatomic, assign) BOOL    labelsVisible;

@property (nonatomic, assign) BOOL    autoRotate;
@property (nonatomic, assign) BOOL    exploded;
@property (nonatomic, assign) BOOL    cutawayOn;
@property (nonatomic, assign) CGFloat autoRotateSpeed;

- (IBAction)toggleRun:(nullable id)sender;
- (IBAction)resetCounter:(nullable id)sender;
- (IBAction)resetCamera:(nullable id)sender;
- (IBAction)centerModel:(nullable id)sender;
- (IBAction)toggleCutaway:(nullable id)sender;
- (IBAction)toggleRotate:(nullable id)sender;
- (IBAction)toggleExplode:(nullable id)sender;
- (IBAction)toggleSidebar:(nullable id)sender;
- (IBAction)toggleLabels:(nullable id)sender;
- (IBAction)showHelp:(nullable id)sender;

@end

NS_ASSUME_NONNULL_END
