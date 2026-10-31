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

#ifndef IOKITD_IOPLATFORMEXPERTDEVICE_H
#define IOKITD_IOPLATFORMEXPERTDEVICE_H

#include "IOService.h"

class ServiceRegistry;

/*
 * Root platform device. Native macOS publishes IOPlatformUUID here, and XNU's
 * gethostuuid() syscall returns the same platform UUID through
 * IOBSDGetPlatformUUID(). Darling's gethostuuid() answers the host's stable
 * machine id, so this device publishes that value instead of inventing a
 * hardware identity.
 */
class IOPlatformExpertDevice : public IOService
{
public:
	IOPlatformExpertDevice();
	virtual ~IOPlatformExpertDevice();

	static void registerSelf(ServiceRegistry* targetRegistry);

	const char* className() const override { return "IOPlatformExpertDevice"; }
	NSDictionary* matchingDictionary() override;
	NSDictionary* getProperties() override;

private:
	NSDictionary* m_props;
};

#endif
