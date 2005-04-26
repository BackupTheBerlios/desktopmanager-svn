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

#import "CGWorkspace.h"
#import "CGWindow.h"
#import "CGSPrivate.h"

NSString *CGWorkspaceWillChangeNotification = @"CGWorkspaceWillChangeNotification";
NSString *CGWorkspaceDidChangeNotification = @"CGWorkspaceDidChangeNotification";

NSString *CGWorkspaceFromNumberKey = @"CGWorkspaceFromNumberKey";
NSString *CGWorkspaceToNumberKey = @"CGWorkspaceToNumberKey";

CGSTransitionType _defaultTransitionType = CGSFade;
CGSTransitionOption _defaultTransitionOption = CGSDown;

@implementation CGWorkspace

+ (int) defaultTransition { return _defaultTransitionType; }
+ (int) defaultTransitionOption { return _defaultTransitionOption; }
+ (void) setDefaultTransition: (int) transition
{
	_defaultTransitionType = transition;
}
+ (void) setDefaultTransitionOption: (int) direction
{
	_defaultTransitionOption = direction;
}

- (id) init
{
	id mySelf = [super init];
	if(mySelf)
	{
		_windowList = [[NSMutableArray array] retain];
	}
	return mySelf;
}

- (id) initRepresentingWorkspace: (int) number
{
	id mySelf = [self init];
	if(mySelf)
	{
		[self setWorkspaceNumber: number];
	}
	return mySelf;
}

- (void) dealloc
{
	if(_windowList)
		[_windowList release];
	[super dealloc];
}

- (NSArray*) refreshCachedWindowList
{
	int windowCount = -1;
	int wsNum = [self workspaceNumber];
	CGSConnection cid = _CGSDefaultConnection();
	
	[_windowList removeAllObjects];
	
	CGSGetWorkspaceWindowCount(cid,wsNum,&windowCount);
	if(windowCount > 0)
	{
		CGSWindow *windowBuffer = malloc(windowCount * sizeof(CGSWindow));
		CGSGetWorkspaceWindowList(cid, wsNum, windowCount, windowBuffer, &windowCount);
		int i;
		for(i=windowCount-1; i>=0; i--)
		{
			CGWindow *window = [[[CGWindow alloc] autorelease] initWithWindowNumber: windowBuffer[i]];
			[_windowList addObject: window];
		}
		free(windowBuffer);
	}
	
	return _windowList;
}

- (NSArray*) cachedWindowList
{
	return _windowList;
}

- (int) workspaceNumber
{
	return _workspaceNumber;
}

- (void) setWorkspaceNumber: (int) number
{
	_workspaceNumber = number;
}

- (BOOL) isCurrentWorkspace
{
	CGSConnection cid = _CGSDefaultConnection();
	int currentWorkspaceNumber = -1;
	CGSGetWorkspace(cid, &currentWorkspaceNumber);
	return (currentWorkspaceNumber == [self workspaceNumber]);
}

- (void) makeCurrentWithTransition: (int) transition option: (int) option time: (float) seconds;
{
        /* No need to do this if we /are/ the current workspace */
        if([self isCurrentWorkspace])
                return;

	CGSConnection cid = _CGSDefaultConnection();
	int currentWorkspaceNumber = -1;
	CGSGetWorkspace(cid, &currentWorkspaceNumber);
	
	/* Provide warning. */
	[[NSNotificationCenter defaultCenter] postNotificationName:CGWorkspaceWillChangeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt: currentWorkspaceNumber], CGWorkspaceFromNumberKey,
			[NSNumber numberWithInt: [self workspaceNumber]], CGWorkspaceToNumberKey,
		nil]];
		
	int transNo = -1;
	CGSTransitionSpec transSpec;
	
	transSpec.type = transition;
	transSpec.option = option;
	transSpec.wid = 0;
	transSpec.backColour = 0;
	
	CGSNewTransition(cid, &transSpec, &transNo);
	CGSSetWorkspace(cid,[self workspaceNumber]);
	usleep(10000);
	CGSInvokeTransition(cid, transNo, seconds);
		
	/* Provide notification. */
	[[NSNotificationCenter defaultCenter] postNotificationName:CGWorkspaceDidChangeNotification object:self userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt: currentWorkspaceNumber], CGWorkspaceFromNumberKey,
		[NSNumber numberWithInt: [self workspaceNumber]], CGWorkspaceToNumberKey,
		nil]];
}

- (void) makeCurrent: (id) sender
{
	[self makeCurrentWithTransition:_defaultTransitionType option:_defaultTransitionOption time: 0.2];
}

/* Comparison operations */

- (unsigned) hash
{
	return [[NSNumber numberWithInt: [self workspaceNumber]] hash];
}

- (BOOL) isEqual: (id) anObject
{
	if(![anObject isKindOfClass:[self class]])
		return NO;
	CGWorkspace *ws = (CGWorkspace*) anObject;
	return [ws workspaceNumber] == [self workspaceNumber];
}

- (id)copyWithZone:(NSZone *)zone
{
	CGWorkspace *ws = [[CGWorkspace allocWithZone:zone] initRepresentingWorkspace:_workspaceNumber];
}

@end
