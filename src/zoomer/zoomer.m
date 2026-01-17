#import "ZKSwizzle.h"
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface NSWindow (ZoomerPrivate)
- (BOOL)_zoomButtonIsFullScreenButton;
@end

// Helper to inject hint into a menu
static void InjectZoomerHint(NSMenu *menu) {
  if (!menu)
    return;

  // Check if we already injected
  for (NSMenuItem *item in menu.itemArray) {
    if ([item.title isEqualToString:@"Hold ⌘ to enter Full Screen"])
      return;
  }

  NSInteger fsIndex = -1;
  for (NSInteger i = 0; i < (NSInteger)menu.itemArray.count; i++) {
    NSString *title = menu.itemArray[i].title;
    // If we see "Exit Full Screen", we are already in fullscreen. Skip the
    // hint.
    if ([title containsString:@"Exit Full Screen"])
      return;

    // Match "Full Screen" (covers "Enter Full Screen", "Full Screen", etc.)
    if ([title containsString:@"Full Screen"]) {
      fsIndex = i;
      break;
    }
  }

  if (fsIndex != -1) {
    // Add separator if needed
    if (fsIndex > 0 && ![menu.itemArray[fsIndex - 1] isSeparatorItem]) {
      [menu insertItem:[NSMenuItem separatorItem] atIndex:fsIndex];
      fsIndex++;
    }

    NSMenuItem *hint =
        [[NSMenuItem alloc] initWithTitle:@"Hold ⌘ to enter Full Screen"
                                   action:nil
                            keyEquivalent:@""];
    hint.enabled = NO;
    [menu insertItem:hint atIndex:fsIndex];
  }
}

ZKSwizzleInterface(ZoomerMenuHook, NSMenu, NSObject)
    @implementation ZoomerMenuHook
- (void)addItem:(NSMenuItem *)newItem {
  ZKOrig(void, newItem);
  InjectZoomerHint((NSMenu *)self);
}
- (void)insertItem:(NSMenuItem *)newItem atIndex:(NSInteger)index {
  ZKOrig(void, newItem, index);
  InjectZoomerHint((NSMenu *)self);
}
@end

ZKSwizzleInterface(ZoomerWindowHook, NSWindow, NSResponder)
    @implementation ZoomerWindowHook

// Handle Command-click on green button
- (BOOL)_zoomButtonIsFullScreenButton {
  NSWindow *window = (NSWindow *)self;
  if (window.styleMask & NSWindowStyleMaskFullScreen)
    return ZKOrig(BOOL);
  if ([NSEvent modifierFlags] & NSEventModifierFlagCommand)
    return ZKOrig(BOOL);
  return NO;
}

static char const *const ZoomerPreZoomFrameKey = "ZoomerPreZoomFrameKey";

// Custom zoom action: toggle between zoomed and original frame
- (void)zoom:(id)sender {
  NSWindow *window = (NSWindow *)self;
  NSRect current = window.frame;
  NSRect visible = window.screen.visibleFrame;

  // Check if we are already zoomed (roughly)
  BOOL isZoomed = (ABS(current.origin.x - visible.origin.x) < 2 &&
                   ABS(current.origin.y - visible.origin.y) < 2 &&
                   ABS(current.size.width - visible.size.width) < 2 &&
                   ABS(current.size.height - visible.size.height) < 2);

  if (isZoomed) {
    NSValue *saved = objc_getAssociatedObject(self, ZoomerPreZoomFrameKey);
    if (saved) {
      [window setFrame:[saved rectValue] display:YES animate:YES];
      objc_setAssociatedObject(self, ZoomerPreZoomFrameKey, nil,
                               OBJC_ASSOCIATION_RETAIN_NONATOMIC);
      return;
    }
  } else {
    // Save current frame before zooming
    objc_setAssociatedObject(self, ZoomerPreZoomFrameKey,
                             [NSValue valueWithRect:current],
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }

  // Zoom to full visible frame
  [window setFrame:visible display:YES animate:YES];
}

@end