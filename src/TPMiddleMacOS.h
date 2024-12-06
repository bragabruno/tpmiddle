#ifndef TPMIDDLE_MACOS_H
#define TPMIDDLE_MACOS_H

#import <Cocoa/Cocoa.h>

namespace TPMiddle {

class TPMiddleMacOS {
public:
    TPMiddleMacOS();
    ~TPMiddleMacOS();

    bool Initialize();
    void Run();

private:
    id statusBarController;  // Using id to avoid exposing Objective-C++ types in header
};

} // namespace TPMiddle

#endif // TPMIDDLE_MACOS_H
