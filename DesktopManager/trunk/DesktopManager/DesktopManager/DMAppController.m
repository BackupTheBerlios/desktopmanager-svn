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

#import "DMAppController.h"
#import "Pager/DMPagerCell.h"
#import "Pager/DMPager.h"
#import "HotKeys/DMHotKey.h"
#import "Preferences/DMPreferencesController.h"
#import "CoreGraphics/CGWorkspace.h"
#import "CoreGraphics/CGWindow.h"
#import "CoreGraphics/CGSPrivate.h"
#import "DockExtension/Injection/CodeInjector.h"

#import "Preferences/DMDesktopsPreferences.h"
#import "Preferences/DMPagerPreferences.h"
#import "Preferences/DMHotKeyPreferences.h"

/*
 The workspace 'array' is actually a dictionary relating co-ordinate pairs
 as strings (e.g. '0,3') to CGWorkspace objects. The rationale behind this is
 that the size, nature, etc of this array can be quite fluid with rows and
 columns being added. Ideally we want the same workspace to be added for
 'x,y' even if this has subsequently been deleted and reinserted. Consequently
 we only read in rows x columns workspaces at the start but write out
 all the configuration and use it whenever possible when filling the array.
 */

static DMAppController *_defaultDMAppController = nil;

@interface DMAppController (Private)
- (void) updateCurrentWorkspace: (NSTimer*) timer;
- (void) updateWorkspaces: (NSTimer*) timer;
@end

@implementation DMAppController

+ (DMAppController*) defaultController
{
	return _defaultDMAppController;
}

- (id) init {
	id mySelf = [super init];
	if(mySelf)
	{
		if(!_defaultDMAppController)
		{
			_defaultDMAppController = mySelf;
		}
		_workspaces = nil;
		_currentWorkspaceRefreshTimer = nil;
		_workspaceRefreshTimer = nil;
		_statusMenuItem = nil;
	}
	return mySelf;
}

- (void) dealloc
{
	if(_hotKeys)
		[_hotKeys release];
	if(_statusMenuItem)
		[_statusMenuItem release];
	if(self == _defaultDMAppController)
		_defaultDMAppController = nil;
	if(_currentWorkspaceRefreshTimer)
		[_currentWorkspaceRefreshTimer invalidate];
	if(_workspaceRefreshTimer)
		[_workspaceRefreshTimer invalidate];
	if(_workspaces)
		[_workspaces release];
	
	[super dealloc];
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
	/* Sync user defaults */
	[[NSUserDefaults standardUserDefaults] synchronize];
}

#define DEFAULT_HOTKEY(thekeycode, themodifiers, theselector, thedescription) \
	{ hk = [DMHotKey hotKeyWithKeycode: thekeycode modifiers: themodifiers]; \
	[hk setTarget: self]; \
	[hk setAction: @selector( theselector )]; \
	[hk registerHotKey]; \
	[_hotKeys addObject: [NSDictionary dictionaryWithObjectsAndKeys: \
		@#thedescription, @"description", \
		hk, @"hotkey", \
		nil]]; }

- (void) buildDefaultHotKeys
{
	DMHotKey *hk;
	[_hotKeys removeAllObjects];
	
	DEFAULT_HOTKEY(124, NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask, switchToNextWorkspace:, move_to_next_ws);
	DEFAULT_HOTKEY(123, NSCommandKeyMask | NSAlternateKeyMask | NSShiftKeyMask, switchToPreviousWorkspace:, move_to_prev_ws);
	DEFAULT_HOTKEY(123, NSCommandKeyMask | NSAlternateKeyMask, switchWorkspaceLeft:, move_to_left_ws);
	DEFAULT_HOTKEY(124, NSCommandKeyMask | NSAlternateKeyMask, switchWorkspaceRight:, move_to_right_ws);
	DEFAULT_HOTKEY(125, NSCommandKeyMask | NSAlternateKeyMask, switchWorkspaceDown:, move_to_lower_ws);
	DEFAULT_HOTKEY(126, NSCommandKeyMask | NSAlternateKeyMask, switchWorkspaceUp:, move_to_upper_ws);
	DEFAULT_HOTKEY(35, NSCommandKeyMask | NSAlternateKeyMask, showPreferences:, show_prefs);
	[hk setEnabled: NO];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	/* OK lads, here we are - first things ever done by the application.
	 * let's keep our heads and just take things one at a time. 
	 */
	
	/* Try injecting code */
	OSStatus retVal;
	if(retVal = injectCode())
	{
		NSLog(@"Error injecting Dock bundle: %i", retVal);
		
		NSAlert *alert = [[[NSAlert alloc] init] autorelease];
		[alert setMessageText:NSLocalizedString(@"Desktop Manager could not complete its own installation.", @"error message")];
		[alert setInformativeText:NSLocalizedString(@"In order to provide full functionality Desktop Manager must insert part of itself into the Dock. This operation failed. Desktop Manager will still run but some operations will be unavailable.", @"description of consequences of failing to insert into Dock.")];
		[alert runModal];
	}
	
	/* Our actual data storage. */
	/* The actual CGWorkspaces will be created 'on demand'. */	
	_workspaces = [[NSMutableDictionary dictionary] retain];
	
	/* Make sure we give 0,0 workspace 1 */
	[_workspaces setObject:[[[CGWorkspace alloc] initRepresentingWorkspace:1] autorelease] forKey:@"0,0"];
	
	/* Make sure we're informed of any workspace selection changes */
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceWillChange:) name:CGWorkspaceWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceDidChange:) name:CGWorkspaceDidChangeNotification object:nil];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:2], @"PagerRows",
		[NSNumber numberWithInt:4], @"PagerColumns",
		[NSNumber numberWithBool:YES], @"DisplayStatusPagerOnLaunch",
		[NSNumber numberWithBool:YES], @"DisplayDesktopPagerOnLaunch",
		[NSNumber numberWithFloat: 0.2], @"SwitchDuration",
		[NSNumber numberWithInt: CGSNone], @"SwitchTransition",
		nil]];

	_pagerWindow = nil;
	_pagerView = nil;
	_statusMenuItem = nil;
		
	[self setRows: [defaults integerForKey: @"PagerRows"]];
	[self setColumns: [defaults integerForKey: @"PagerColumns"]];
		
	/* Refresh current workspace at a greater frequency than others
	 * since it is the one we're most likely to modify */
	_currentWorkspaceRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateCurrentWorkspace:) userInfo:nil repeats:YES];
	_workspaceRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(updateWorkspaces:) userInfo:nil repeats:YES];
	
	_prefsController = nil;

	/* Create status menu */
	NSNib *statusNib = [[[NSNib alloc] initWithNibNamed:@"StatusBar" bundle:[NSBundle mainBundle]] autorelease];
	[statusNib instantiateNibWithOwner:self topLevelObjects:nil];
	
	_statusMenuItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
	[_statusMenuItem retain];
	[_statusMenuItem setImage:[NSImage imageNamed:@"StatusIcon"]];
	[_statusMenuItem setHighlightMode: YES];
	[_statusMenuItem setAlternateImage:[NSImage imageNamed:@"StatusIconSelected"]];
	[_statusMenuItem setMenu:_statusMenu];

	_statusPagerItem = nil;
	
	if([[NSUserDefaults standardUserDefaults] boolForKey: @"DisplayDesktopPagerOnLaunch"])
	{
		[self showDesktopPager: nil];
	}
	
	if([[NSUserDefaults standardUserDefaults] boolForKey: @"DisplayStatusPagerOnLaunch"])
	{
		[self showStatusPager: nil];
	}
	
	_hotKeys = [[NSMutableArray array] retain];
	[self buildDefaultHotKeys];
}

- (IBAction) showStatusPager: (id) sender
{
	if(_statusPagerItem)
		return;
		
	_statusPagerItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSVariableStatusItemLength];
	[_statusPagerItem retain];
	
	DMPager *statusPagerView = [[[DMPager alloc] autorelease] initWithFrame: NSMakeRect(0,0, 88, 22)]; 
	[statusPagerView setAppController: self];
	[statusPagerView setAutosizesCells: YES];
	[statusPagerView makeIdealSizeForHeight:22];
	[_statusPagerItem setView: statusPagerView];
}

- (IBAction) switchToWorkspace: (CGWorkspace*) ws
{
	if(!ws || ![ws isKindOfClass:[CGWorkspace class]])
		return;
	
	NSLog(@"Switch to %i", [ws workspaceNumber]);
	
	[ws makeCurrentWithTransition:[[NSUserDefaults standardUserDefaults] integerForKey:@"SwitchTransition"] option:CGSRight time:[[NSUserDefaults standardUserDefaults] floatForKey:@"SwitchDuration"]];
}

- (BOOL) desktopPagerVisible
{
	if(!_pagerWindow)
		return NO;
	return [_pagerWindow isVisible];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	if([menuItem action] == @selector(showDesktopPager:))
	{
		return ![self desktopPagerVisible];
	}
}

- (IBAction) showDesktopPager: (id) sender
{
	if(!_pagerWindow || !_pagerView)
	{
		/* Load desktop pager */
		NSNib *pagerNib = [[[NSNib alloc] initWithNibNamed:@"Pager" bundle:[NSBundle mainBundle]] autorelease];
		[pagerNib instantiateNibWithOwner:self topLevelObjects:nil];
		
		[_pagerWindow setBackgroundColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.3]];
		[_pagerWindow setOpaque: NO];
		[_pagerWindow setLevel: NSFloatingWindowLevel];
		[_pagerWindow setHidesOnDeactivate: NO];
		
		[_pagerView setAutosizesCells: YES];
	}
	
	/* Finally show the window */
	[_pagerWindow orderFront:nil];
	[[_pagerWindow cgWindow] setSticky: YES];
}

/* Notification of workspace change */
- (void) workspaceWillChange: (NSNotification*) notification
{
	[self willChangeValueForKey:@"currentWorkspace"];
}

- (void) workspaceDidChange: (NSNotification*) notification
{
	[self didChangeValueForKey:@"currentWorkspace"];
}

- (IBAction) showPreferences: (id) sender
{
	if(!_prefsController)
	{
		/* Load the preferences window controller */
		NSNib *prefsNib = [[[NSNib alloc] initWithNibNamed:@"Preferences" bundle:[NSBundle mainBundle]] autorelease];
		[prefsNib instantiateNibWithOwner:self topLevelObjects:nil];
		
		/* Load individual panes */
		NSPreferencePane *pane;
		pane = [[[DMDesktopsPreferences alloc] initWithBundle: [NSBundle bundleForClass:[self class]]] autorelease];
		[_prefsController addPreferencePane: pane title: NSLocalizedString(@"Desktops", @"perfpane title for desktops") icon: [NSImage imageNamed: @"pref_desktops"]];		
		pane = [[[DMHotKeyPreferences alloc] initWithBundle: [NSBundle bundleForClass:[self class]]] autorelease];
		[_prefsController addPreferencePane: pane title: NSLocalizedString(@"Hot Keys", @"perfpane title for hot keys") icon: [NSImage imageNamed: @"pref_hotkeys"]];		
		pane = [[[DMPagerPreferences alloc] initWithBundle: [NSBundle bundleForClass:[self class]]] autorelease];
		[_prefsController addPreferencePane: pane title: NSLocalizedString(@"Pagers", @"perfpane title for pagers") icon: [NSImage imageNamed: @"pref_pager"]];		
	}
	
	[_prefsController showPreferences:sender];
}

- (IBAction) switchWorkspaceRight: (id) sender
{
	int row, column;
	if(![self getCurrentWorkspaceRow:&row column:&column])
		return;
	
	column ++;
	if(column < [self columns])
	{
		[self switchToWorkspace: [self workspaceAtRow:row column:column]];
	}
}

- (IBAction) switchWorkspaceLeft: (id) sender
{
	int row, column;
	if(![self getCurrentWorkspaceRow:&row column:&column])
		return;

	column --;
	if(column >= 0)
	{
		[self switchToWorkspace: [self workspaceAtRow:row column:column]];
	}
}

- (IBAction) switchWorkspaceDown: (id) sender
{
	int row, column;
	if(![self getCurrentWorkspaceRow:&row column:&column])
		return;
	
	row ++;
	if(row < [self rows])
	{
		[self switchToWorkspace: [self workspaceAtRow:row column:column]];
	}
}

- (IBAction) switchWorkspaceUp: (id) sender
{
	int row, column;
	if(![self getCurrentWorkspaceRow:&row column:&column])
		return;
	
	row --;
	if(row >= 0)
	{
		[self switchToWorkspace: [self workspaceAtRow:row column:column]];
	}
}

- (IBAction) switchToPreviousWorkspace: (id) sender
{
	int row, column;
	if(![self getCurrentWorkspaceRow:&row column:&column])
		return;
	
	column --;
	if(column < 0)
	{
		column = [self columns] - 1;
		row --;
	}
	
	if(row >= 0)
	{
		[self switchToWorkspace:[self workspaceAtRow:row column:column]];
	}
}

- (IBAction) switchToNextWorkspace: (id) sender
{
	int row, column;
	if(![self getCurrentWorkspaceRow:&row column:&column])
		return;
	
	column ++;
	if(column >= [self columns])
	{
		column = 0;
		row ++;
	}
	
	if(row < [self rows])
	{
		[self switchToWorkspace:[self workspaceAtRow:row column:column]];
	}
}

@end

@implementation DMAppController (HotKeys)

- (NSArray*) hotKeys
{
	return _hotKeys;
}

@end

@implementation DMAppController (DataModel)

- (CGWorkspace*) workspaceAtRow: (int) row column: (int) column
{
	if((row < 0) || (row >= [self rows]))
		return nil;
	if((column < 0) || (column >= [self columns]))
		return nil;
	
	/* Do we have an existing workspace? */
	NSString *key = [NSString stringWithFormat:@"%i,%i", row, column];
	CGWorkspace *workspace = [_workspaces objectForKey: key];
	if(workspace)
		return workspace;
	
	/* Nothing already huh? Let's see if we have one in the preferences */
	NSDictionary *workspaceDescription = [[NSUserDefaults standardUserDefaults] dictionaryForKey: [NSString stringWithFormat:@"Workspace%@",key]];
	if(workspaceDescription)
	{
		/* Yup, we've got one */
		workspace = [[[CGWorkspace alloc] initRepresentingWorkspace: [[workspaceDescription objectForKey:@"number"] intValue]] autorelease];
		/* Little sanity check. */
		while([[_workspaces allKeysForObject:workspace] count])
		{
			[workspace setWorkspaceNumber: [workspace workspaceNumber]+1];
		}
		/* Save in user defaults */
		[[NSUserDefaults standardUserDefaults] setValue:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:[workspace workspaceNumber]] forKey:@"number"] forKey:[NSString stringWithFormat:@"Workspace%@", key]];
		[_workspaces setObject:workspace forKey:key];
		return workspace;
	}
	
	/* Nope nothing. Keep trying workspaces until we
	   come across an unused one. I don't like this method much but
	   it is quick to code up. */
	workspace = [[[CGWorkspace alloc] initRepresentingWorkspace: 1] autorelease];
	while([[_workspaces allKeysForObject:workspace] count])
	{
		[workspace setWorkspaceNumber: [workspace workspaceNumber]+1];
	}
	[_workspaces setObject:workspace forKey:key];
	
	/* Save in user defaults */
	[[NSUserDefaults standardUserDefaults] setValue:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:[workspace workspaceNumber]] forKey:@"number"] forKey:[NSString stringWithFormat:@"Workspace%@", key]];
	
	/* Make sure we save it */
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	return workspace;
}

- (BOOL) getCurrentWorkspaceRow: (int*) row column: (int*) column
{
	return [self getWorkspace:[self currentWorkspace] row:row column:column];
}

- (BOOL) getWorkspace: (CGWorkspace*) ws row: (int*) row column: (int*) column
{
	NSArray *keyArray = [_workspaces allKeysForObject: ws];
	if([keyArray count] < 1)
		return NO;
	
	if([keyArray count] > 1)
		NSLog(@"Err... oddness");
	
	NSString *key = [keyArray objectAtIndex: 0];
	NSArray *coords = [key componentsSeparatedByString: @","];
	if([coords count] != 2)
		return NO;
	
	if(row)
		*row = [[coords objectAtIndex: 0] intValue];
	
	if(*column)
		*column = [[coords objectAtIndex: 1] intValue];
	
	return YES;
}

- (CGWorkspace*) currentWorkspace
{
	/* For neatness' sake actually return the object we store representing
	 * the current workspace. */
	NSEnumerator *wsEnum = [_workspaces objectEnumerator];
	CGWorkspace *ws;
	while(ws = [wsEnum nextObject])
	{
		if([ws isCurrentWorkspace])
			return ws;
	}
	
	return nil;
}

- (int) maxRows { return 10; }
- (int) maxColumns { return 20; }

- (BOOL) validateRows: (id*) ioValue error: (NSError**) outError
{
	if([*ioValue intValue] < 1)
		*ioValue = [NSNumber numberWithInt:1];
	if([*ioValue intValue] > [self maxRows])
		*ioValue = [NSNumber numberWithInt:[self maxRows]];
	return YES;
}

- (BOOL) validateColumns: (id*) ioValue error: (NSError**) outError
{
	if([*ioValue intValue] < 1)
		*ioValue = [NSNumber numberWithInt:1];
	if([*ioValue intValue] > [self maxColumns])
		*ioValue = [NSNumber numberWithInt:[self maxColumns]];
	return YES;
}

- (int) rows
{
	return _rows;
}

- (void) pagerResized
{
	if(_statusPagerItem)
	{
		[(DMPager*)[_statusPagerItem view] makeIdealSizeForHeight: 22];
	}
	
	if(_pagerWindow && _pagerView)
	{
		NSSize pagerSize = [[_pagerWindow contentView] bounds].size;
		pagerSize.height = [_pagerView idealHeightForWidth: pagerSize.width];
		[_pagerWindow setContentSize: pagerSize];
		[_pagerWindow setContentAspectRatio: pagerSize];
	}
	
	[self updateWorkspaces:nil];
	[self updateCurrentWorkspace:nil];
}

- (void) setRows: (int) rows
{
	[self willChangeValueForKey:@"rows"];
	_rows = rows;
	[self didChangeValueForKey:@"rows"];
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:rows] forKey:@"PagerRows"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self pagerResized];
}

- (int) columns
{
	return _columns;
}

- (void) setColumns: (int) columns
{
	[self willChangeValueForKey:@"columns"];
	_columns = columns;
	[self didChangeValueForKey:@"columns"];
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:columns] forKey:@"PagerColumns"];
	[[NSUserDefaults standardUserDefaults] synchronize];	
	
	[self pagerResized];
}

- (NSDictionary*) associatedInfoForWorkspace: (CGWorkspace*) ws
{
	if(![[_workspaces allValues] containsObject: ws])
		return nil;
	
	NSString *key = [[_workspaces allKeysForObject:ws] objectAtIndex: 0];
	if(!key)
		return nil;
	
	NSDictionary *workspaceDescription = [[NSUserDefaults standardUserDefaults] dictionaryForKey: [NSString stringWithFormat:@"Workspace%@",key]];
	if(!workspaceDescription)
		return nil;
	
	return [workspaceDescription objectForKey:@"attributes"];
}

- (void) setAssociatedInfo: (NSDictionary*) info forWorkspace: (CGWorkspace*) ws
{
	if(![[_workspaces allValues] containsObject: ws])
		return;
	
	NSString *key = [[_workspaces allKeysForObject:ws] objectAtIndex: 0];
	if(!key)
		return;
	
	NSDictionary *workspaceDescription = [[NSUserDefaults standardUserDefaults] dictionaryForKey: [NSString stringWithFormat:@"Workspace%@",key]];
	if(!workspaceDescription)
		return;
	
	NSMutableDictionary *newInfo = [NSMutableDictionary dictionary];
	if([workspaceDescription objectForKey:@"atributes"])
	{
		[newInfo addEntriesFromDictionary: [workspaceDescription objectForKey:@"atributes"]];
	}
	[newInfo addEntriesFromDictionary:info];
	
	NSMutableDictionary *newDescription = [NSMutableDictionary dictionaryWithDictionary: workspaceDescription];
	[newDescription setObject:newInfo forKey:@"attributes"];
	[[NSUserDefaults standardUserDefaults] setObject:newDescription forKey:[NSString stringWithFormat:@"Workspace%@",key]];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

@end

@implementation DMAppController (Private)

- (void) updateCurrentWorkspace: (NSTimer*) timer
{
	[[self currentWorkspace] refreshCachedWindowList];
}

- (void) updateWorkspaces: (NSTimer*) timer
{
	NSEnumerator *wsEnum = [_workspaces objectEnumerator];
	CGWorkspace *ws;
	while(ws = [wsEnum nextObject])
	{
		if(![ws isCurrentWorkspace])
			[ws refreshCachedWindowList];
	}
}

@end

enum {
    // NSEvent subtypes for hotkey events (undocumented)
    kEventHotKeyPressedSubtype = 6,
    kEventHotKeyReleasedSubtype = 9,
};

@implementation DMApplication

- (void)sendEvent: (NSEvent*) theEvent {
    if(([theEvent type] == NSSystemDefined) && 
       ([theEvent subtype] == kEventHotKeyPressedSubtype)) {
        // Dispatch hotkey press notification.
        EventHotKeyRef hotKeyRef = (EventHotKeyRef) [theEvent data1];
        [[NSNotificationCenter defaultCenter]
          postNotificationName: @"DMInternalHotKeyPress" object: 
            [NSValue value: &hotKeyRef withObjCType: @encode(EventHotKeyRef)]];
    }
	
    [super sendEvent: theEvent];
}

@end
