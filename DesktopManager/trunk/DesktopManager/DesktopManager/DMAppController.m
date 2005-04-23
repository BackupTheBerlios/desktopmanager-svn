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
#import "Preferences/DMTransitionPreferences.h"

NSString *DMAssociatedInformationChangedNotification = @"DMAssociatedInformationChangedNotification";
NSString *DMWorkspaceWithChangedInformationKey = @"DMWorkspaceWithChangedInformationKey";

/*
 The workspace 'array' is actually a one-dimensional 
 array of objects in row-major order.
 */

static DMAppController *_defaultDMAppController = nil;

@interface DMAppController (Private)
- (void) updateCurrentWorkspace: (NSTimer*) timer;
- (void) updateWorkspaces: (NSTimer*) timer;
- (void) syncModelToRowOrColumnChange;
- (void) pagerResized;
- (void) saveHotKeysToUserDefaults;
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
		_workspaceArray = nil;
		_currentWorkspaceRefreshTimer = nil;
		_workspaceRefreshTimer = nil;
		_statusMenuItem = nil;
		_rows = 0;
		_columns = 0;
		_displaysWindowInfoAdvanced = YES;
		_foregroundWin = nil;
		_inspectorRectTag = -1;
		_inspectorFadeTimer = nil;
		_workspaceHotKeyDict = [[NSMutableDictionary dictionary] retain];
	}
	return mySelf;
}

- (void) dealloc
{
	if(_inspectorFadeTimer)
		[_inspectorFadeTimer invalidate];
	if((_inspectorRectTag >= 0) && _windowInspector)
		[[_windowInspector contentView] removeTrackingRect:_inspectorRectTag];
	if(_workspaceHotKeyDict)
		[_workspaceHotKeyDict release];
	if(_foregroundWin)
		[_foregroundWin release];
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
	if(_workspaceArray)
		[_workspaceArray release];
	
	[super dealloc];
}

- (void) didChangeValueForKey: (NSString*) key
{
	[super didChangeValueForKey:key];
	if([key isEqualToString:@"hotKeys"])
	{
	}
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if((object == _foregroundWin) && ([keyPath isEqualToString:@"sticky"]))
	{
		CGWindow *win = (CGWindow*) object;
		//NSLog(@"foreground sticky state changed to %@", [change objectForKey:NSKeyValueChangeNewKey]);
		NSMutableDictionary *winInfo = [NSMutableDictionary dictionary];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *key = [win userDefaultsKey];
		if([defaults dictionaryForKey:key]) {
			[winInfo setDictionary:[defaults dictionaryForKey:key]];
		}
		
		[winInfo setObject:[change objectForKey:NSKeyValueChangeNewKey] forKey:@"sticky"];
		[defaults setObject:winInfo forKey:key];
		[defaults synchronize];
	}
}

- (void)applicationWillTerminate:(NSNotification*)aNotification
{
	[self saveHotKeysToUserDefaults];
}

#define DEFAULT_HOTKEY(thekeycode, themodifiers, theselector, thedescription) \
	{ hk = [DMHotKey hotKeyWithKeycode: thekeycode modifiers: themodifiers]; \
	[hk setTarget: self]; \
	[hk setAction: @selector( theselector )]; \
	[hk setEnabled: YES]; \
	[hk setName: @#thedescription]; \
	[_hotKeys addObject: hk]; }

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
	DEFAULT_HOTKEY(5, NSCommandKeyMask | NSAlternateKeyMask, toggleDesktopPager:, show_desktop_pager);
	[hk setEnabled: NO];
	DEFAULT_HOTKEY(34, NSCommandKeyMask | NSAlternateKeyMask, toggleWindowInspector:, show_window_inspector);
	[hk setEnabled: NO];
	
	/* Now go through each hot key and see if we have a user preference */
	NSDictionary *userHotKeys = [[NSUserDefaults standardUserDefaults] objectForKey:@"hotKeys"];
	if(userHotKeys)
	{
		NSEnumerator *hkEnum = [_hotKeys objectEnumerator];
		DMHotKey *hk;
		while(hk = [hkEnum nextObject])
		{
			NSDictionary *hkInfo = [userHotKeys objectForKey:[hk name]];
			if(hkInfo)
			{
				[hk setModifiers: [[hkInfo objectForKey:@"modifiers"] intValue]];
				[hk setKeycode: [[hkInfo objectForKey:@"keycode"] intValue]];
				[hk setEnabled: [[hkInfo objectForKey:@"enabled"] boolValue]];
				
				// NSLog(@"hk: %@, %i, %i, %i", [hk name], [hk modifiers], [hk keycode], [hk enabled]);
			}
		}
	}
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
	/* The actual CGWorkspaces will be created by updateWorkspaceArray. */	
	_workspaceArray = [[NSMutableArray array] retain];

	
	/* Make sure we're informed of any workspace selection changes */
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceWillChange:) name:CGWorkspaceWillChangeNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(workspaceDidChange:) name:CGWorkspaceDidChangeNotification object:nil];
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults registerDefaults: [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithInt:2], @"PagerRows",
		[NSNumber numberWithInt:4], @"PagerColumns",
		[NSNumber numberWithBool:YES], @"DisplayStatusPagerOnLaunch",
		[NSNumber numberWithBool:YES], @"DisplayDesktopPagerOnLaunch",
		[NSNumber numberWithBool:YES], @"DisplayWindowInspectorOnLaunch",
		[NSNumber numberWithFloat: 0.2], @"SwitchDuration",
		[NSNumber numberWithInt: CGSNone], @"SwitchTransition",
		[NSNumber numberWithBool:NO], @"WrapDesktops",
		[NSNumber numberWithBool:YES], @"FadeInspector",
		nil]];

	_pagerWindow = nil;
	_pagerView = nil;
	_statusMenuItem = nil;
	_windowInspector = nil;	
	
	[self setRows: [defaults integerForKey: @"PagerRows"]];
	[self setColumns: [defaults integerForKey: @"PagerColumns"]];
		
	/* Refresh current workspace at a greater frequency than others
	 * since it is the one we're most likely to modify */
	_currentWorkspaceRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateCurrentWorkspace:) userInfo:nil repeats:YES];
	_workspaceRefreshTimer = [NSTimer scheduledTimerWithTimeInterval:4.14134 target:self selector:@selector(updateWorkspaces:) userInfo:nil repeats:YES];
	
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
	
	if([[NSUserDefaults standardUserDefaults] boolForKey: @"DisplayWindowInspectorOnLaunch"])
	{
		[self showWindowInspector: nil];
	}
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
	[_statusPagerItem setView: statusPagerView];
	[self pagerResized];
}

- (BOOL) showsWindowInspectorAdvanced
{
	return _displaysWindowInfoAdvanced;
}

- (void) setShowsWindowInspectorAdvanced: (BOOL) showIt
{
	[self willChangeValueForKey:@"showsWindowInspectorAdvanced"];
	NSRect newFrame = [_windowInspector frame];

	if(!showIt && [self showsWindowInspectorAdvanced])
	{
		newFrame.size.height -= [_windowInspectorShrinkView frame].size.height;
		newFrame.origin.y += [_windowInspectorShrinkView frame].size.height;
	} else if(showIt && ![self showsWindowInspectorAdvanced])
	{
		newFrame.size.height += [_windowInspectorShrinkView frame].size.height;
		newFrame.origin.y -= [_windowInspectorShrinkView frame].size.height;
	}
	
	NSSize contentSize = [_windowInspector contentRectForFrameRect:newFrame].size;
	[_windowInspector setFrame:newFrame display:YES animate:YES];
	if(_inspectorRectTag >= 0) {
		[[_windowInspector contentView] removeTrackingRect:_inspectorRectTag];
		_inspectorRectTag = [[_windowInspector contentView] addTrackingRect:NSMakeRect(0,0,contentSize.width, contentSize.height) owner:self userData:nil assumeInside:NO];
	}
	
	_displaysWindowInfoAdvanced = showIt;
	[self didChangeValueForKey:@"showsWindowInspectorAdvanced"];
}

- (IBAction) switchToWorkspace: (CGWorkspace*) ws
{
	if(!ws || ![ws isKindOfClass:[CGWorkspace class]])
		return;
	
	/* Fall back if we have no idea */
	int option = CGSLeft;
	
	int fromRow, fromCol;
	[self getCurrentWorkspaceRow:&fromRow column:&fromCol];
	
	int toRow, toCol;
	[self getWorkspace:ws row:&toRow column:&toCol];
	
	/* The orientations seem reversed here since the option directions
     * refer to the movement of the transition itself */
	if(([self rows] > 2) && (toCol == fromCol) && (toRow == 0) && (fromRow == [self rows] - 1))
	{
		/* Wrapping rows */
		option = CGSUp;
	} else if(([self columns] > 2) && (toRow == fromRow) && (toCol == 0) && (fromCol == [self columns] - 1))
	{
		/* Wrapping cols */
		option = CGSLeft;
	} else if(([self rows] > 2) && (toCol == fromCol) && (fromRow == 0) && (toRow == [self rows] - 1))
	{
		/* Wrapping rows */
		option = CGSDown;
	} else if(([self columns] > 2) && (toRow == fromRow) && (fromCol == 0) && (toCol == [self columns] - 1))
	{
		/* Wrapping cols */
		option = CGSRight;
		
	} else if(toRow > fromRow)
	{
		/* Moving down */
		option = CGSUp;
	} else if(toRow < fromRow)
	{
		/* Moving up */
		option = CGSDown;
	} else if(toCol > fromCol)
	{
		/* Moving right */
		option = CGSLeft;
	} else if(toCol < fromCol)
	{
		/* Moving left */
		option = CGSRight;
	}
	
	[ws makeCurrentWithTransition:[[NSUserDefaults standardUserDefaults] integerForKey:@"SwitchTransition"] option:option time:[[NSUserDefaults standardUserDefaults] floatForKey:@"SwitchDuration"]];
}

- (BOOL) desktopPagerVisible
{
	if(!_pagerWindow)
		return NO;
	return [_pagerWindow isVisible];
}

- (BOOL)validateMenuItem:(id <NSMenuItem>)menuItem
{
	if([_pagerWindow isVisible] && ([menuItem action] == @selector(showDesktopPager:)))
	{
		[menuItem setAction:@selector(hideDesktopPager:)];
		[menuItem setTitle:NSLocalizedString(@"Hide Desktop Pager", @"Status menu item to hide desktop pager")];
	} else if(![_pagerWindow isVisible] && ([menuItem action] == @selector(hideDesktopPager:)))
	{
		[menuItem setAction:@selector(showDesktopPager:)];
		[menuItem setTitle:NSLocalizedString(@"Show Desktop Pager", @"Status menu item to show desktop pager")];
	} else 	if([_windowInspector isVisible] && ([menuItem action] == @selector(showWindowInspector:)))
	{
		[menuItem setAction:@selector(hideWindowInspector:)];
		[menuItem setTitle:NSLocalizedString(@"Hide Window Inspector", @"Status menu item to hide inspector")];
	} else if(![_windowInspector isVisible] && ([menuItem action] == @selector(hideWindowInspector:)))
	{
		[menuItem setAction:@selector(showWindowInspector:)];
		[menuItem setTitle:NSLocalizedString(@"Show Window Inspector", @"Status menu item to show inspector")];
	}
}

- (void)mouseExited:(NSEvent *)theEvent
{
	if(!_windowInspector || 
	   ![[[NSUserDefaults standardUserDefaults] objectForKey:@"FadeInspector"] boolValue]) 
		return;

	if(_inspectorFadeTimer)
		[_inspectorFadeTimer invalidate];
	_inspectorFadeTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(startInspectorFade:) userInfo:nil repeats:NO];
}

- (void)mouseEntered:(NSEvent *)theEvent
{
	if(!_windowInspector) 
		return;
	
	if(_inspectorFadeTimer) {
		[_inspectorFadeTimer invalidate];
		_inspectorFadeTimer = nil;
	}
	
	[_windowInspector setAlphaValue:1.0];
}

- (void) inspectorFade: (NSTimer*) timer
{
	NSDate *then = (NSDate*) [timer userInfo];
	NSTimeInterval ti = [[NSDate date] timeIntervalSinceDate:then];
	
	ti /= 0.33; /* Fade time */
	
	if(ti > 1.0)
	{
		[_windowInspector setAlphaValue:0.75];
		[_inspectorFadeTimer invalidate];
		_inspectorFadeTimer = nil;
	} else {
		[_windowInspector setAlphaValue:1.0 - (ti * 0.25)];
	}
}

- (void) startInspectorFade: (NSTimer*) timer
{
	_inspectorFadeTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(inspectorFade:) userInfo:[NSDate date] repeats:YES];
}

- (IBAction) showWindowInspector: (id) sender
{
	if(!_windowInspector)
	{
		/* Load inspector */
		NSNib *inspectorNib = [[[NSNib alloc] initWithNibNamed:@"WindowInspector" bundle:[NSBundle mainBundle]] autorelease];
		[inspectorNib instantiateNibWithOwner:self topLevelObjects:nil];
		
		[_windowInspector setHidesOnDeactivate:NO];
		[_windowInspector setFloatingPanel:YES];
		
		_inspectorRectTag = [[_windowInspector contentView] addTrackingRect:[[_windowInspector contentView] bounds] owner:self userData:nil assumeInside:NO];
	}

	[_windowInspector setBecomesKeyOnlyIfNeeded:YES];
	[self setShowsWindowInspectorAdvanced: NO];
	[_windowInspector orderFront: nil];
	[[_windowInspector cgWindow] setSticky:YES];
	[_windowInspector setAlphaValue:1.0];
	
	if(_inspectorFadeTimer)
		[_inspectorFadeTimer invalidate];
	_inspectorFadeTimer = [NSTimer scheduledTimerWithTimeInterval:2.0 target:self selector:@selector(startInspectorFade:) userInfo:nil repeats:NO];
}

- (IBAction) hideWindowInspector: (id) sender
{
	[_windowInspector orderOut:nil];
}

- (IBAction) toggleWindowInspector: (id) sender
{
	if([_windowInspector isVisible])
		[self hideWindowInspector:nil];
	else
		[self showWindowInspector:nil];
}

- (IBAction) showDesktopPager: (id) sender
{
	if(!_pagerWindow || !_pagerView)
	{
		/* Load desktop pager */
		NSNib *pagerNib = [[[NSNib alloc] initWithNibNamed:@"Pager" bundle:[NSBundle mainBundle]] autorelease];
		[pagerNib instantiateNibWithOwner:self topLevelObjects:nil];
		
		[_pagerWindow setBackgroundColor: [NSColor colorWithCalibratedWhite:0.0 alpha:0.5]];
		[_pagerWindow setOpaque: NO];
		[_pagerWindow setFloatingPanel:YES];
		[_pagerWindow setHidesOnDeactivate: NO];
		
		[_pagerView setAutosizesCells: YES];
		
		[self pagerResized];
	}
	
	/* Finally show the window */
	[_pagerWindow setBecomesKeyOnlyIfNeeded:YES];
	[_pagerWindow orderFront:nil];
	[[_pagerWindow cgWindow] setSticky: YES];
}

- (IBAction) hideDesktopPager: (id) sender
{
	[_pagerWindow orderOut:nil];
}

- (IBAction) toggleDesktopPager: (id) sender
{
	if([_pagerWindow isVisible])
		[self hideDesktopPager:nil];
	else
		[self showDesktopPager:nil];
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
		pane = [[[DMHotKeyPreferences alloc] initWithBundle: [NSBundle bundleForClass:[self class]]] autorelease];
		[_prefsController addPreferencePane: pane title: NSLocalizedString(@"Hot Keys", @"perfpane title for hot keys") icon: [NSImage imageNamed: @"pref_hotkeys"]];		
		pane = [[[DMDesktopsPreferences alloc] initWithBundle: [NSBundle bundleForClass:[self class]]] autorelease];
		[_prefsController addPreferencePane: pane title: NSLocalizedString(@"Desktops", @"perfpane title for desktops") icon: [NSImage imageNamed: @"pref_desktops"]];		
		pane = [[[DMTransitionPreferences alloc] initWithBundle: [NSBundle bundleForClass:[self class]]] autorelease];
		[_prefsController addPreferencePane: pane title: NSLocalizedString(@"Transitions", @"perfpane title for transitions") icon: [NSImage imageNamed: @"pref_transition"]];		
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"WrapDesktops"])
		column %= [self columns];
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"WrapDesktops"])
	{
		column += [self columns];
		column %= [self columns];
	}
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"WrapDesktops"])
		row %= [self rows];
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
	if([[NSUserDefaults standardUserDefaults] boolForKey:@"WrapDesktops"])
	{
		row += [self rows];
		row %= [self rows];
	}
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
	
	if((row == 0) && (column == 0) && [[NSUserDefaults standardUserDefaults] boolForKey:@"WrapDesktops"])
	{
		row = [self rows] - 1;
		column = [self columns] - 1;
	} else {
		column --;
	}
	
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
	
	if((row == [self rows]-1) && (column == [self columns]-1) && [[NSUserDefaults standardUserDefaults] boolForKey:@"WrapDesktops"])
	{
		row = column = 0;
	} else {
		column ++;
	}
	
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

- (void) insertObject:(id)hotKey inHotKeysAtIndex:(unsigned int)index {
	if(![hotKey isKindOfClass:[DMHotKey class]])
	{
		NSLog(@"Attempt to insert non hot-key");
		return;
	}
	[self willChangeValueForKey:@"hotKeys"];
	[_hotKeys insertObject:hotKey atIndex:index];
	[self didChangeValueForKey:@"hotKeys"];
}

- (void) removeObjectFromHotKeysAtIndex:(unsigned int)index {
	[self willChangeValueForKey:@"hotKeys"];
	[_hotKeys removeObjectAtIndex:index];
	[self didChangeValueForKey:@"hotKeys"];
}

- (void) replaceObjectInHotKeysAtIndex:(unsigned int)index withObject: (id) hotKey
{
	if(![hotKey isKindOfClass:[DMHotKey class]])
	{
		NSLog(@"Attempt to replace non hot-key");
		return;
	}
	[self willChangeValueForKey:@"hotKeys"];
	[_hotKeys replaceObjectAtIndex:index withObject:hotKey];
	[self didChangeValueForKey:@"hotKeys"];
}

@end

@implementation DMAppController (DataModel)

- (NSArray*) workspaces
{
	return _workspaceArray;
}

- (NSArray*) associatedInfoForAllWorkspaces
{
	NSMutableArray *infoArray = [NSMutableArray array];
	
	NSEnumerator *wsEnum = [[self workspaces] objectEnumerator];
	CGWorkspace *ws;
	while(ws = [wsEnum nextObject])
	{
		[infoArray addObject:[self associatedInfoForWorkspace:ws]];
	}
	
	return infoArray;
}

- (CGWorkspace*) workspaceAtRow: (int) row column: (int) column
{
	/* Sanity check */
	if([_workspaceArray count] != [self rows] * [self columns])
	{
		NSLog(@"Error: Somehow our workspace array has got out of kilter.");
		return nil;
	}
	
	
	if((row < 0) || (row >= [self rows]))
		return nil;
	if((column < 0) || (column >= [self columns]))
		return nil;
	
	
	return [_workspaceArray objectAtIndex:column + row*[self columns]];
}

- (BOOL) getCurrentWorkspaceRow: (int*) row column: (int*) column
{
	return [self getWorkspace:[self currentWorkspace] row:row column:column];
}

- (BOOL) getWorkspace: (CGWorkspace*) ws row: (int*) row column: (int*) column
{
	if(![_workspaceArray containsObject:ws])
	{
		NSLog(@"Error: Request for location of unknown workspace %i.", [ws workspaceNumber]);
		return NO;
	}
	
	int index = [_workspaceArray indexOfObject: ws];

	if(row)
		*row = index / [self columns];
	if(column)
		*column = index % [self columns];
	
	//NSLog(@"Workspace %i at (%i,%i)", [ws workspaceNumber], index - (index % [self columns]), index % [self columns]);

	return YES;
}

- (CGWindow*) foregroundWindow
{
	return _foregroundWin;
}

- (CGWorkspace*) currentWorkspace
{
	/* For neatness' sake actually return the object we store representing
	 * the current workspace. */
	NSEnumerator *wsEnum = [_workspaceArray objectEnumerator];
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

- (void) setRows: (int) rows
{
	[self willChangeValueForKey:@"rows"];
	_rows = rows;
	[self syncModelToRowOrColumnChange];
	[self didChangeValueForKey:@"rows"];
	[self pagerResized];
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:rows] forKey:@"PagerRows"];
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (int) columns
{
	return _columns;
}

- (void) setColumns: (int) columns
{
	[self willChangeValueForKey:@"columns"];
	_columns = columns;
	[self syncModelToRowOrColumnChange];
	[self didChangeValueForKey:@"columns"];
	[self pagerResized];
	
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:columns] forKey:@"PagerColumns"];
	[[NSUserDefaults standardUserDefaults] synchronize];	
}

- (NSDictionary*) associatedInfoForWorkspace: (CGWorkspace*) ws
{
	if(![_workspaceArray containsObject: ws])
		return nil;
	
	NSDictionary *aInfo = [[NSUserDefaults standardUserDefaults] dictionaryForKey: [NSString stringWithFormat:@"Workspace%iInfo",[ws workspaceNumber]]];
	
	return aInfo ? aInfo : [NSDictionary dictionaryWithObjectsAndKeys:
		[NSString stringWithFormat:NSLocalizedString(@"Desktop %i", @"Format for untitled desktops"), [_workspaceArray indexOfObject:ws] + 1], @"name",
		nil];
}

- (void) setAssociatedInfo: (NSDictionary*) info forWorkspace: (CGWorkspace*) ws
{
	if(![_workspaceArray containsObject: ws])
		return;

	[[NSUserDefaults standardUserDefaults] setObject:info forKey:[NSString stringWithFormat:@"Workspace%iInfo",[ws workspaceNumber]]];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:DMAssociatedInformationChangedNotification object:self userInfo:[NSDictionary dictionaryWithObject:ws forKey:DMWorkspaceWithChangedInformationKey]];
}

- (DMHotKey*) hotKeyForWorkspace: (CGWorkspace*) ws
{
	DMHotKey *hk = [_workspaceHotKeyDict objectForKey:ws];
	if(!hk)
	{
		hk = [DMHotKey hotKey];
		[hk setTarget:ws];
		[hk setAction:@selector(selectWithAppController:)];
		
		NSDictionary *wsInfo = [self associatedInfoForWorkspace: ws];
		if([wsInfo objectForKey:@"hotKey"])
		{
			NSDictionary *hkInfo = [wsInfo objectForKey:@"hotKey"];
			[hk setKeycode:[[hkInfo objectForKey:@"keycode"] intValue]];
			[hk setModifiers:[[hkInfo objectForKey:@"modifiers"] intValue]];
			[hk setEnabled:[[hkInfo objectForKey:@"enabled"] boolValue]];
		}
		
		[_workspaceHotKeyDict setObject:hk forKey:ws];
	}
	return hk;
}

@end

@implementation DMAppController (Private)

- (void) saveHotKeysToUserDefaults
{
	/* Form a description of the hot keys */
	NSMutableDictionary *userHotKeys = [NSMutableDictionary dictionary];
	NSEnumerator *hkEnum = [_hotKeys objectEnumerator];
	DMHotKey *hk;
	while(hk = [hkEnum nextObject])
	{
		//NSLog(@"hk: %@ - %i", [hk name], [hk isEnabled]);
		NSDictionary *hkInfo = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:[hk modifiers]], @"modifiers",
			[NSNumber numberWithInt:[hk keycode]], @"keycode",
			[NSNumber numberWithBool:[hk isEnabled]], @"enabled",
			nil];
		[userHotKeys setObject:hkInfo forKey:[hk name]];
	}
	
	[[NSUserDefaults standardUserDefaults] setObject:userHotKeys forKey:@"hotKeys"];
	
	/* Update per-desktop hot keys */
	NSEnumerator *wsEnum = [_workspaceArray objectEnumerator];
	CGWorkspace *ws;
	while(ws = [wsEnum nextObject])
	{
		NSMutableDictionary *newInfo = [NSMutableDictionary dictionary];
		NSDictionary *wsInfo = [self associatedInfoForWorkspace: ws];
		if(wsInfo)
		{
			[newInfo setDictionary:wsInfo];
		}
		
		NSMutableDictionary *hkInfo = [NSMutableDictionary dictionary];
		if([newInfo objectForKey:@"hotKey"])
		{
			[hkInfo setDictionary:[newInfo objectForKey:@"hotKey"]];
		}
		
		DMHotKey *hk = [self hotKeyForWorkspace:ws];
		[hkInfo setObject:[NSNumber numberWithInt:[hk keycode]] forKey:@"keycode"];
		[hkInfo setObject:[NSNumber numberWithInt:[hk modifiers]] forKey:@"modifiers"];
		[hkInfo setObject:[NSNumber numberWithBool:[hk isEnabled]] forKey:@"enabled"];
		
		[newInfo setObject:hkInfo forKey:@"hotKey"];
		[self setAssociatedInfo:newInfo forWorkspace:ws];
	}
	
	/* Sync user defaults */
	[[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) newWindows: (NSArray*) windows onWorkspace: (CGWorkspace*) ws
{
	CGWindow *win;
	NSEnumerator *winEnum = [windows objectEnumerator];
	while(win = [winEnum nextObject]) 
	{
		NSString *winKey = [win userDefaultsKey];
		NSDictionary *winInfo = [[NSUserDefaults standardUserDefaults] dictionaryForKey: winKey];
		if(winInfo) 
		{
			/* We have some properties stored! */
			if([winInfo objectForKey:@"sticky"])
				[win setSticky:[[winInfo objectForKey:@"sticky"] boolValue]];
		}
	}
}

- (void) updateCurrentWorkspace: (NSTimer*) timer
{
	CGWorkspace *ws = [self currentWorkspace];
	NSSet *oldList = [NSSet setWithArray: [ws cachedWindowList]];
	[ws refreshCachedWindowList];
	NSMutableSet *windowSet = [NSMutableSet setWithArray:[ws cachedWindowList]];
	[windowSet minusSet:oldList];
	
	if([windowSet count]) {
		[self newWindows: [windowSet allObjects] onWorkspace: ws];
	}
	
	NSArray *list = [ws cachedWindowList];
	int i = [list count] - 1;
	CGWindow *win = nil;
	BOOL found = NO;
	while((i>=0) && !found) {
		win = [list objectAtIndex:i];
		found = win && ([win windowLevel] == NSNormalWindowLevel) && ([[win ownerName] isNotEqualTo: [[NSProcessInfo processInfo] processName]]);
		i--;
	}
	
	if(found && (_foregroundWin != win)) {
		[self willChangeValueForKey:@"foregroundWindow"];
		if(_foregroundWin) {
			[_foregroundWin removeObserver:self forKeyPath:@"sticky"];
			[_foregroundWin release];
		}
		_foregroundWin = [win retain];
		[_foregroundWin addObserver:self forKeyPath:@"sticky" options:NSKeyValueObservingOptionNew context:nil];
		[self didChangeValueForKey:@"foregroundWindow"];
	} else if(!found && _foregroundWin) {
		[self willChangeValueForKey:@"foregroundWindow"];
		if(_foregroundWin) {
			[_foregroundWin removeObserver:self forKeyPath:@"sticky"];
			[_foregroundWin release];
		}
		_foregroundWin = nil;
		[self didChangeValueForKey:@"foregroundWindow"];
	}
}

- (void) updateWorkspaces: (NSTimer*) timer
{
	NSEnumerator *wsEnum = [_workspaceArray objectEnumerator];
	CGWorkspace *ws;
	while(ws = [wsEnum nextObject])
	{
		NSSet *oldList = [NSSet setWithArray: [ws cachedWindowList]];
		if(![ws isCurrentWorkspace])
			[ws refreshCachedWindowList];
		NSMutableSet *windowSet = [NSMutableSet setWithArray:[ws cachedWindowList]];
		[windowSet minusSet:oldList];
		
		if([windowSet count]) {
			[self newWindows: [windowSet allObjects] onWorkspace: ws];
		}
	}
}

- (void) syncModelToRowOrColumnChange
{
	if((_rows == 0) || (_columns == 0))
		return;
	
	/* Synchronise workspace array */
	[_workspaceArray removeAllObjects];
	int i;
	for(i=1; i<=_rows*_columns; i++)
	{
		CGWorkspace *ws = [[[CGWorkspace alloc] autorelease] initRepresentingWorkspace:i];
		[_workspaceArray addObject:ws];
	}
	
	/* Remove hot keys for no longer present workspaces */
	NSEnumerator *keyEnum = [_workspaceHotKeyDict keyEnumerator];
	CGWorkspace *ws;
	while(ws = [keyEnum nextObject])
	{
		if(![_workspaceArray containsObject:ws])
		{
			[_workspaceHotKeyDict removeObjectForKey:ws];
		}
	}
}

- (void) pagerResized
{
	if((_rows == 0) || (_columns == 0))
		return;
	
	if(_statusPagerItem)
	{
		[(DMPager*)[_statusPagerItem view] makeIdealSizeForHeight: 22];
	}
	
	if(_pagerWindow && _pagerView)
	{
		/* This is a bit of a hack to make the pager window
		* track the pager size. */
		NSSize pagerSize = [[_pagerWindow contentView] frame].size;
		
		pagerSize.height = [_pagerView idealHeightForWidth:pagerSize.width];
		[_pagerWindow setContentSize:pagerSize];
		[_pagerWindow setContentAspectRatio:pagerSize];
	}
	
	[self updateWorkspaces:nil];
	[self updateCurrentWorkspace:nil];
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

@implementation CGWorkspace (DMAppControllerAdditions)

- (NSDictionary*) associatedInfo
{
	return [[DMAppController defaultController] associatedInfoForWorkspace:self];
}

- (void) setAssociatedInfo: (NSDictionary*) aInfo
{
	[self willChangeValueForKey:@"name"];
	[self willChangeValueForKey:@"associatedInfo"];
	[[DMAppController defaultController] setAssociatedInfo:aInfo forWorkspace:self];
	[self didChangeValueForKey:@"name"];
	[self didChangeValueForKey:@"associatedInfo"];
}

- (NSString*) name
{
	return [[self associatedInfo] objectForKey:@"name"];
}

- (void) setName: (NSString*) name
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary: [self associatedInfo]];
	[dict setObject: name forKey: @"name"];
	[self setAssociatedInfo: dict];
}

- (DMHotKey*) hotKey
{
	return [[DMAppController defaultController] hotKeyForWorkspace: self];
}

- (IBAction) selectWithAppController: (id) sender
{
	[[DMAppController defaultController] switchToWorkspace:self];
}

@end

@implementation CGWindow (DMAppControllerAdditions)

- (NSString*) userDefaultsKey
{
	return [NSString stringWithFormat:@"Window:%x:%x", [[self windowTitle] hash], [[self ownerName] hash]];
}

@end
