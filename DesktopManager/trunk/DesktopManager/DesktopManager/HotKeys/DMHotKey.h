/* HotKey.h -- Interface for Hot key management */

/* DesktopManager -- A virtual desktop provider for OS X
 *
 * Copyright (C) 2003, 2004 Richard J Wareham <richwareham@users.sourceforge.net>
 * This program is free software; you can redistribute it and/or modify it 
 * under the terms of the GNU General Public License as published by the Free 
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but 
 * WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
 * or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License 
 * for more details.
 *
 * You should have received a copy of the GNU General Public License along 
 * with this program; if not, write to the Free Software Foundation, Inc., 675 
 * Mass Ave, Cambridge, MA 02139, USA.
 */

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

#define HOTKEY_LEFTARROWCHAR    0x2190
#define HOTKEY_UPARROWCHAR      0x2191
#define HOTKEY_RIGHTARROWCHAR   0x2192
#define HOTKEY_DOWNARROWCHAR    0x2193
    
@interface DMHotKey : NSObject {
    int keycode;
    int modifiers;
    BOOL registered;
	BOOL _wasRegistered;
	BOOL _enabled;
    EventHotKeyRef myRef;
	
	id _target;
	SEL _action;
}

+ (id) hotKeyWithKeycode: (int) keycode modifiers: (int) modifier;
- (id) initWithKeycode: (int) keycode modifiers: (int) modifier;
- (id) initWithHotKey: (DMHotKey*) key;

- (void) registerHotKey;
- (void) unregisterHotKey;
- (BOOL) isRegistered;

- (int) keycode;
- (int) modifiers;
- (int) carbonModifiers;

- (void) setTarget: (id) target;
- (id) target;
- (void) setAction: (SEL) action;
- (SEL) action;

- (void) setKeycode: (int) keycode;
- (void) setModifiers: (int) modifiers;

- (NSString*) stringValue;

- (BOOL) enabled;
- (void) setEnabled: (BOOL) enabled;

- (id) copyWithZone: (NSZone*) zone;

@end
