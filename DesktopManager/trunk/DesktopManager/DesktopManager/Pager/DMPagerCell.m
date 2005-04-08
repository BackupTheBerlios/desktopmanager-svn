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
#import "DMPagerCell.h"
#import "CoreGraphics/CGWorkspace.h"
#import "CoreGraphics/CGWindow.h"

@implementation DMPagerCell

- (BOOL) isOpaque
{
	return NO;
}

- (id) init
{
	id mySelf = [super init];
	if(mySelf)
	{
		[self setBordered: NO];
	}
	return mySelf;
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	[NSGraphicsContext saveGraphicsState];
	[NSBezierPath clipRect:cellFrame];
	CGWorkspace *ws = nil;
	if([[self representedObject] isKindOfClass: [CGWorkspace class]])
	{
		ws = [self representedObject];
	}
	
	if(!ws)
		return;
	
	NSRect screenFrame = NSMakeRect(0,0,0,0);
	NSEnumerator *screenEnum = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while(screen = [screenEnum nextObject])
	{
		screenFrame = NSUnionRect(screenFrame, [screen frame]);
	}
	
	if([ws isCurrentWorkspace])
	{
		[[[NSColor selectedControlColor] colorWithAlphaComponent:0.5] set];
	} else {
		[[[NSColor controlShadowColor] colorWithAlphaComponent:0.5] set];
	}
	NSRectFillUsingOperation(cellFrame, NSCompositeSourceOver);
	
	NSEnumerator *windowEnum = [[ws cachedWindowList] objectEnumerator];
	CGWindow *window;
	NSRect frame;
	while(window = [windowEnum nextObject])
	{
		frame = [window frame];
		frame = NSOffsetRect(frame, -screenFrame.origin.x, -screenFrame.origin.y);
		frame.origin.x /= screenFrame.size.width;
		frame.origin.y /= screenFrame.size.height;
		frame.size.width /= screenFrame.size.width;
		frame.size.height /= screenFrame.size.height;
		
		frame.origin.x *= cellFrame.size.width;
		frame.origin.y *= cellFrame.size.height;
		frame.size.width *= cellFrame.size.width;
		frame.size.height *= cellFrame.size.height;
		
		frame = NSOffsetRect(frame, cellFrame.origin.x, cellFrame.origin.y);
		
		frame = NSIntegralRect(frame);
		
		[[[NSColor lightGrayColor] colorWithAlphaComponent:0.75] set];
		NSRectFill(frame);
		[[[NSColor darkGrayColor] colorWithAlphaComponent: 0.75] set];
		NSFrameRect(frame);
	}
		
	if([ws isCurrentWorkspace])
	{
		[[NSColor darkGrayColor] set];
	} else {
		[[NSColor blackColor] set];
	}
	
	NSFrameRect(cellFrame);
	[NSGraphicsContext restoreGraphicsState];
}

- (NSSize) cellSize
{
	return [self cellSizeForBounds: NSMakeRect(0,0, 40,40)];
}

- (NSSize)cellSizeForBounds:(NSRect)aRect
{
	float aspect = 1.0;
	NSRect screenFrame = NSMakeRect(0,0,0,0);
	NSEnumerator *screenEnum = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while(screen = [screenEnum nextObject])
	{
		screenFrame = NSUnionRect(screenFrame, [screen frame]);
	}
	
	aspect = screenFrame.size.width / screenFrame.size.height;
	
	NSSize size;
	size.height = aRect.size.height;
	size.width = size.height * aspect;
	
	return size;
}

@end
