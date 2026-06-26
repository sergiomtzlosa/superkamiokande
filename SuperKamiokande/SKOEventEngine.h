#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, SKOEventKind) {
    SKOEventKindMuon = 0,
    SKOEventKindElectron,
    SKOEventKindGamma,
};

/// Human-readable symbol for the event type ("μ", "e⁻", "γ").
FOUNDATION_EXPORT NSString *SKOEventKindSymbol(SKOEventKind kind);
FOUNDATION_EXPORT NSString *SKOEventKindName(SKOEventKind kind);

@protocol SKOEventEngineDelegate <NSObject>
- (void)engineDidSpawnEventWithEnergy:(CGFloat)energyGeV
                                 kind:(SKOEventKind)kind
                             ringNode:(SCNNode *)ringNode
                          totalEvents:(NSUInteger)total;
@end

/// Simulates detector operation: emits neutrino / muon events at a
/// configurable rate, visualizing Cherenkov rings inside the tank.
@interface SKOEventEngine : NSObject

@property (nonatomic, weak) id<SKOEventEngineDelegate> delegate;
@property (nonatomic, readonly) BOOL running;
/// Events per second (0..20). Applied live.
@property (nonatomic, assign) CGFloat eventRate;
/// PMT brightness multiplier (0..2).
@property (nonatomic, assign) CGFloat pmtSensitivity;
/// Fiducial volume radius in metres (2..16).
@property (nonatomic, assign) CGFloat fiducialRadius;
/// Live water temperature readout, in degrees Celsius.
@property (nonatomic, readonly) CGFloat waterTemperatureCelsius;
@property (nonatomic, readonly) NSUInteger totalEvents;

- (void)start;
- (void)stop;
- (void)resetCount;
- (void)fireOnce;
- (void)attachSceneRoot:(nullable SCNNode *)root;

@end

NS_ASSUME_NONNULL_END
