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


#import "DMPager.h"
#import "DesktopManager/DMAppController.h"
#import "DMPagerCell.h"

@implementation DMPager

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
		_appController = nil;
		[self setMode:NSTrackModeMatrix];
		[self setIntercellSpacing: NSMakeSize(0,0)];
		
		_redrawTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(setNeedsDisplay) userInfo:nil repeats:YES];
		[self setCellClass:[DMPagerCell class]];	
		[self setPrototype: nil];
    }
    return self;
}

- (void) dealloc
{
	if(_redrawTimer)
		[_redrawTimer invalidate];
	
	if(_appController)
	{
		[self setAppController: nil];
	}
	[super dealloc];
}

- (BOOL) isOpaque
{
	return NO;
}

- (void) awakeFromNib
{
	if(_appController)
	{
		/* Nasty, horrible hack */
		DMAppController *actemp = _appController;
		_appController = nil;
		[self setAppController: actemp];
	}
}

- (void) workspaceInfoUpdated: (NSNotification*) notification
{
	CGWorkspace *ws = [[notification userInfo] objectForKey:DMWorkspaceWithChangedInformationKey];
	if(!ws)
		return;
	
	NSEnumerator *cellEnum = [[self cells] objectEnumerator];
	DMPagerCell *cell;
	while(cell = [cellEnum nextObject])
	{
		if([[cell representedObject] isEqualTo:ws])
		{
			NSString *name = [[_appController associatedInfoForWorkspace:ws] objectForKey:@"name"];
			[self setToolTip:name forCell:cell];
		}
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	/* If rows, columns, etc change then schedule a redraw and let the
	 * magic of OOP and de-coupling do its magic. */
	if([keyPath isEqualToString: @"rows"] || [keyPath isEqualToString: @"columns"])
	{
		[self synchroniseWithController];
	}
	
	[self setNeedsDisplay: YES];
}

- (DMAppController*) appController
{
	return _appController;
}

- (void) setAppController: (DMAppController*) appController
{
	if(_appController)
	{
		[_appController removeObserver:self forKeyPath:@"rows"];
		[_appController removeObserver:self forKeyPath:@"columns"];
		[_appController removeObserver:self forKeyPath:@"currentWorkspace"];
		[[NSNotificationCenter defaultCenter] removeObserver: self];
		[_appController release];
	}
	
	_appController = [appController retain];
	[_appController addObserver:self forKeyPath:@"rows" options:NSKeyValueObservingOptionNew context:nil];
	[_appController addObserver:self forKeyPath:@"columns" options:NSKeyValueObservingOptionNew context:nil];
	[_appController addObserver:self forKeyPath:@"currentWorkspace" options:NSKeyValueObservingOptionNew context:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceInfoUpdated:) name:DMAssociatedInformationChangedNotification object:_appController];
	
	[self synchroniseWithController];
}

- (NSSize) idealCellAspectRatio
{
	NSRect screenFrame = NSMakeRect(0,0,0,0);
	NSEnumerator *screenEnum = [[NSScreen screens] objectEnumerator];
	NSScreen *screen;
	while(screen = [screenEnum nextObject])
	{
		screenFrame = NSUnionRect(screenFrame, [screen frame]);
	}
	
	return screenFrame.size;
}

- (int) idealWidthForHeight: (int) height
{
	NSSize cellSize = [self idealCellAspectRatio];
	
	if(([self numberOfColumns] == 0) || ([self numberOfRows] == 0))
		return 40;
	
	height -= [self intercellSpacing].height * ([self numberOfRows]-1);
	
	cellSize.width /= cellSize.height;
	cellSize.height = (float)height / (float)[self numberOfRows];
	cellSize.width *= cellSize.height * [self numberOfColumns];
	cellSize.width += [self intercellSpacing].width * ([self numberOfColumns]-1);
	
	return cellSize.width;
}

- (int) idealHeightForWidth: (int) width
{
	NSSize cellSize = [self idealCellAspectRatio];
	
	if(([self numberOfColumns] == 0) || ([self numberOfRows] == 0))
		return 40;
	
	width -= [self intercellSpacing].width * ([self numberOfColumns]-1);
	
	cellSize.height /= cellSize.width;
	cellSize.width = (float)width / [self numberOfColumns];
	cellSize.height *= cellSize.width * [self numberOfRows];
	cellSize.height += [self intercellSpacing].height * ([self numberOfRows]-1);
	
	return cellSize.height;	
}

- (void) makeIdealSizeForHeight: (int) height
{
	NSRect frame = [self frame];
	frame.size.width = [self idealWidthForHeight: height];
	frame.size.height = height;
	[self setFrame: frame];
}

- (void) makeIdealSizeForWidth: (int) width
{
	NSRect frame = [self frame];
	frame.size.height = [self idealHeightForWidth: width];
	frame.size.width = width;
	[self setFrame: frame];
}

@end

@implementation DMPager (Internal)

- (void) synchroniseWithController
{
	DMAppController *controller = [self appController];
	int rows = [controller rows];
	int columns = [controller columns];
	
	if((rows == 0) || (columns == 0))
		return;
	
	/* Renew rows and cols. */
	[self renewRows:rows columns: columns];
	
	/* Work out cell size */
	NSSize cellSize = [self bounds].size;
	cellSize.height -= [self intercellSpacing].height*(rows - 1);
	cellSize.width -= [self intercellSpacing].width*(columns - 1);
	cellSize.height /= [controller rows];
	cellSize.width /= [controller columns];
	[self setCellSize: cellSize];
	
	/* Set represented objects - don't ya just love OOP? */
	int i,j;
	for(i=0; i<rows; i++)
	{
		for(j=0; j<columns; j++)
		{
			CGWorkspace *ws = [controller workspaceAtRow:i column:j];
			DMPagerCell *cell = [self cellAtRow:i column:j];
			NSDictionary *dict = [controller associatedInfoForWorkspace:ws];
			if(dict)
			{
				NSString *name = [dict objectForKey:@"name"];
				if(name)
				{
					[self setToolTip:name forCell:cell];
				}
			}
			[cell setRepresentedObject:ws];
			[cell setTarget: self];
			[cell setAction: @selector(cellSelected:)];
		}
	}
	
	[self setNeedsDisplay: YES];
}

- (void) cellSelected: (id) sender
{
	DMPagerCell *cell = [self selectedCell];
	[_appController switchToWorkspace: [cell representedObject]];
}

@end
