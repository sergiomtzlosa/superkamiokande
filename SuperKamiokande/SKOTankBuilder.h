#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import "SKOCommon.h"

NS_ASSUME_NONNULL_BEGIN

/// Builds the procedural Super-Kamiokande scene graph.
@interface SKOTankBuilder : NSObject

/// Assembles every part group beneath `root`. Group names:
///   "cave", "shell", "structure", "wallPMT", "bottomPMT", "topPMT",
///   "outerPMT", "water", "fiducial", "tunnel", "facility", "anchor".
+ (void)buildIntoRoot:(SCNNode *)root;

/// Water fill level, 0..1 (fraction of tank height).
+ (void)setWaterFill:(CGFloat)fraction rootNode:(SCNNode *)root;
/// Water transparency 0..1 (alpha of the water material).
+ (void)setWaterTransparency:(CGFloat)alpha rootNode:(SCNNode *)root;

/// Fiducial volume radius in meters (scaled).
+ (void)setFiducialRadius:(CGFloat)meters rootNode:(SCNNode *)root;

/// PMT sphere radius scaling (0.5..2.0 × nominal).
+ (void)setPMTRadiusScale:(CGFloat)scale rootNode:(SCNNode *)root;

/// Explode view: pulls the groups apart radially/vertically by `amount`.
+ (void)setExplodeAmount:(CGFloat)amount rootNode:(SCNNode *)root;

/// Cutaway opacity for the steel shell (1 = opaque).
+ (void)setShellOpacity:(CGFloat)opacity rootNode:(SCNNode *)root;

/// Expanding Cherenkov ring for a physics event.
+ (SCNNode *)makeCherenkovRingWithEnergy:(CGFloat)energyGeV
                            atPosition:(SCNVector3)position
                              direction:(SCNVector3)direction
                                  color:(SKColor *)color;

/// Short-lived muon track through the detector volume.
+ (SCNNode *)makeMuonTrackWithEnergy:(CGFloat)energyGeV
                          atPosition:(SCNVector3)position
                            direction:(SCNVector3)direction
                                color:(SKColor *)color;

/// Flashes the PMTs that fall on the Cherenkov cone for `direction`.
/// Flash nodes remove themselves when their animation completes.
+ (void)flashPMTsInRoot:(SCNNode *)root
              direction:(SCNVector3)direction
            sensitivity:(CGFloat)sensitivity
                  color:(SKColor *)color;

@end

NS_ASSUME_NONNULL_END
