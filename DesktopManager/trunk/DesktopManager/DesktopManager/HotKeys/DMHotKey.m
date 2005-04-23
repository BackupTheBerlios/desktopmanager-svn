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

#import "DMHotKey.h"

#import <Carbon/Carbon.h>

@implementation DMHotKey

+ (id) hotKey
{
	return [[[DMHotKey alloc] init] autorelease];
}

+ (id) hotKeyWithKeycode: (int) kcode modifiers: (int) mfier
{
    return [[[DMHotKey alloc] initWithKeycode: kcode modifiers: mfier] autorelease];
}

- (id) init
{
	id mySelf = [super init];
	if(mySelf)
	{
		_registered = NO;
		_target = nil;
		_keycode = -1; 
		_modifiers = 0;
		_description = nil;
		
		// Register our interest in hotkey notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hotKeyPressedNotification:) name:@"DMInternalHotKeyPress" object:nil];
	}
	return mySelf;
}

- (id) initWithKeycode: (int) kcode modifiers: (int) mdfer 
{
    id mySelf = [self init];
    if(mySelf)
	{
		[self setKeycode:kcode];
		[self setModifiers:mdfer];
    }
    return mySelf;
}

- (id) initWithHotKey: (DMHotKey*) key
{
    id mySelf = [self init];
    if(mySelf)
	{
		[self setKeycode:[key keycode]];
		[self setModifiers:[key modifiers]];
		[self setEnabled: [key isEnabled]];
    }
    return mySelf;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];

	[self setName: nil];
	
	if(_target)
		[_target release];
	
    if(_registered) { 
		[self setEnabled: NO]; 
	}
    [super dealloc];
}

- (NSString*) name
{
	return _description;
}

- (void) setName: (NSString*) description
{
	[self willChangeValueForKey:@"name"];
	if(_description)
		[_description release];
	_description = [description retain];
	[self didChangeValueForKey:@"name"];
}

- (void) setTarget: (id) target
{
	if(_target)
		[_target release];
	_target = target ? [target retain] : nil;
}

- (id) target
{
	return _target;
}

- (void) setAction: (SEL) action
{
	_action = action;
}

- (SEL) action
{
	return _action;
}

- (BOOL) isEnabled {
	return _registered;
}

- (void) setEnabled: (BOOL) enabled {
	if(enabled == _registered) {
		return;
	}
	if(_keycode < 0)
		return;
	
	if(!enabled && _registered) {
		UnregisterEventHotKey(myRef);
		myRef = NULL;
		_registered = NO;
	} else if(enabled && !_registered) {
		EventHotKeyID hotKeyID;
		EventHotKeyRef hotkeyRef;
		hotKeyID.id = (int)self; 
		OSStatus retVal = RegisterEventHotKey([self keycode], [self carbonModifiers], hotKeyID,
											  GetApplicationEventTarget(), 0, &hotkeyRef);
		if(retVal) {
			NSLog(@"Error registering hot key");
		} else {
			myRef = hotkeyRef;
			_registered = YES;
		}
	}
}

- (void) hotKeyPressedNotification: (NSNotification*) notification {
    NSValue *value = [notification object];
    EventHotKeyRef hotKeyRef;
    [value getValue: &hotKeyRef];
	
    if(hotKeyRef == myRef) {
		// We were pressed - perform action.
		if(_target && [_target respondsToSelector:_action])
		{
			[NSApp sendAction:_action to:_target from:self];
		}
    }
}

- (int) keycode
{
    return _keycode;
}

- (int) modifiers
{
    return _modifiers;
}

- (int) carbonModifiers
{
    int cmod = 0;
    if(_modifiers & NSCommandKeyMask) { cmod |= cmdKey; }
    if(_modifiers & NSAlternateKeyMask) { cmod |= optionKey; }
    if(_modifiers & NSShiftKeyMask) { cmod |= shiftKey; }
    if(_modifiers & NSControlKeyMask) { cmod |= controlKey; }
    
    return cmod;
}

- (void) setKeycode: (int) keycode
{
	[self willChangeValueForKey:@"stringRepresentation"];
    _keycode = keycode;
    if([self isEnabled])
	{
		/* Force a re-registering */
		[self setEnabled:NO];
		[self setEnabled:YES];
	}
	[self didChangeValueForKey:@"stringRepresentation"];
}

- (void) setModifiers: (int) modifiers
{
	[self willChangeValueForKey:@"stringRepresentation"];
    _modifiers = modifiers;
    if([self isEnabled]) { 
		/* Force a re-registering */
		[self setEnabled:NO];
		[self setEnabled:YES];
    }
	[self didChangeValueForKey:@"stringRepresentation"];
}

NSString *C2S(unichar ch) {
	return [NSString stringWithCharacters: &ch length: 1];	
}

NSString *_charCodeToString(unichar charCode, int keyCode) {
	switch(charCode) {
		case kFunctionKeyCharCode:
			switch(keyCode) {
				case 122:
					return @"F1";
					break;
				case 120:
					return @"F2";
					break;
				case 99:
					return @"F3";
					break;
				case 118:
					return @"F4";
					break;
				case 96:
					return @"F5";
					break;
				// No F6
				case 98:
					return @"F7";
					break;
				case 100:
					return @"F8";
					break;
				case 101:
					return @"F9";
					break;
				case 109:
					return @"F10";
					break;
				case 103:
					return @"F11";
					break;
				case 111:
					return @"F12";
					break;
				case 105:
					return @"F13";
					break;
			}
			break;
		case kRightArrowCharCode:
			return C2S(0x2192);
			break;
		case kLeftArrowCharCode:
			return C2S(0x2190);
			break;
		case kUpArrowCharCode:
			return C2S(0x2191);
			break;
		case kDownArrowCharCode:
			return C2S(0x2193);
			break;
		case kBackspaceCharCode:
			return C2S(0x232b);
			break;
		case kHomeCharCode:
			return C2S(0x2196);
			break;
		case kSpaceCharCode:
			return @"Space";
			break;
		case kReturnCharCode:
			return C2S(0x23CE);
			break;	
		case kEscapeCharCode:
			return C2S(0x238B);
			break;	
	}
	
	// NSLog(@"CharCode: %i", charCode);
	
	return [C2S(charCode) uppercaseString];
}

- (NSString*) stringRepresentation {
	if(_keycode < 0)
		return @"-";
	
	NSMutableString *string = [NSMutableString string];
	if(_modifiers & NSControlKeyMask) {
		[string appendString: @"Ctrl-"];
	}
	if(_modifiers & NSShiftKeyMask) {
		[string appendString: C2S(0x21E7)];
	}
	if(_modifiers & NSAlternateKeyMask) {
		[string appendString: C2S(0x2325)];
	}
	if(_modifiers & NSCommandKeyMask) {
		[string appendString: C2S(0x2318)];
	}

	KeyboardLayoutRef kbdLayout;
	if(KLGetCurrentKeyboardLayout(&kbdLayout) != noErr)
		return @"?";
	KeyboardLayoutKind layout_kind;
	if(KLGetKeyboardLayoutProperty(kbdLayout,kKLKind,(const void**)&layout_kind) != noErr)
		return @"??";
	
	if((layout_kind == kKLuchrKind) || (layout_kind == kKLKCHRuchrKind)) {
		/* Try uchr */
		UCKeyboardLayout* layout = NULL;
		
		KLGetKeyboardLayoutProperty(kbdLayout,kKLuchrData, (const void**) &layout);
		unichar uniStr[10];
		UInt32 deadKeyState = 0;
		UniCharCount length;
		if(layout && (UCKeyTranslate(layout,(UInt16) [self keycode],kUCKeyActionDisplay,0,LMGetKbdType(),0,&deadKeyState,10,&length,uniStr) == noErr))
		{	
			[string appendString: _charCodeToString(uniStr[0], _keycode)];
			return string;
		}
	} else if(layout_kind == kKLKCHRKind) 
	{
		/* Try using KCHR */
		Handle kchrHandle;
		
		KLGetKeyboardLayoutProperty(kbdLayout, kKLKCHRData, (const void**) &kchrHandle);
		
		if(kchrHandle) {
			UInt32 state = 0;
			UInt32 charCode = KeyTranslate(kchrHandle, _keycode, &state);
			
			[string appendString: _charCodeToString(charCode, _keycode)];
			
			return string;
		}
	}
	
	return @"Error";
}

- (id) copyWithZone: (NSZone*) zone
{
    DMHotKey *hk= [[[DMHotKey allocWithZone: zone] initWithHotKey:self] autorelease];
	return hk;
}
@end
