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

#include "ExtensionUtils.h"
#include "WindowControllerEvents.h"
#import <Cocoa/Cocoa.h>

/**** UTILITY FUNCTIONS ****/

void makeEvent(int event, AppleEvent *theEvent) {
    int sig = 'dock';
    OSErr err;
    AEAddressDesc targetDesc;
    
    err = AECreateDesc(
					   typeApplSignature,
					   &sig, sizeof(int),
					   &targetDesc
					   );
    if(err) { NSLog(@"Error creating descriptor: %i\n", err); }
    
    err = AECreateAppleEvent(
							 kWindowControllerClass, event,
							 &targetDesc,
							 kAutoGenerateReturnID, kAnyTransactionID,
							 theEvent
							 );
    if(err) { NSLog(@"Error creating event: %i\n", err); }
    
    AEDisposeDesc(&targetDesc);
}

int getIntParam(const AppleEvent *theEvent, int keyword) {
    int value = 0;
    OSErr err;
	
    // Get Parameter
    err = AEGetParamPtr(
						theEvent, keyword,
						typeSInt32, NULL, &value, sizeof(int),
						NULL
						);
    if(err) { NSLog(@"Error getting parameter: %i\n", err); }
    
    return value;
}

void addIntParm(int parm, int keyword, AppleEvent *theEvent) {
    OSErr err = AEPutParamPtr(
							  theEvent, keyword,
							  typeSInt32, &parm, sizeof(parm)
							  );
    if(err) { NSLog(@"Error setting parameter: %i\n", err); }
}

void addDataParm(void *data, int length, int keyword, AppleEvent *theEvent) {
    OSErr err = AEPutParamPtr(
							  theEvent, keyword,
							  typeData, data, length
							  );
    if(err) { NSLog(@"Error setting parameter: %i\n", err); }
}

void addFloatParm(float parm, int keyword, AppleEvent *theEvent) {
    OSErr err = AEPutParamPtr(
							  theEvent, keyword,
							  typeFloat, &parm, sizeof(parm)
							  );
    if(err) { NSLog(@"Error setting parameter: %i\n", err); }
}

/* We await reply here since we wan't method calls using this
* to appear like normal calls, i.e. once the method returns, the
* action has been completed. */
void sendEvent(AppleEvent *theEvent) {
    OSErr err = AESend(
					   theEvent, NULL, kAEWaitReply,
					   kAENormalPriority, kNoTimeOut,
					   NULL, NULL
					   );
    if(err) { NSLog(@"Error sending: %i\n", err); }
	AEDisposeDesc(theEvent);
}

void sendEventAsync(AppleEvent *theEvent) {
    OSErr err = AESend(
					   theEvent, NULL, kAENoReply,
					   kAENormalPriority, kNoTimeOut,
					   NULL, NULL
					   );
    if(err) { NSLog(@"Error sending: %i\n", err); }
	AEDisposeDesc(theEvent);
}

int sendEventWithIntReply(AppleEvent *theEvent) {
	AppleEvent theReply;
	int retVal = -100;
    OSErr err = AESend(
					   theEvent, &theReply, kAEWaitReply,
					   kAENormalPriority, kNoTimeOut,
					   NULL, NULL
					   );
    if(err) { NSLog(@"Error sending: %i\n", err); }
	
	retVal = getIntParam(&theReply, 'retv');
	
	AEDisposeDesc(&theReply);
	AEDisposeDesc(theEvent);
	
	return retVal;
}

