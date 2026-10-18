#import "TigirlCandidateWindow.hpp"

static const CGFloat kRowHeight = 28.0;
static const CGFloat kPadding = 8.0;
static const CGFloat kPanelWidth = 280.0;

@interface TigirlCandidateView : NSView
@property(nonatomic, copy) NSArray<NSString *> *items;
@property(nonatomic) NSInteger selection;
@property(nonatomic, copy) void (^onSelect)(NSInteger index);
@end

@implementation TigirlCandidateView
- (BOOL)isFlipped { return YES; }
- (void)mouseDown:(NSEvent *)event {
    NSPoint point = [self convertPoint:event.locationInWindow fromView:nil];
    NSInteger row = (NSInteger)((point.y - kPadding) / kRowHeight);
    if (row >= 0 && row < (NSInteger)self.items.count && self.onSelect) self.onSelect(row);
}
- (void)drawRect:(NSRect)rect {
    [[NSColor windowBackgroundColor] setFill];
    NSRectFill(rect);
    NSDictionary *attrs = @{NSFontAttributeName: [NSFont systemFontOfSize: 16]};
    CGFloat y = kPadding;
    for (NSInteger i = 0; i < (NSInteger)self.items.count; ++i) {
        if (i == self.selection) {
            [[NSColor selectedContentBackgroundColor] setFill];
            NSRectFill(NSMakeRect(0, y - 2, rect.size.width, kRowHeight - 2));
        }
        NSString *label = [NSString stringWithFormat:@"%ld  %@", (long)i + 1, self.items[i]];
        [label drawAtPoint:NSMakePoint(10, y + 4) withAttributes:attrs];
        y += kRowHeight;
    }
}
@end

@implementation TigirlCandidateWindow {
    TigirlCandidateView *_candidateView;
}
- (instancetype)init {
    self = [super initWithContentRect:NSMakeRect(0, 0, kPanelWidth, 120)
                             styleMask:(NSWindowStyleMaskBorderless | NSWindowStyleMaskNonactivatingPanel)
                               backing:NSBackingStoreBuffered
                                 defer:NO];
    if (self) {
        self.level = NSStatusWindowLevel;
        self.opaque = YES;
        self.hasShadow = YES;
        self.ignoresMouseEvents = NO;
        self.releasedWhenClosed = NO;
        self.hidesOnDeactivate = NO;
        self.becomesKeyOnlyIfNeeded = YES;
        self.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary;
        _candidateView = [[TigirlCandidateView alloc] initWithFrame:self.contentView.bounds];
        _candidateView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        __unsafe_unretained TigirlCandidateWindow *weakSelf = self;
        _candidateView.onSelect = ^(NSInteger index) {
            TigirlCandidateWindow *strongSelf = weakSelf;
            if (strongSelf && strongSelf.selectionHandler) strongSelf.selectionHandler(index);
        };
        [self.contentView addSubview:_candidateView];
    }
    return self;
}
- (void)showCandidates:(const std::vector<tiger::Candidate> &)candidates
             selection:(NSInteger)selection
              atPoint:(NSPoint)point {
    NSMutableArray *items = [NSMutableArray arrayWithCapacity:candidates.size()];
    for (const auto &candidate : candidates) {
        [items addObject:[[NSString alloc] initWithBytes:candidate.display.data()
                                                   length:candidate.display.size() * sizeof(char16_t)
                                                 encoding:NSUTF16LittleEndianStringEncoding] ?: @""];
    }
    _candidateView.items = items;
    _candidateView.selection = selection;

    CGFloat height = MAX(1, (CGFloat)items.count) * kRowHeight + kPadding;
    [self setContentSize:NSMakeSize(kPanelWidth, height)];
    _candidateView.frame = self.contentView.bounds;
    [_candidateView setNeedsDisplay:YES];

    NSScreen *screen = self.screen ?: [NSScreen mainScreen];
    NSRect visible = screen ? screen.visibleFrame : NSMakeRect(0, 0, 1440, 900);
    CGFloat x = point.x;
    // Prefer below the caret; flip above when there is no room, then clamp.
    CGFloat y = point.y - height - 6;
    if (y < NSMinY(visible)) y = point.y + 22;
    x = MIN(MAX(x, NSMinX(visible) + 4), NSMaxX(visible) - kPanelWidth - 4);
    y = MIN(MAX(y, NSMinY(visible) + 4), NSMaxY(visible) - height - 4);
    [self setFrameOrigin:NSMakePoint(x, y)];
    // orderFrontRegardless keeps the panel visible even when the host app is
    // not the active application.
    [self orderFrontRegardless];
}
- (void)hideCandidates { [self orderOut:nil]; }
@end
