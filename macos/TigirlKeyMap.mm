#import <Cocoa/Cocoa.h>
#import "TigirlKeyMap.hpp"

namespace tigirl::macos {
tiger::KeyEvent keyEventFromNSEvent(void *raw) {
    NSEvent *event = (__bridge NSEvent *)raw;
    tiger::KeyEvent result;
    // US ANSI keyCode table. Slots 10 (section), 36 (return), 48 (tab) and
    // 49 (space) stay empty because the switch below maps them explicitly;
    // omitting them here shifts every later key by one and breaks typing.
    static const int letters[] = {
        'A','S','D','F','H','G','Z','X','C','V', 0, 'B','Q','W','E','R','Y','T',
        '1','2','3','4','6','5','=','9','7','-','8','0',']','O','U','[','I','P',
        0, 'L','J','\'','K',';','\\',',','/','N','M','.','`'
    };
    const auto code = static_cast<std::size_t>(event.keyCode);
    result.vk = code < sizeof(letters) / sizeof(*letters) ? letters[code] : 0;
    switch (event.keyCode) {
        case 36: result.vk = 13; break;      // return
        case 48: result.vk = 9; break;       // tab
        case 49: result.vk = 32; break;      // space
        case 51: result.vk = 8; break;       // delete
        case 53: result.vk = 27; break;      // escape
        case 123: result.vk = 37; break;     // left
        case 124: result.vk = 39; break;     // right
        case 125: result.vk = 40; break;     // down
        case 126: result.vk = 38; break;     // up
        case 115: result.vk = 36; break;     // home
        case 119: result.vk = 35; break;     // end
        case 116: result.vk = 33; break;     // page up
        case 121: result.vk = 34; break;     // page down
        case 117: result.vk = 127; break;    // forward delete
        // Windows virtual-key codes for OEM punctuation; the engine expects
        // VK_OEM_1 (186) etc., not the ASCII character code.
        case 41: result.vk = 186; break;     // ; :
        case 39: result.vk = 222; break;     // ' "
        case 43: result.vk = 188; break;     // , <
        case 47: result.vk = 190; break;     // . >
        case 44: result.vk = 191; break;     // / ?
        case 27: result.vk = 189; break;     // - _
        case 24: result.vk = 187; break;     // = +
        case 33: result.vk = 219; break;     // [ {
        case 30: result.vk = 221; break;     // ] }
        case 42: result.vk = 220; break;     // \ |
        case 50: result.vk = 192; break;     // ` ~
        default: break;
    }
    result.down = event.type == NSEventTypeKeyDown;
    result.repeat = event.isARepeat ? 2 : 1;
    const auto flags = event.modifierFlags;
    result.shift = (flags & NSEventModifierFlagShift) != 0;
    result.ctrl = (flags & NSEventModifierFlagControl) != 0;
    result.alt = (flags & NSEventModifierFlagOption) != 0;
    result.win = (flags & NSEventModifierFlagCommand) != 0;
    result.caps = (flags & NSEventModifierFlagCapsLock) != 0;
    result.num = true;
    return result;
}
}
