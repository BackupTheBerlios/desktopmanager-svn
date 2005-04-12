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

#import "DMDesktopsPreferences.h"

#import "CoreGraphics/CGWorkspace.h"

#import "DesktopManager/DMAppController.h"
#import "DesktopManager/Pager/DMPager.h"
#import "DesktopManager/Pager/DMPagerCell.h"

@interface DMDesktopsPrefsPagerCell : DMPagerCell {
}
@end

@implementation DMDesktopsPrefsPagerCell

- (BOOL) shouldHighlight
{
	return ([self state] == NSOnState);
}

@end

@interface DMDesktopsPrefsPager : DMPager {
}
@end

@implementation DMDesktopsPrefsPager
@end

@implementation DMDesktopsPrefsPager (Internal)

- (void) synchroniseWithController 
{
	[super synchroniseWithController];
	
	/* Set appropriate target and actions */
	NSEnumerator *cellEnumerator = [[self cells] objectEnumerator];
	DMDesktopsPrefsPagerCell *cell;
	while(cell = [cellEnumerator nextObject])
	{
		[cell setTarget: [self target]];
		[cell setAction: [self action]];
	}
}

@end

@implementation DMDesktopsPreferences

- (NSString*) mainNibName
{
	return @"DesktopsPrefs";
}

- (void) updatePager
{
	[_pager setNeedsDisplay: YES];
	[_pager setCellSize: NSMakeSize(50,40)];
	[_pager sizeToCells];
	[_pager selectCellAtRow:0 column:0];
	[_pager sendAction];
}

- (void) desktopSelected: (id) sender
{
	[self willChangeValueForKey:@"currentDesktopName"];
	[self didChangeValueForKey:@"currentDesktopName"];
}

- (void) mainViewDidLoad
{
	DMAppController *controller = [DMAppController defaultController];
	
	[_appControllerController setContent: controller];
	
	[_pager setCellClass:[DMDesktopsPrefsPagerCell class]];
	[_pager setMode: NSRadioModeMatrix];
	[_pager setAppController: controller];
	
	[_pager setTarget: self];
	[_pager setAction: @selector(desktopSelected:)];
		
	[controller addObserver:self forKeyPath:@"rows" options:NSKeyValueObservingOptionNew context:nil];
	[controller addObserver:self forKeyPath:@"columns" options:NSKeyValueObservingOptionNew context:nil];
	
	[self updatePager];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self updatePager];
}

- (NSString*) currentDesktopName
{
	DMPagerCell *cell = [_pager selectedCell];
	CGWorkspace *ws = [cell representedObject];
	
	return [ws name];
}

- (void) setCurrentDesktopName: (NSString*) name
{
	DMPagerCell *cell = [_pager selectedCell];
	CGWorkspace *ws = [cell representedObject];
	[ws setName: name];
}

@end
