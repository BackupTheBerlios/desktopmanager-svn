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

@class CGWorkspace;
@class CGWindow;
@class DMPager;
@class DMPreferencesController;
@class CGWorkspace;
@class DMHotKey;

#import "CoreGraphics/CGWorkspace.h"
#import "CoreGraphics/CGWindow.h"

/* Notification sent when information associated with a particular
 * workspace changes. */
extern NSString *DMAssociatedInformationChangedNotification;

extern NSString *DMWorkspaceWithChangedInformationKey;

/* CGWorkspace additions */
@interface CGWorkspace (DMAppControllerAdditions)

- (NSDictionary*) associatedInfo;
- (void) setAssociatedInfo: (NSDictionary*) aInfo;
- (NSString*) name;
- (void) setName: (NSString*) name;
- (DMHotKey*) hotKey;

@end

@interface CGWindow (DMAppControllerAdditions)

- (NSString*) userDefaultsKey;

@end

@interface DMApplication : NSApplication {
}
@end

@interface DMAppController : NSObject {
	IBOutlet NSPanel *_pagerWindow;
	IBOutlet NSPanel *_windowInspector;
	IBOutlet NSView *_windowInspectorShrinkView;
	IBOutlet DMPager* _pagerView;
	IBOutlet NSMenu *_statusMenu;
	IBOutlet DMPreferencesController *_prefsController;
	
	NSMutableDictionary *_workspaceHotKeyDict;
	
	/* See comment in DMAppController for data model */
	NSMutableArray *_workspaceArray;
	int _rows, _columns;
	NSTimer *_currentWorkspaceRefreshTimer;
	NSTimer *_workspaceRefreshTimer;
	
	NSMutableArray *_hotKeys;
	
	NSStatusItem *_statusMenuItem;
	NSStatusItem *_statusPagerItem;
	
	BOOL _displaysWindowInfoAdvanced;
	
	CGWindow *_foregroundWin;
}

+ (DMAppController*) defaultController;

- (IBAction) showPreferences: (id) sender;
- (IBAction) showDesktopPager: (id) sender;
- (IBAction) showStatusPager: (id) sender;
- (IBAction) switchToWorkspace: (CGWorkspace*) ws;
- (IBAction) showWindowInspector: (id) sender;

- (IBAction) switchWorkspaceLeft: (id) sender;
- (IBAction) switchWorkspaceRight: (id) sender;
- (IBAction) switchWorkspaceDown: (id) sender;
- (IBAction) switchWorkspaceUp: (id) sender;

- (IBAction) switchToNextWorkspace: (id) sender;
- (IBAction) switchToPreviousWorkspace: (id) sender;

- (BOOL) showsWindowInspectorAdvanced;
- (void) setShowsWindowInspectorAdvanced: (BOOL) showIt;

@end

@interface DMAppController (DataModel)

- (CGWorkspace*) workspaceAtRow: (int) row column: (int) column;
- (CGWorkspace*) currentWorkspace;

- (CGWindow*) foregroundWindow;

- (NSArray*) workspaces;
- (NSArray*) associatedInfoForAllWorkspaces;

- (NSDictionary*) associatedInfoForWorkspace: (CGWorkspace*) ws;
- (void) setAssociatedInfo: (NSDictionary*) info forWorkspace: (CGWorkspace*) ws;
- (DMHotKey*) hotKeyForWorkspace: (CGWorkspace*) ws;

- (BOOL) getCurrentWorkspaceRow: (int*) row column: (int*) column;
- (BOOL) getWorkspace: (CGWorkspace*) ws row: (int*) row column: (int*) column;

- (int) rows;
- (void) setRows: (int) rows;

- (int) columns;
- (void) setColumns: (int) columns;

@end

@interface DMAppController (HotKeys)

- (NSArray*) hotKeys;
- (void) insertObject:(id)hotKey inHotKeysAtIndex:(unsigned int)index;
- (void) removeObjectFromHotKeysAtIndex:(unsigned int)index;
- (void) replaceObjectInHotKeysAtIndex:(unsigned int)index withObject: (id) hotKey;

@end