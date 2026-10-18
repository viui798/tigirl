#import <InputMethodKit/InputMethodKit.h>
#import <ApplicationServices/ApplicationServices.h>
#include <memory>
#include <filesystem>
#include <cstdlib>
#import "TigirlCandidateWindow.hpp"
#import "TigirlKeyMap.hpp"
#import "TigirlSentence.hpp"
#include "SentenceDecoder.h"
#include "SentenceResources.h"

@interface TigirlInputController : IMKInputController
@end

@implementation TigirlInputController {
    std::unique_ptr<tiger::Engine> _engine;
    TigirlCandidateWindow *_candidateWindow;
    __unsafe_unretained id _lastClient;
    std::unique_ptr<tiger::SentenceDecoder> _sentenceDecoder;
    bool _sentenceEnabled;
    NSString *_schema;
    std::string _dictionaryPath;
}

- (NSUInteger)recognizedEvents:(id)sender {
    // InputMethodKit only forwards non-text key events (arrows, paging) to
    // handleEvent: when the controller declares them.
    return NSKeyDownMask;
}
- (instancetype)initWithServer:(IMKServer *)server delegate:(id)delegate client:(id)client {
    self = [super initWithServer:server delegate:delegate client:client];
    if (self) {
        _sentenceEnabled = false;
        _candidateWindow = [TigirlCandidateWindow new];
        __unsafe_unretained TigirlInputController *weakSelf = self;
        _candidateWindow.selectionHandler = ^(NSInteger index) {
            TigirlInputController *strongSelf = weakSelf;
            if (!strongSelf || !strongSelf->_engine) return;
            const auto snapshot = strongSelf->_engine->snapshot();
            const auto absolute = static_cast<std::uint32_t>(snapshot.page * strongSelf->_engine->pageSize() + index);
            if (auto result = strongSelf->_engine->selectCandidate(absolute)) {
                [strongSelf applyResult:*result client:strongSelf->_lastClient];
            }
        };
        NSString *schema = [[NSUserDefaults standardUserDefaults] stringForKey:@"TigirlSchema"];
        if (!schema.length) schema = @"words";
        [self loadSchema:schema];
    }
    return self;
}

- (NSString *)dictionaryPathForSchema:(NSString *)schema {
    NSString *name = [schema isEqualToString:@"sentence"] ? @"tiger-v2-sentence" : @"tiger-v2";
    NSString *path = [[NSBundle mainBundle] pathForResource:name ofType:@"tcd"];
    if (!path.length) {
        const char *external = std::getenv("TIGIRL_DICTIONARY");
        if (external) path = [NSString stringWithUTF8String:external];
    }
    return path;
}

- (void)loadSchema:(NSString *)schema {
    NSString *path = [self dictionaryPathForSchema:schema];
    if (!path.length) return;
    try {
        auto dictionary = tiger::Dictionary::Open(std::filesystem::path(path.UTF8String));
        _engine = std::make_unique<tiger::Engine>(std::move(dictionary));
        _dictionaryPath = path.UTF8String;
        _sentenceDecoder.reset();
        _sentenceEnabled = false;
        [_schema release];
        _schema = [schema copy];
        if ([schema isEqualToString:@"sentence"]) {
            TigirlLoadSentenceResources(std::filesystem::path(path.UTF8String));
        }
    } catch (const std::exception &error) {
        NSLog(@"Tigirl dictionary failed: %s", error.what());
        _engine.reset();
    } catch (...) {
        _engine.reset();
    }
}

- (void)switchSchema:(NSString *)schema {
    [[NSUserDefaults standardUserDefaults] setObject:schema forKey:@"TigirlSchema"];
    [self loadSchema:schema];
    if (_lastClient) {
        [_lastClient setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    }
    [_candidateWindow hideCandidates];
}

- (void)selectWords:(id)sender { [self switchSchema:@"words"]; }
- (void)selectSentence:(id)sender { [self switchSchema:@"sentence"]; }

- (NSMenu *)menu {
    NSMenu *menu = [[[NSMenu alloc] initWithTitle:@"虎娘"] autorelease];
    NSMenuItem *words = [[[NSMenuItem alloc] initWithTitle:@"虎码字词" action:@selector(selectWords:) keyEquivalent:@""] autorelease];
    words.target = self;
    words.state = [_schema isEqualToString:@"words"] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:words];
    NSMenuItem *sentence = [[[NSMenuItem alloc] initWithTitle:@"虎整句" action:@selector(selectSentence:) keyEquivalent:@""] autorelease];
    sentence.target = self;
    sentence.state = [_schema isEqualToString:@"sentence"] ? NSControlStateValueOn : NSControlStateValueOff;
    [menu addItem:sentence];
    return menu;
}

- (void)activateServer:(id)sender {
    NSString *wanted = [[NSUserDefaults standardUserDefaults] stringForKey:@"TigirlSchema"];
    if (!wanted.length) wanted = @"words";
    if (![_schema isEqualToString:wanted]) [self loadSchema:wanted];
    [super activateServer:sender];
}

- (void)enableSentenceIfReady {
    if (_sentenceEnabled || !_engine) return;
    // Only the 虎整句 schema uses the decoder; 虎码字词 keeps ordinary input
    // with four-code auto-commit.
    if (![_schema isEqualToString:@"sentence"]) return;
    auto resources = TigirlSentenceResources(_dictionaryPath);
    if (!resources) return;
    _sentenceDecoder = resources->createDecoder();
    _engine->enableSentenceInput(true, 1, true, 0);
    _sentenceEnabled = true;
}

- (void)applyResult:(const tiger::KeyResult &)result client:(id)client {
    _lastClient = client;
    if (!result.commit.empty()) {
        NSString *text = [[NSString alloc] initWithBytes:result.commit.data()
                                                   length:result.commit.size() * sizeof(char16_t)
                                                 encoding:NSUTF16LittleEndianStringEncoding];
        // Clear the composition first so the committed text replaces the
        // marked text instead of being appended after it.
        [client setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
        [client insertText:text replacementRange:NSMakeRange(NSNotFound, 0)];
    }
    const auto snapshot = _engine->snapshot();
    NSString *marked = [[NSString alloc] initWithBytes:snapshot.compositionText().data()
                                                 length:snapshot.compositionText().size() * sizeof(char16_t)
                                               encoding:NSUTF16LittleEndianStringEncoding];
    if (marked.length) {
        [client setMarkedText:marked selectionRange:NSMakeRange(marked.length, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    } else {
        [client setMarkedText:@"" selectionRange:NSMakeRange(0, 0) replacementRange:NSMakeRange(NSNotFound, 0)];
    }
    if (!snapshot.candidates.empty()) {
        [_candidateWindow showCandidates:snapshot.candidates
                               selection:snapshot.selectedCandidate
                                 atPoint:[self caretPointForClient:client]];
    } else {
        [_candidateWindow hideCandidates];
    }
}

- (NSPoint)caretPointForClient:(id)client {
    NSRect caret = NSZeroRect;
    if ([client respondsToSelector:@selector(firstRectForCharacterRange:actualRange:)]) {
        // Prefer the client's current selection: many web views implement
        // selectedRange/firstRectForCharacterRange but not the NSNotFound probe.
        NSRange selection = NSMakeRange(NSNotFound, 0);
        if ([client respondsToSelector:@selector(selectedRange)]) {
            selection = [client selectedRange];
        }
        if (selection.location != NSNotFound) {
            caret = [client firstRectForCharacterRange:selection actualRange:NULL];
        }
        if (NSIsEmptyRect(caret)) {
            // NSNotFound asks IMK for the insertion point; index 0 would return
            // the first character of the document instead.
            caret = [client firstRectForCharacterRange:NSMakeRange(NSNotFound, 0) actualRange:NULL];
        }
        if (NSIsEmptyRect(caret)) {
            caret = [client firstRectForCharacterRange:NSMakeRange(0, 0) actualRange:NULL];
        }
    }
    if (NSIsEmptyRect(caret) &&
        [client respondsToSelector:@selector(attributesForCharacterIndex:lineHeightRectangle:)]) {
        // Squirrel uses this IMKTextInput method instead of the rectangle probe;
        // web views often implement it even when firstRectForCharacterRange does
        // not return anything useful.
        NSRect line = NSZeroRect;
        [client attributesForCharacterIndex:0 lineHeightRectangle:&line];
        if (!NSIsEmptyRect(line)) caret = line;
    }
    if (NSIsEmptyRect(caret) && AXIsProcessTrusted()) {
        // Accessibility fallback: web views and some custom editors expose the
        // insertion point through AX but not through IMKTextInput. A failed or
        // slow AX query must not stall typing, so it gets a short timeout and is
        // disabled for the rest of the session after the first failure.
        static bool axFailed = false;
        if (!axFailed) {
            AXUIElementRef system = AXUIElementCreateSystemWide();
            if (system) {
                AXUIElementSetMessagingTimeout(system, 0.2);
                CFTypeRef focused = NULL;
                bool ok = false;
                if (AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute, &focused) == kAXErrorSuccess && focused) {
                    AXUIElementSetMessagingTimeout((AXUIElementRef)focused, 0.2);
                    CFTypeRef rangeValue = NULL;
                    if (AXUIElementCopyAttributeValue((AXUIElementRef)focused, kAXSelectedTextRangeAttribute, &rangeValue) == kAXErrorSuccess && rangeValue) {
                        CFRange range = CFRangeMake(0, 0);
                        if (AXValueGetValue((AXValueRef)rangeValue, (AXValueType)kAXValueCFRangeType, &range)) {
                            AXValueRef query = AXValueCreate((AXValueType)kAXValueCFRangeType, &range);
                            CFTypeRef boundsValue = NULL;
                            if (query && AXUIElementCopyParameterizedAttributeValue((AXUIElementRef)focused, kAXBoundsForRangeParameterizedAttribute, query, &boundsValue) == kAXErrorSuccess && boundsValue) {
                                CGRect bounds = CGRectZero;
                                if (AXValueGetValue((AXValueRef)boundsValue, (AXValueType)kAXValueCGRectType, &bounds)) {
                                    NSScreen *screen = [NSScreen mainScreen];
                                    CGFloat flippedY = NSMaxY(screen.frame) - CGRectGetMaxY(bounds);
                                    caret = NSMakeRect(bounds.origin.x, flippedY, bounds.size.width, bounds.size.height);
                                    ok = true;
                                }
                                CFRelease(boundsValue);
                            }
                            if (query) CFRelease(query);
                        }
                        CFRelease(rangeValue);
                    }
                    CFRelease(focused);
                }
                CFRelease(system);
                if (!ok) {
                    axFailed = true;
                }
            }
        }
    }
    if (NSIsEmptyRect(caret)) {
        NSPoint mouse = [NSEvent mouseLocation];
        // No caret geometry from this client: sit a little below the pointer so
        // the panel does not cover the text being typed.
        caret = NSMakeRect(mouse.x, mouse.y - 28, 0, 0);
    } else {
    }
    if (!NSEqualPoints(caret.origin, NSZeroPoint)) return caret.origin;
    return NSMakePoint(NSMidX([NSScreen mainScreen].frame), NSMidY([NSScreen mainScreen].frame));
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)client {
    if (!_engine || event.type != NSEventTypeKeyDown) return NO;
    switch (event.keyCode) {
        case 55: case 56: case 57: case 58: case 59: case 60: case 61: case 62: case 63:
            return NO; // modifier keys
        default: break;
    }
    [self enableSentenceIfReady];
    tiger::KeyEvent key = tigirl::macos::keyEventFromNSEvent((__bridge void *)event);
    tiger::SentencePathQueries queries;
    if (_sentenceDecoder) {
        auto decoder = _sentenceDecoder.get();
        queries.complete = [decoder](std::u16string_view raw, std::u16string_view prefix,
                                     std::optional<std::u16string_view> excluded, bool grouped,
                                     const tiger::SentenceLockedPrefix *locked) {
            return decoder->hasCompleteCandidate(raw, prefix, excluded, grouped, locked);
        };
        queries.properPrefix = [decoder](std::u16string_view raw) {
            return decoder->isProperCodePrefix(raw);
        };
        queries.competingBoundaryEnd = [decoder](std::u16string_view raw, int committed, int proposed, int target) {
            return decoder->competingBoundaryEnd(raw, committed, proposed, target);
        };
    }
    // Keep the composition alive for navigation keys that the client would
    // otherwise use to move the caret and drop the marked text.
    if (_engine->composing()) {
        if (key.vk == 38 || key.vk == 40) {
            const auto snapshot = _engine->snapshot();
            _engine->setPage(snapshot.page + (key.vk == 40 ? 1 : -1));
            tiger::KeyResult pageResult;
            pageResult.handled = true;
            [self applyResult:pageResult client:client];
            return YES;
        }
        if (key.vk == 37 || key.vk == 39 || key.vk == 36 || key.vk == 35) {
            return YES;
        }
    }
    tiger::KeyResult result = _engine->process(key, queries);
    // The engine exposes a pending sentence decode after every appended code.
    // Completing it here keeps sentence candidates visible while typing; a key
    // that awaits the result (space/tab/enter) is replayed after the decode.
    auto completeSentence = [&]() -> bool {
        if (!_sentenceDecoder) return false;
        auto ticket = _engine->sentenceRequest();
        if (!ticket) return false;
        try {
            auto decoded = _sentenceDecoder->decode(ticket->raw, 20, true,
                                                    ticket->requiredPrefix, ticket->lockedPrefix);
            return _engine->applySentenceResult(*ticket, std::move(decoded));
        } catch (...) {
            return false;
        }
    };
    if (result.awaitSentenceDecode) {
        if (completeSentence()) result = _engine->process(key, queries);
    } else if (_sentenceEnabled) {
        completeSentence();
    }
    if (!result.handled) return NO;
    [self applyResult:result client:client];
    return YES;
}

- (void)deactivateServer:(id)sender {
    [_candidateWindow hideCandidates];
    [super deactivateServer:sender];
}
@end
