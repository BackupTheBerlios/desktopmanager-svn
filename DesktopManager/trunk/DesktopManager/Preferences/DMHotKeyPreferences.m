/* DesktopManager -- A virtual desktop provider for OS X
*
* Copyright (C) 2003, 2004, 2005
* Richard J Wareham <richwareham@users.sourceforge.net>
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

#import "DMHotKeyPreferences.h"
#import "DesktopManager/DMAppController.h"
#import "DesktopManager/HotKeys/DMHotKey.h"

@interface DMLocaliseHotKeyDescription: NSValueTransformer {}
@end

@interface DMHotKeyFieldEditor : NSView {
	id _delegate;
	DMHotKey *_representedHotKey;
}

- (id) delegate;
- (void) setDelegate: (id) delegate;
- (DMHotKey*) representedHotKey;
- (void) setRepresentedHotKey: (DMHotKey*) hk;

@end

@implementation DMHotKeyPreferences

- (id) initWithBundle: (NSBundle*) bundle
{
	id mySelf = [super initWithBundle: bundle];
	if(mySelf) 
	{
		if(![NSValueTransformer valueTransformerForName:@"DMLocaliseHotKeyDescription"])
		{
			[NSValueTransformer setValueTransformer:[[[DMLocaliseHotKeyDescription alloc] init] autorelease] forName:@"DMLocaliseHotKeyDescription"];
		}
	}
	return mySelf;
}

- (NSString*) mainNibName
{
	return @"HotKeyPrefs";
}

- (IBAction) editKeyCombination: (id) sender
{
	[[DMAppController defaultController] willChangeValueForKey:@"hotKeys"];
	
	DMHotKeyFieldEditor *fieldEditor = [[[DMHotKeyFieldEditor alloc] initWithFrame:[_keyCombinationButton frame]] autorelease];
	[fieldEditor setDelegate: self];
	[fieldEditor setRepresentedHotKey: [[_hotKeysController selectedObjects] objectAtIndex:0]];
	[[_keyCombinationButton superview] addSubview:fieldEditor];
	[[[self mainView] window] makeFirstResponder: fieldEditor];
}

- (void) endHotKeyEditing: (DMHotKeyFieldEditor*) editor
{
	[editor removeFromSuperview];
	[[DMAppController defaultController] didChangeValueForKey:@"hotKeys"];
}

- (NSArray*) hotKeys
{
	return [[DMAppController defaultController] hotKeys];
}

@end

@implementation DMHotKeyFieldEditor

- (BOOL)acceptsFirstResponder
{
	return YES;
}

- (BOOL)resignFirstResponder
{
	if(_delegate && [_delegate respondsToSelector:@selector(endHotKeyEditing:)])
	{
		[_delegate endHotKeyEditing: self];
	}
	return YES;
}

- (BOOL)performKeyEquivalent:(NSEvent *)theEvent
{
	[self keyDown: theEvent];
	return YES;
}

- (void) keyDown: (NSEvent*) keyEvent
{
	[_representedHotKey setModifiers:[keyEvent modifierFlags]];
	[_representedHotKey setKeycode:[keyEvent keyCode]];
	
	if([[self window] firstResponder] == self) 
	{
		[[self window] makeFirstResponder: [self nextResponder]];
	}
}

- (void) drawRect: (NSRect) aRect
{
	NSButtonCell *cell = [[NSButtonCell alloc] initTextCell:@"..."];
	[cell setBezelStyle: NSShadowlessSquareBezelStyle];
	[cell setBezeled: YES];
	[cell drawWithFrame:[self bounds] inView:self];
}

- (id) delegate
{
	return _delegate;
}

- (void) setDelegate: (id) delegate
{
	if(_delegate)
		[_delegate release];
	if(delegate)
		[delegate retain];
	_delegate = delegate;
}

- (DMHotKey*) representedHotKey
{
	return _representedHotKey;
}

- (void) setRepresentedHotKey: (DMHotKey*) hk
{
	if(_representedHotKey)
		[_representedHotKey release];
	if(hk)
		[hk retain];
	_representedHotKey = hk;
}

- (void) dealloc
{
	[self setDelegate: nil];
	[self setRepresentedHotKey: nil];
	[super dealloc];
}

- (id) initWithFrame: (NSRect) frame
{
	id mySelf = [super initWithFrame:frame];
	if(mySelf)
	{
		_delegate = nil;
		_representedHotKey = nil;
	}
	return mySelf;
}

@end

@implementation DMLocaliseHotKeyDescription
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	return (value == nil) ? nil : [[NSBundle mainBundle] localizedStringForKey:value value:value table:@"HotKeyDescriptions"];
}
@end

