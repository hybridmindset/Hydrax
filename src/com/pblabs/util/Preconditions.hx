/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.util; 

/*
* Based on Preconditions from Google Collections
*/
class Preconditions
 {
    /**
     * Checks that the argument is not null, and returns the validated argument.
     * @return the validated reference.
     */
    public static function checkNotNull <T> (ref :T, ?message :String = null) :T
    {
        if (ref == null) {
            fail(if (message != null) message else "Argument is null");
        }
        return ref;
    }
    
    /**
     * Checks that an argument is true.
     */
    public static function checkArgument (expression :Bool, ?message :String = null) :Void
    {
        if (!expression) {
            fail(if (message != null) message else "Argument is false");
        }
    }

    /**
     * Check that the index is between 0 and (size - 1) inclusive.
     * @return the validated index.
     */
    public static function checkPositionIndex (index :Int, size :Int, ?message :String = null) :Int
    {
        if (index < 0 || index >= size) {
            fail("Index out of bounds " + index + ", [0, " + (size - 1) + "].");
        }
        return index;
    }
    
    inline static function fail (message :String) :Void
	{
        //Some javascript targets don't show exceptions, so at least log the error
        #if (js && debug)
        com.pblabs.engine.debug.Log.error(message);
        #end
	    throw message;
	}
}
