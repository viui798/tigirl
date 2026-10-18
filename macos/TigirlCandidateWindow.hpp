#import <Cocoa/Cocoa.h>
#include "Engine.h"

@interface TigirlCandidateWindow : NSPanel
@property(nonatomic, copy) void (^selectionHandler)(NSInteger index);
- (void)showCandidates:(const std::vector<tiger::Candidate> &)candidates
             selection:(NSInteger)selection
              atPoint:(NSPoint)point;
- (void)hideCandidates;
@end
