/* WorkspaceKit - A Framework for handling virtual desktops
 *
 * Copyright (C) 2003, 2004 Richard J Wareham <richwareham@users.sourceforge.net>
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

/* Version of the extender protocol we're using, any backwards
compatibility breakages should incrememnt major version,
new features should increment minor. Bug-fixes increment
revision number */
#define DOCK_EXTENSION_VERSION ((1 << 16) | (1 << 8) | (0))
							   /* major,    minor,     revision */

/* Contains enums for the WindowController events */

enum {
    kWindowControllerClass = 'wbgr' // WindowBuggerer ... the original name :)
};

enum {
	kWindowControllerPing		= 'ping',
	kWindowControllerHideWindow		= 'hidw',
	kWindowControllerShowWindow		= 'show',
    kWindowControllerFadeWindow 	= 'fdwn',
    kWindowControllerUnFadeWindow 	= 'ufdw',
    kWindowControllerMoveWindow		= 'mvwn',
    kWindowControllerOrderOutWindow		= 'odot',
    kWindowControllerOrderAboveWindow   = 'odab',
	kWindowControllerMakeSticky			= 'mksk',
	kWindowControllerMakeUnSticky		= 'mkus',
	kWindowControllerGetTags		= 'gttg',
	kWindowControllerGetEventMask		= 'gtmk',
	kWindowControllerSetEventMask		= 'stmk',
	kWindowControllerMoveToWorkspace	= 'mvwk',
	kWindowControllerArrange		= 'arng',
	kWindowControllerRestore		= 'rstr',
	kWindowControllerCreateAnimation		= 'cran',
	kWindowControllerFreeAnimation		= 'fran',
	kWindowControllerRunAnimation		= 'rnan',
};