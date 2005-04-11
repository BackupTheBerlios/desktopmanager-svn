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

static CGSValue kCGSWindowTitle = NULL;
void _ensure_kCGSWindowTitle() {
	if(!kCGSWindowTitle) {
		kCGSWindowTitle = CGSCreateCStringNoCopy("kCGSWindowTitle");
	}
}

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
		_ownerName = nil;
	}
	return mySelf;
}

- (void) dealloc
{
	if(_ownerName)
		[_ownerName release];
	[super dealloc];
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

- (NSString*) windowTitle {
	CGSValue windowTitle = NULL;
	OSStatus retVal;
    CGSConnection connection = _CGSDefaultConnection();
	
	_ensure_kCGSWindowTitle();
	
	if(retVal = CGSGetWindowProperty(connection, _wid, 
									 kCGSWindowTitle, &windowTitle)) {
		NSLog(@"Error getting window title for wid %i.", _wid);
		return nil;
	}
	
	char *strVal = CGSCStringValue(windowTitle);
	if(strVal) {
		return [NSString stringWithUTF8String: strVal];
	}
	
	return nil;
}

- (int) windowLevel {
    CGSConnection connection = _CGSDefaultConnection();
    int level = -1;
    OSStatus retVal;
    
    if(retVal = CGSGetWindowLevel(connection, _wid, &level)) {
        NSLog(@"Error getting window level: %i", retVal);
    }
    
    return level;
}

- (pid_t) ownerPid {
	OSStatus retVal;
	CGSConnection connection = _CGSDefaultConnection();
	CGSConnection ownerCID;
	
	if(retVal = CGSGetWindowOwner(connection, _wid, &ownerCID)) {
		NSLog(@"Error getting window owner: %i\n", retVal);
		return 0;
	}
	
	pid_t pid = 0;
	if(retVal = CGSConnectionGetPID(ownerCID, &pid, ownerCID)) {
		NSLog(@"Error getting connection PID: %i\n", retVal);
	}
	
	return pid;
}

- (NSString*) ownerName {
    if(_ownerName == nil) {
        CFStringRef strProcessName;
        ProcessSerialNumber psn = [self ownerPSN];
        int retVal;
		
        if(retVal = CopyProcessName(&psn, &strProcessName)) {
            NSLog(@"Error getting process name: %i\n", retVal);
        }
        
        _ownerName = (NSString*) strProcessName;
    }
	
    return _ownerName;
}

- (ProcessSerialNumber) ownerPSN {
    ProcessSerialNumber psn;
	
    int retVal;
    if(retVal = GetProcessForPID([self ownerPid], &psn)) {
        NSLog(@"Error getting PSN from PID: %i\n", retVal);
    }
	
    return psn;
}

- (void) makeOwnerActive
{
    OSStatus retVal;
    ProcessSerialNumber psn = [self ownerPSN];
    if(retVal = SetFrontProcess(&psn)) {
        NSLog(@"Error focusing owner: %i\n", (int)retVal);
    }
}

- (NSImage*) ownerIcon
{
	NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
	return [workspace iconForFile:[workspace fullPathForApplication:[self ownerName]]];
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
