/*
 This file is part of Darling.

 Copyright (C) 2020 Lubos Dolezel

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

#include "iokitd.h"
#include "ServiceRegistry.h"
#include <IOKit/IOCFUnserialize.h>
#include <CoreFoundation/CFString.h>
#include <IOKit/IOReturn.h>
#include <os/log.h>
#include <stdexcept>
#include "IOIterator.h"

extern "C" {
#include "iokitmigServer.h"
}

ServiceRegistry* ServiceRegistry::instance()
{
	static ServiceRegistry reg;
	return &reg;
}

IOIterator* ServiceRegistry::iteratorForMatchingServices(NSDictionary* criteria) const
{
	std::vector<IOObject*> matching;

	for (auto it = m_registeredServices.begin(); it != m_registeredServices.end(); it++)
	{
		if ((*it)->matches(criteria))
			matching.push_back(*it);
	}

	return new IOIterator(matching);
}

IOService* ServiceRegistry::firstMatchingService(NSDictionary* criteria) const
{
	for (auto it = m_registeredServices.begin(); it != m_registeredServices.end(); it++)
	{
		if ((*it)->matches(criteria))
			return *it;
	}

	return nullptr;
}

void ServiceRegistry::registerService(IOService* service)
{
	m_registeredServices.push_back(service);
}

/*
 * Single-service matching (IOServiceGetMatchingService). The client sends the
 * serialized matching dictionary in-band when it is smaller than
 * io_struct_inband_t; iokitmig issues io_service_get_matching_service_bin.
 * XNU's is_io_service_get_matching_service_bin is the reference for the return
 * value: kIOReturnSuccess with the first match, or kIOReturnNotFound with a
 * null service. The legacy string RPC (io_service_get_matching_service) stays
 * unsupported exactly as in XNU. The out-of-line variant is not needed for
 * this path: IOKitLib sends matching dictionaries below io_struct_inband_t
 * in-band, and it remains unsupported here.
 */
kern_return_t is_io_service_get_matching_service_bin
(
	mach_port_t master_port,
	io_struct_inband_t matching,
	mach_msg_type_number_t matchingCnt,
	mach_port_t *service
)
{
	*service = MACH_PORT_NULL;

	CFStringRef errorString = nullptr;
	CFTypeRef criteria = IOCFUnserializeBinary(matching, matchingCnt, nullptr, 0, &errorString);

	if (!criteria)
	{
		os_log_error(OS_LOG_DEFAULT, "is_io_service_get_matching_service_bin: cannot parse matching dictionary");
		if (errorString)
			CFRelease(errorString);
		return kIOReturnBadArgument;
	}

	if (CFGetTypeID(criteria) != CFDictionaryGetTypeID())
	{
		CFRelease(criteria);
		if (errorString)
			CFRelease(errorString);
		os_log_error(OS_LOG_DEFAULT, "is_io_service_get_matching_service_bin: dictionary expected");
		return kIOReturnBadArgument;
	}

	IOService* matched = ServiceRegistry::instance()->firstMatchingService((NSDictionary*) criteria);
	CFRelease(criteria);
	if (errorString)
		CFRelease(errorString);

	if (!matched)
		return kIOReturnNotFound;

	*service = matched->port();
	return kIOReturnSuccess;
}

kern_return_t is_io_service_get_matching_services_ool
(
	mach_port_t master_port,
	io_buf_ptr_t matching,
	mach_msg_type_number_t matchingCnt,
	kern_return_t *result,
	mach_port_t *existing
)
{
	// TODO
    return kIOReturnUnsupported;
}

kern_return_t is_io_service_get_matching_services_bin
(
	mach_port_t master_port,
	io_struct_inband_t matching,
	mach_msg_type_number_t matchingCnt,
	mach_port_t *existing
)
{
	CFStringRef errorString = nullptr;
	try
	{
		CFTypeRef criteria = IOCFUnserializeBinary(matching, matchingCnt, nullptr, 0, &errorString);

		if (!criteria)
			throwCFStringException(CFSTR("io_service_get_matching_services_bin(): cannot parse 'matching': %@"), errorString);
		
		if (CFGetTypeID(criteria) != CFDictionaryGetTypeID())
			throw std::runtime_error("io_service_get_matching_services_bin(): dictionary expected");

		// Criteria example:
		// IOProviderClass -> IODisplayConnect
		IOIterator* iterator = ServiceRegistry::instance()->iteratorForMatchingServices((NSDictionary*) criteria);
		CFShow(criteria);
		CFRelease(criteria);

		*existing = iterator->port();

		iterator->releaseLater();

		return kIOReturnSuccess;
	}
	catch (const std::exception& e)
	{
		os_log_error(OS_LOG_DEFAULT, "is_io_service_get_matching_services_bin: %s", e.what());
		if (errorString)
			CFRelease(errorString);

		return kIOReturnBadArgument;
	}
}

kern_return_t is_io_service_get_matching_services
(
	mach_port_t master_port,
	io_string_t matching,
	mach_port_t *existing
)
{
    // Old unsupported API
    return kIOReturnUnsupported;
}
