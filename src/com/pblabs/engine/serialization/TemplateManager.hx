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

package com.pblabs.engine.serialization;

import com.pblabs.engine.core.IEntity;
import com.pblabs.engine.core.IEntityComponent;
import com.pblabs.engine.core.IPBContext;
import com.pblabs.engine.core.IPBGroup;
import com.pblabs.engine.core.PBGroup;
import com.pblabs.engine.core.PropertyReference;
import com.pblabs.engine.debug.Log;
import com.pblabs.engine.debug.Profiler;
import com.pblabs.engine.resource.IResource;
import com.pblabs.engine.resource.IResourceManager;
import com.pblabs.engine.resource.XMLResource;
import com.pblabs.engine.serialization.ISerializable;
import com.pblabs.engine.serialization.Serializer;
import com.pblabs.util.Preconditions;
import com.pblabs.util.ds.Map;
import com.pblabs.util.ds.Maps;
import com.pblabs.util.ds.maps.DynamicMap;

import hsl.haxe.DirectSignaler;
import hsl.haxe.Signaler;

/**
 * @eventType com.pblabs.engine.core.TemplateEvent.GROUP_LOADED
 */
/*[Event(name="GROUP_LOADED", type="com.pblabs.engine.serialization.TemplateEvent")]*/

/**
 * The template manager loads and unloads level files and stores information
 * about their contents. The Serializer is used to deserialize object
 * descriptions.
 *
 * <p>A level file can contain templates, entities, and groups. A template
 * describes an entity that will be instantiated several times, like a
 * bullet. Templates are left unnamed when they are instantiated.</p>
 *
 * <p>An entity describes a complete entity that is only instantiated once, like
 * a background tilemap. Entities are named based on the name of the xml data
 * that describes it.</p>
 *
 * <p>A group contains references to templates, entities, and other groups that
 * should be instantiated when the group is instantiated.</p>
 *
 * @see com.pblabs.engine.serialization.Serializer.
 */
class TemplateManager 
    // implements haxe.rtti.Infos //For injections 
{
    public var signalLoaded :Signaler<XMLResource>;
    public var signalFailed :Signaler<XMLResource>;
    public var signalGroupLoaded :Signaler<String>;
    
    // public var entityType(null, setEntityType) :Class<Dynamic>;
    @inject("com.pblabs.engine.serialization.Serializer")
    public var serializer :Serializer;
    
    @inject("com.pblabs.engine.resource.IResourceManager")
    public var resourceManager :IResourceManager;
    
    /**
     * Defines the event to dispatch when a level file is successfully loaded.
     */
    // public static var LOADED_EVENT :String="LOADED_EVENT";
    
    /**
     * Defines the event to dispatch when a level file fails to load.
     */
    // public static var FAILED_EVENT :String="FAILED_EVENT";
    
    /**
     * Report every time we create an entity.
     */
    public static var VERBOSE_LOGGING :Bool=false;
    
    public function new() 
    {
        _inGroup = false;
        _entityType = null;
        _things = Maps.newHashMap(String);
        signalLoaded = new DirectSignaler(this);
        signalFailed = new DirectSignaler(this);
        signalGroupLoaded = new DirectSignaler(this); 
        
        signalLoaded.bind(onLoaded);
        signalFailed.bind(onFailed);
    }
    
    /**
     * Allow specifying an alternate class to use for IEntity.
     */
    public function setEntityType(value :Class<Dynamic>) :Void
    {
        _entityType=value;
    }
    
    /**
     * Loads a level file and adds its contents to the template manager. This
     * does not instantiate any of the objects in the file, it merely loads
     * them for future instantiation.
     *
     * <p>When the load completes, the LOADED_EVENT will be dispatched. If
     * the load fails, the FAILED_EVENT will be dispatched.</p>
     *
     * @param filename The file to load.
     */
    public function loadFile(filename :String, ?forceReload :Bool = false) :Void
    {
        if (!forceReload && resourceManager.isResource(filename)) {
            //Already present
            return;
        }
        
        var rsrc = new XMLResource(filename, Source.url(filename));
        // resourceManager.unload(filename);
        // resourceManager.addResource(new XMLResource(filename, Source.url(filename)));
        
        var self = this;
        var onLoaded = function () :Void {
            self.signalLoaded.dispatch(rsrc);
            // resourceManager.addResource(rsrc);
            // signalLoaded.
        }
        
        var onError = function (e :Dynamic) :Void {
            Log.error("Failed to load " + filename + ", error=" + e);
            self.signalFailed.dispatch(rsrc);
        }
        
        rsrc.load(onLoaded, onError);
        
        // resourceManager.load
        
        // resourceManager.load(filename, XMLResource, onLoaded, onFailed, forceReload);
    }
    
    /**
     * Unloads a level file and removes its contents from the template manager.
     * This does not destroy any entities that have been instantiated.
     *
     * @param filename The file to unload.
     */
    public function unloadFile(filename :String) :Void
    {
        removeXML(filename);
        resourceManager.unload(filename);
    }
    
    /**
     * Creates an instance of an object with the specified name. The name must
     * refer to a template or entity. To instantiate groups, use instantiateGroup
     * instead.
     *
     * @param name The name of the entity or template to instantiate. This
     * corresponds to the name attribute on the template or entity tag in the XML.
     *
     * @return The created entity, or null if it wasn't found.
     */
    public function instantiateEntity(name :String, context :IPBContext) :IEntity
    {
        Profiler.enter("instantiateEntity");
        var entity;
        try {
            // Check for a callback.
            if (_things.exists(name)) {
                if (_things.get(name).groupCallback != null) {
                    throw "Thing '" + name + "' is a group callback!";
                }
                
                if (_things.get(name).entityCallback != null) {
                    var instantiated = _things.get(name).entityCallback();
                    
                    if(instantiated == null) {
                        throw "entityCallback returned NULL!";
                    }
                    
                    Profiler.exit("instantiateEntity");
                    return instantiated;
                }
            }
            
            var xml = getXML(name, "template", "entity");
            if (xml == null) {
                Log.error("Unable to find a template or entity with the name " + name + ".");
                Profiler.exit("instantiateEntity");
                return null;
            }
            
            entity = instantiateEntityFromXML(xml, context);
            Profiler.exit("instantiateEntity");
        }
        catch (e :Dynamic) {
            Log.error("Failed instantiating '" + name + "' due to :" + e.toString() + "\n" + e.getStackTrace());
            entity = null;
            Profiler.exit("instantiateEntity");
        }
        
        return entity;
    }
    
    
    
    /**
     * Make a new instance of an entity, setting appropriate fields based
     * on the parameters passed.
     * 
     * @param entityName Identifier by which to look up the entity on the 
     *                                       TemplateManager.
     * @param params     Properties to assign, by key/value. Keys can be only
     *                               be Strings, however the can be PropertyReference
     *                               Strings (start with @ or #) and the key will be converted
     *                               into a PropertyReference.
     *                               Values can be any type.
     */
    public function makeEntity(context :IPBContext, entityName :String, ?params :Map<String, Dynamic>) :IEntity
    {
        // Create the entity.
        var entity = instantiateEntity(entityName, context);
        if(entity == null) {
            return null;
        }
        
        if(params == null) {
            return entity;
        }
        
        // Set all the properties.
        for(key in params.keys()) {
            if(key.charAt(0) == "@" && key.indexOf(".") == -1) {
                entity.addComponent(cast(params.get(key), IEntityComponent), key.substr(1));
            }
            else {
                entity.setProperty(new PropertyReference(key), params.get(key));
            }
        }
        
        // Finish deferring.
        if(entity.deferring) {
            entity.deferring = false;
        }
        
        // Give it to the user.
        return entity;
    }
    
    /**
     * Given an XML literal, construct a valid entity from it.
     */
    public function instantiateEntityFromXML (xml :XML, context :IPBContext) :IEntity
    {
        Preconditions.checkNotNull(xml);
        Preconditions.checkNotNull(context);
        Profiler.enter("instantiateEntityFromXML");
        
        var entity :IEntity;
        var name = null;
        try {
            // Get at the name...
            name = xml.get("name");
            if (xml.nodeName == "template") {
                name = "";
            }
            
            // Make the IEntity instance.
            entity = context.allocate(IEntity);
            trace("entity made " + entity);    
            // To aid with reference handling, initialize FIRST but defer the
            // reset...
            entity.initialize(name);
            entity.deferring = true;
            trace("initialized");
            
            if (!doInstantiateTemplate(entity, xml.get("template"), new DynamicMap<Bool>())) {
                trace("false on doInstantiateTemplate"); 
                entity.destroy();
                Profiler.exit("instantiateEntityFromXML");
                return null;
            }
            
            var serializer = context.getManager(Serializer);
            #if debug
            com.pblabs.util.Assert.isNotNull(serializer);
            #end
            
            trace("serializer=" + serializer);
            serializer.deserialize(context, entity, xml);
            // serializer.clearCurrentEntity();
            
            // // Don't forget to disable deferring.
            // entity.deferring = false;
            
            // if (!_inGroup) {
            //     serializer.reportMissingReferences();
            // }
            
            Profiler.exit("instantiateEntityFromXML");
        }
        catch (e :Dynamic) {
            Log.error("Failed instantiating '" + name + "' due to :" + e + "\n" + Log.getStackTrace());
            entity = null;
            Profiler.exit("instantiateEntityFromXML");
        }
        
        return entity;
    }
    
    /**
     * instantiates all templates or entities referenced by the specified group.
     *
     * @param name The name of the group to instantiate. This correspands to the
     * name attribute on the group tag in the XML.
     *
     * @return An array containing all the instantiated objects. If the group
     * wasn't found, the array will be empty.
     */
    public function instantiateGroup(context :IPBContext, name :String) :IPBGroup
    {
        // Check for a callback.
        if (_things.exists(name)) {
            Preconditions.checkArgument(_things.get(name).entityCallback == null, "Thing '" + name + "' is an entity callback!"); 
            // We won't dispatch the GROUP_LOADED event here as it's the callback
            // author's responsibility.
            if (null != _things.get(name).groupCallback)
                return _things.get(name).groupCallback();
        }
        
        try {
            // Create the group.
            var group = doInstantiateGroup(name, new DynamicMap<Bool>(), context); 
            if (null == group) {
                return null;
            }
            
            if (signalGroupLoaded.isListenedTo) {
                signalGroupLoaded.dispatch(name);
            }
            
            return group;
        }
        catch (e :Dynamic) {
            Log.error("Failed to instantiate group '" + name + "' due to :" + e.toString());
            return null;
        }
        
        // Should never get here, one branch or the other of the try will take it.
        throw "Somehow skipped both branches of group instantiation try/catch block!";
        return null;
    }
    
    /**
     * Adds an XML description of a template, entity, or group to the template manager so
     * it can be instantiated in the future.
     *
     * @param xml The xml to add.
     * @param identifier A string by which this xml can be referenced. This is NOT the
     * name of the object. It is used so the xml can be removed by a call to RemoveXML.
     * @param version The version of the format of the added xml.
     */
    public function addXML(xml :XML, identifier :String, version :Int) :Void
    {
        // var name :String=xml.get("name");
        var name = xml.get("name");
        
        if (name.length == 0) {
            Log.warn("XML object description added without a 'name' attribute.");
            return;
        }
        
        if (_things.exists(name)) {
            Log.warn("An XML object description with name " + name + " has already been added.");
            return;
        }
        
        var thing = new ThingReference();
        thing.xmlData = xml;
        thing.identifier = identifier;
        thing.version = version;
        
        _things.set(name, thing);
    }
    
    /**
     * Removes the specified object from the template manager.
     *
     * @param identifier This is NOT the name of the xml object. It is the value
     * passed as the identifier in AddXML.
     */
    public function removeXML (identifier :String) :Void
    {
        _things.remove(identifier);
    }
    
    /**
     * Gets a previously added xml description that has the specified name.
     *
     * @param name The name of the xml to retrieve.
     * @param xmlType1 The type (template, entity, or group) the xml must be.
     * If this is null, it can be anything.
     * @param xmlType2 Another type (template, entity, or group) the xml can
     * be.
     *
     * @return The xml description with the specified name, or null if it wasn't
     * found.
     */
    public function getXML(name :String, ?xmlType1 :String, ?xmlType2 :String) :XML
    {
        var thing = doGetXML(name, xmlType1, xmlType2);
        return thing != null ? thing.xmlData :null;
    }
    
    /**
     * Check if a template method by the provided name has been registered.
     * @param name Name of the template registered with the TemplateManager
     * @return true if the template exists, false if it does not.
     */        
    public function hasEntityCallback(name :String) :Bool
    {
        return _things.exists(name);
    }
    
    /**
     * Register a callback-powered entity with the TemplateManager. Instead of
     * parsing and returning an entity based on XML, this lets you directly
     * create the entity from a function you specify.
     *
     * Generally, we recommend using XML for entity definitions, but this can
     * be useful for reducing external dependencies, or providing special
     * functionality (for instance, a single name that returns several
     * possible entities based on chance).
     *
     * @param name Name of the entity.
     * @param callback A function which takes no arguments and returns an IEntity.
     * @see UnregisterEntityCallback, RegisterGroupCallback, hasEntityCallback
     */
    public function registerEntityCallback(name :String, callBack :Void->IEntity) :Void
    {
        Preconditions.checkNotNull(callBack, "Must pass a callback function!");
        Preconditions.checkArgument(!_things.exists(name), "Already have a thing registered under '" + name + "'!");
        
        var newThing = new ThingReference();
        newThing.entityCallback = callBack;
        _things.set(name, newThing);
    }
    
    /**
     * Unregister a callback-powered entity registered with RegisterEntityCallback.
     * @see RegisterEntityCallback
     */
    public function unregisterEntityCallback(name :String) :Void
    {
        if (!_things.exists(name)) {
            Log.warn("No such template '" + name + "'!");
            return;
        }
        Preconditions.checkNotNull(_things.get(name).entityCallback, "Thing '" + name + "' is not an entity callback!"); 
        _things.remove(name);
    }
    
    /**
     * Register a function as a group. When the group is requested via instantiateGroup,
     * the function is called, and the Array it returns is given to the user.
     *
     * @param name NAme of the group.
     * @param callback A function which takes no arguments and returns an array of IEntity instances.
     * @see UnregisterGroupCallback, RegisterEntityCallback
     */
    public function registerGroupCallback(name :String, callBack :Void->IPBGroup) :Void
    {
        Preconditions.checkNotNull(callBack, "Must pass a callback function!");
        Preconditions.checkArgument(!_things.exists(name), "Already have a thing registered under '" + name + "'!");
        
        var newThing = new ThingReference();
        newThing.groupCallback = callBack;
        _things.set(name, newThing);
    }
    
    /**
     * Unregister a function-based group registered with RegisterGroupCallback.
     * @param name Name passed to RegisterGroupCallback.
     * @see RegisterGroupCallback
     */
    public function unregisterGroupCallback(name :String) :Void
    {
        Preconditions.checkArgument(_things.exists(name), "No such thing '" + name + "'!");
        Preconditions.checkArgument(_things.get(name).groupCallback != null, "Thing '" + name + "' is not a group callback!");
        _things.remove(name);
    }
    
    function doGetXML(name :String, xmlType1 :String, xmlType2 :String) :ThingReference
    {
        var thing = _things.get(name);
        if (null == thing) {
            return null;
        }
        
        // No XML on callbacks.
        if (thing.entityCallback != null || thing.groupCallback != null) {
            return null;
        }
        
        if (xmlType1 != null) {
            var type = thing.xmlData.nodeName;
            if (type != xmlType1 && type != xmlType2) {
                return null;
            }
        }
        
        return thing;
    }
    
    function doInstantiateTemplate (object :IEntity, templateName :String, tree :Map<String, Bool>) :Bool
    {
        if (templateName == null || templateName.length == 0) {
            return true;
        }
        
        if (tree.exists(templateName)) {
            Log.warn("Cyclical template detected. " + templateName + " has already been instantiated.");
            return false;
        }
        
        var templateXML = getXML(templateName, "template");
        if (null == templateXML) {
            Log.warn("Unable to find the template " + templateName + ".");
            return false;
        }
        
        tree.set(templateName, true);
        if (!doInstantiateTemplate(object, templateXML.get("template"), tree)) {
            return false;
        }
        
        object.deserialize(templateXML, false);
        
        return true;
    }
    
    function doInstantiateGroup(name :String, tree :Map<String, Bool>, context :IPBContext) :IPBGroup
    {
        var xml = getXML(name, "group");
        Preconditions.checkNotNull(xml, "Could not find group '" + name + "'"); 
        
        //Create the group :
        var actualGroup :IPBGroup = context.allocate(IPBGroup);
        if(name != context.rootGroup.name) {
            actualGroup.initialize(name);
            actualGroup.owningGroup = context.currentGroup;
        } else {
            actualGroup = context.rootGroup;
        }
        
        var oldGroup = context.currentGroup;
        context.currentGroup = actualGroup;
        
        for (objectXML in xml.elements()) {
            var childName = objectXML.get("name");
            if (objectXML.nodeName == "groupReference") {
                Preconditions.checkArgument(!tree.exists(childName), "Cyclical group detected. " + childName + " has already been instantiated."); 
                
                tree.set(childName, true);
                
                // Don't need to check for return value, as it will throw an error 
                // if something bad happens.
                try {
                    if (doInstantiateGroup(childName, tree, context) == null) {
                        return null;
                    }
                } catch (err :Dynamic) {
                    Log.warn("Failed to instantiate group '" + childName + "' from groupReference in '" + name + "' due to :" + err);
                    return null;
                }
            } else if (objectXML.nodeName == "objectReference") {
                _inGroup = true;
                instantiateEntity(childName, context);
                _inGroup=false;
            } else {
                Log.warn("Encountered unknown tag " + objectXML.nodeName + " in group.");
            }
        }
        
        context.currentGroup = oldGroup;
        
        serializer.reportMissingReferences();
        
        return actualGroup;
    }
    
    public function loadInMemoryFile(data :XML, sourceName :String) :Void
    {
        var version = Std.parseInt(data.get("version"));
        var thingCount :Int = 0;
        for (xml in data.elements()) {
            thingCount++;
            addXML(xml, sourceName, version);
        }
        
        Log.info("Loaded " + thingCount + " from " + sourceName);            
    }
    
    function onLoaded(resource :XMLResource) :Void
    {
        var xml = resource.create();
        var version = Std.parseInt(xml.get("version"));
        var thingCount :Int=0;
        for (childxml in xml.elements()) {
            thingCount++;
            addXML(childxml, resource.name, version);
        }
        
        Log.info("Loaded " + thingCount + " from " + resource.name);
        
        // signalLoaded.dispatch(resource);
    }
    
    function onFailed(resource :XMLResource) :Void
    {
        signalFailed.dispatch(resource);
    }
    
    var _inGroup :Bool;
    var _entityType :Class<Dynamic>;
    var _things :Map<String, ThingReference>;
}

/**
 * Helper class to store information about each thing.
 */
class ThingReference
{
    public var version :Int;
    public var xmlData :XML;
    public var entityCallback :Void->IEntity;
    public var groupCallback :Void->IPBGroup;
    public var identifier :String;
    
    public function new () 
    {
        version = 0;
        xmlData = null;
        entityCallback = null;
        groupCallback = null;
        identifier = "";
    }
}


