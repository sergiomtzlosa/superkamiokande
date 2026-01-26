#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

/// A standalone, scrollable guide to the Super-Kamiokande 3D Explorer.
/// The window is created programmatically to match the app's dark glass UI.
@interface SKOHelpWindowController : NSWindowController

@property (nonatomic, readonly) NSScrollView *scrollView;
@property (nonatomic, readonly) NSTextField *titleLabel;

/// Positions the help window over its parent (or centers it when `parent` is
/// nil) and brings it to the front.
- (void)showRelativeToWindow:(nullable NSWindow *)parent;

@end

NS_ASSUME_NONNULL_END
