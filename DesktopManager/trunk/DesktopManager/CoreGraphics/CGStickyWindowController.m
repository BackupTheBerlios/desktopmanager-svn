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

#import "CGStickyWindowController.h"
#import "CGWorkspace.h"
#import "CGWindow.h"
#import "ExtensionUtils.h"
#import "WindowControllerEvents.h"

static CGStickyWindowController *_defaultCGStickyWindowController = nil;

@implementation CGStickyWindowController

+ (CGStickyWindowController*) defaultController
{
	if(_defaultCGStickyWindowController)
		return _defaultCGStickyWindowController;
	
	_defaultCGStickyWindowController = [[CGStickyWindowController alloc] init];
	return _defaultCGStickyWindowController;
}

- (id) init
{
	id mySelf = [super init];
	if(mySelf)
	{
		if(!_defaultCGStickyWindowController)
			_defaultCGStickyWindowController = mySelf;
		
		_stickyWindows = [[NSMutableArray array] retain];
		
		/* Make sure we know about any workspace changes */
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceWillChange:) name:CGWorkspaceWillChangeNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceDidChange:) name:CGWorkspaceDidChangeNotification object:nil];
	}
	return mySelf;
}

- (void) dealloc
{
	if(self == _defaultCGStickyWindowController)
		_defaultCGStickyWindowController = nil;
	
	if(_stickyWindows)
		[_stickyWindows release];
	
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
	[super dealloc];
}

- (void) workspaceWillChange: (NSNotification*) notification
{
	/* Set everything we are maintaining to be sticky */
	AppleEvent theEvent;
	NSEnumerator *windowEnum = [_stickyWindows objectEnumerator];
	CGWindow *window;
	while(window = [windowEnum nextObject])
	{
		makeEvent(kWindowControllerMakeSticky, &theEvent);
		addIntParm([window windowNumber], 'wid ', &theEvent);
		sendEvent(&theEvent);
	}
}

- (void) workspaceDidChange: (NSNotification*) notification
{
	/* Set everything we are maintaining to be non-sticky */
	AppleEvent theEvent;
	NSEnumerator *windowEnum = [_stickyWindows objectEnumerator];
	CGWindow *window;
	while(window = [windowEnum nextObject])
	{
		makeEvent(kWindowControllerMakeUnSticky, &theEvent);
		addIntParm([window windowNumber], 'wid ', &theEvent);
		sendEvent(&theEvent);
	}
}

- (void) addStickyWindow: (CGWindow*) window
{
	if(![_stickyWindows containsObject: window])
		[_stickyWindows addObject: window];
}

- (void) removeStickyWindow: (CGWindow*) window
{
	if([_stickyWindows containsObject:window])
		[_stickyWindows removeObject:window];
}

- (BOOL) isWindowSticky: (CGWindow*) window
{
	return [_stickyWindows containsObject: window];
}

@end
