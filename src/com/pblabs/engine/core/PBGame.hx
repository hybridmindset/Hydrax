/*******************************************************************************
 * Hydrax: haXe port of the PushButton Engine
 * Copyright (C) 2010 Dion Amago
 * For more information see http://github.com/dionjwa/Hydrax
 *
 * This file was derived from the equivalent actionscript PushButton Engine 
 * source file:
 * http://code.google.com/p/pushbuttonengine/
 *
 * This file is licensed under the terms of the MIT license, which is included
 * in the License.html file at the root directory of this SDK.
 ******************************************************************************/
package com.pblabs.engine.core;

import com.pblabs.components.scene.SceneView;
import com.pblabs.engine.core.NameManager;
import com.pblabs.engine.core.PBGameBase;
import com.pblabs.engine.core.SetManager;
import com.pblabs.engine.core.SignalBondManager;
import com.pblabs.engine.debug.Log;
import com.pblabs.engine.resource.IResourceManager;
import com.pblabs.engine.resource.ResourceManager;
import com.pblabs.engine.serialization.Serializer;
import com.pblabs.engine.serialization.TemplateManager;
import com.pblabs.engine.time.IProcessManager;
import com.pblabs.engine.time.ProcessManager;

/**
  * Standard game.  Starts up the most commonly used
  * managers that provide functionality that most games requre.
  */
class PBGame extends PBGameBase 
{
    public function new() 
    {
        //Set the com.pblabs.engine.debug.Log methods
        //to be from the Log implementation @ com.pblabs.util
        com.pblabs.util.Log.setupPBGameLog();
        com.pblabs.util.Log.setLevel("", com.pblabs.util.Log.WARNING);
        super();
        startup();
    }
    
    override function initializeManagers():Void
    {
        super.initializeManagers();

        // Register ourselves.
        registerManager(PBGameBase, this);
        
        // Bring in the standard managers.
        registerManager(NameManager, new NameManager());
        registerManager(IProcessManager, new ProcessManager());
        registerManager(SetManager, new SetManager());
        registerManager(SignalBondManager, new SignalBondManager());
        // var view = new SceneView();
        // #if flash
        // displayContainer.addChild(view.layer);
        // #end
        registerManager(SceneView, new SceneView());
        
        //Not yet converted to haXe
        // registerManager(InputManager, new InputManager());
        registerManager(IResourceManager, new ResourceManager());
        registerManager(Serializer, new Serializer());
        registerManager(TemplateManager, new TemplateManager());
    }
    
    #if flash
    public function registerType(clazz:Class<Dynamic>):Void
    {
        // NOP - passing it is enough for it to be linked into the SWF.
    }
    #end
}


