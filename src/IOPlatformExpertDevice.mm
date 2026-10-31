/*
 This file is part of Darling.

 Copyright (C) 2026 Darling contributors

 Darling is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Darling is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Darling.  If not, see <http://www.gnu.org/licenses/>.
*/

#include "IOPlatformExpertDevice.h"
#include "ServiceRegistry.h"
#include <IOKit/IOKitKeys.h>
#import <Foundation/NSString.h>
#include <os/log.h>
#include <unistd.h>
#include <uuid/uuid.h>

static NSString* copyHostUUIDString()
{
	uuid_t uuid;
	struct timespec timeout = { 0, 0 };

	if (gethostuuid(uuid, &timeout) != 0)
	{
		os_log_error(OS_LOG_DEFAULT, "IOPlatformExpertDevice: gethostuuid() failed; "
			"IOPlatformUUID will not be published");
		return nil;
	}

	uuid_string_t string;
	uuid_unparse_upper(uuid, string);
	return [[NSString alloc] initWithUTF8String: string];
}

IOPlatformExpertDevice::IOPlatformExpertDevice()
{
	NSString* uuidString = copyHostUUIDString();

	if (uuidString)
	{
		m_props = [[NSDictionary alloc] initWithObjectsAndKeys:
			uuidString, @"IOPlatformUUID", nil];
		[uuidString release];
	}
	else
	{
		m_props = [[NSDictionary alloc] init];
	}
}

IOPlatformExpertDevice::~IOPlatformExpertDevice()
{
	[m_props release];
}

NSDictionary* IOPlatformExpertDevice::matchingDictionary()
{
	return @{ @"IOProviderClass": @"IOPlatformExpertDevice" };
}

NSDictionary* IOPlatformExpertDevice::getProperties()
{
	return m_props;
}

void IOPlatformExpertDevice::registerSelf(ServiceRegistry* targetRegistry)
{
	IOPlatformExpertDevice* device = new IOPlatformExpertDevice();
	targetRegistry->registerService(device);
	device->registerInPlane(kIOServicePlane, "IOPlatformExpertDevice", IORegistryEntry::root());
}
