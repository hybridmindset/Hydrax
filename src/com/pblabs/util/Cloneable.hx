/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.util;

/**
 * Specifies that an instance can be cloned by calling <i>instance.clone()</i>.
 */
interface Cloneable<T>
{
	/** Returns a copy of the instance. */
	function clone():T;
}
