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

#import "CGWindow.h"
#import "CGSPrivate.h"
#import "CGStickyWindowController.h"

@implementation NSWindow (CoreGraphics)
- (CGWindow*) cgWindow
{
	return [[[CGWindow alloc] autorelease] initWithWindowNumber:[self windowNumber]];
}
@end

@implementation CGWindow 

- (id) initWithWindowNumber: (int) wid
{
	id mySelf = [self init];
	if(mySelf)
	{
		_wid = wid;
	}
	return mySelf;
}

- (int) windowNumber
{
	return _wid;
}

- (NSRect) frame
{
	NSRect frame = NSMakeRect(0,0,0,0);
	CGSConnection cid = _CGSDefaultConnection();
	CGSGetScreenRectForWindow(cid,[self windowNumber],(CGRect*) &frame);
	return frame;
}

- (BOOL) isSticky
{
	CGStickyWindowController *controller = [CGStickyWindowController defaultController];

	return [controller isWindowSticky:self];
}

- (void) setSticky: (BOOL) sticky
{
	CGStickyWindowController *controller = [CGStickyWindowController defaultController];
	
	if(sticky)
	{
		if(![controller isWindowSticky:self])
		{
			[controller addStickyWindow:self];
		}
	} else {
		if([controller isWindowSticky:self])
		{
			[controller removeStickyWindow:self];
		}
	}
}

/* Comparison operations */

- (unsigned) hash
{
	return [[NSNumber numberWithInt: [self windowNumber]] hash];
}

- (BOOL) isEqual: (id) anObject
{
	if(![anObject isKindOfClass:[self class]])
		return NO;
	CGWindow *win = (CGWindow*) anObject;
	return ([win windowNumber] == [self windowNumber]);
}

@end
