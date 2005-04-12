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
#import <Cocoa/Cocoa.h>

/* NSWindow additions */
@class CGWindow;
@class CGWorkspace;

@interface NSWindow (CoreGraphics)
- (CGWindow*) cgWindow;
@end

@interface CGWindow : NSObject {
	int _wid;
	NSString *_ownerName;
}

- (id) initWithWindowNumber: (int) wid;
- (int) windowNumber;

- (NSString*) windowTitle;
- (int) windowLevel;

- (BOOL) isSticky;
- (void) setSticky: (BOOL) sticky;

- (CGWorkspace*) workspace;
- (void) setWorkspace: (CGWorkspace*) ws;

- (NSImage*) ownerIcon;
- (pid_t) ownerPid;
- (ProcessSerialNumber) ownerPSN;
- (void) makeOwnerActive;
- (NSString*) ownerName;

- (NSRect) frame;

@end
