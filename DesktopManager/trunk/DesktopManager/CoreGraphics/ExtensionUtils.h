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

#include <Carbon/Carbon.h>

/* Utility functions for using the dock extender */

void makeEvent(int event, AppleEvent *theEvent);
int getIntParam(const AppleEvent *theEvent, int keyword);
void addIntParm(int parm, int keyword, AppleEvent *theEvent);
void addDataParm(void *data, int length, int keyword, AppleEvent *theEvent);
void addFloatParm(float parm, int keyword, AppleEvent *theEvent);

/* Sending the event will implicityl dispose of it too */
void sendEvent(AppleEvent *theEvent);
void sendEventAsync(AppleEvent *theEvent);
int sendEventWithIntReply(AppleEvent *theEvent);