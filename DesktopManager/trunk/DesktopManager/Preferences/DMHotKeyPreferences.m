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

#import "DMHotKeyPreferences.h"
#import "DesktopManager/DMAppController.h"
#import "DesktopManager/HotKeys/DMHotKey.h"

@interface DMLocaliseHotKeyDescription: NSValueTransformer {}
@end
@implementation DMLocaliseHotKeyDescription
+ (Class)transformedValueClass { return [NSString class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value {
	return (value == nil) ? nil : [[NSBundle mainBundle] localizedStringForKey:value value:value table:@"HotKeyDescriptions"];
}
@end

@implementation DMHotKeyPreferences

- (NSString*) mainNibName
{
	return @"HotKeyPrefs";
}

- (void) mainViewDidLoad
{
	if(![NSValueTransformer valueTransformerForName:@"DMHotKeyTransformer"])
	{
		[NSValueTransformer setValueTransformer:[[[DMHotKeyTransformer alloc] init] autorelease] forName:@"DMHotKeyTransformer"];
	}
	if(![NSValueTransformer valueTransformerForName:@"DMLocaliseHotKeyDescription"])
	{
		[NSValueTransformer setValueTransformer:[[[DMLocaliseHotKeyDescription alloc] init] autorelease] forName:@"DMLocaliseHotKeyDescription"];
	}
	[_appControllerController setContent: [DMAppController defaultController]];
}

@end

@implementation DMHotKeyTransformer 

+ (Class)transformedValueClass 
{ 
	return [NSString class];
}

+ (BOOL)allowsReverseTransformation 
{ 
	return NO; 
}

- (id)transformedValue:(id)value 
{
	if(!value || ![value isKindOfClass:[DMHotKey class]])
		return nil;
	
	DMHotKey *hk = value;
	return [hk stringValue];
}

@end
