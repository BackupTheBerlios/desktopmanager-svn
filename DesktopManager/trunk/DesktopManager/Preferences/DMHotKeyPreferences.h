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
#import <PreferencePanes/PreferencePanes.h>

@class DMHotKey;

@interface DMHotKeyFieldEditor : NSView {
	id _delegate;
	DMHotKey *_representedHotKey;
}

- (id) delegate;
- (void) setDelegate: (id) delegate;
- (DMHotKey*) representedHotKey;
- (void) setRepresentedHotKey: (DMHotKey*) hk;

@end

@interface DMHotKeyPreferences : NSPreferencePane {
	IBOutlet NSObjectController *_dataController;
	IBOutlet NSArrayController *_hotKeysController;
	IBOutlet NSButton *_keyCombinationButton;
}

- (IBAction) editKeyCombination: (id) sender;

@end
