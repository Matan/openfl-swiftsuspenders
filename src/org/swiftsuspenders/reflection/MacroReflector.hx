package org.swiftsuspenders.reflection;

import haxe.rtti.Meta;
import org.swiftsuspenders.typedescriptions.PostConstructInjectionPoint;
import org.swiftsuspenders.typedescriptions.PropertyInjectionPoint;
import org.swiftsuspenders.typedescriptions.ConstructorInjectionPoint;
import org.swiftsuspenders.typedescriptions.NoParamsConstructorInjectionPoint;
import org.swiftsuspenders.typedescriptions.TypeDescription;
import org.swiftsuspenders.utils.CallProxy;

/**
* @author Matan Uberstein
*
* This Reflector is the love child of minject's "injector" logic and org.swiftsuspenders.reflection.DescribeTypeRTTIReflector.
*
* STILL WORK IN PROGRESS
**/
class MacroReflector implements Reflector
{
	public function new()
	{
	}

	public function getClass(value : Dynamic) : Class<Dynamic>
	{
		/*
		 There are several types for which the 'constructor' property doesn't work:
		 - instances of Proxy, Xml and XMLList throw exceptions when trying to access 'constructor'
		 - instances of Vector, always returns Array<Dynamic> as their constructor except numeric vectors
		 - for numeric vectors 'value is Array<Dynamic>' wont work, but 'value.constructor' will return correct result
		 - Int and UInt return Float as their constructor
		 For these, we have to fall back to more verbose ways of getting the constructor.
		 */
		if(Std.is(value, Xml))
		{
			return Xml;
		}
		else if(Std.is(value, Array))
		{
			return Array;
		}

		return Type.getClass(value);
	}

	public function getFQCN(value : Dynamic, replaceColons : Bool = false) : String
	{
		var fqcn : String;
		if(Std.is(value, String))
		{
			fqcn = value;
			// Add colons if missing and desired.
			if(!replaceColons && fqcn.indexOf('::') == -1)
			{
				var lastDotIndex : Int = fqcn.lastIndexOf('.');
				if(lastDotIndex == -1)
				{
					return fqcn;
				}
				return fqcn.substring(0, lastDotIndex) + '::' +
				       fqcn.substring(lastDotIndex + 1);
			}
		}
		else
			fqcn = CallProxy.replaceClassName(value);

		if(replaceColons == true)
			return fqcn.split('::').join('.');

		return fqcn;
	}

	/**
	* Method Credits: 2012-2014 Massive Interactive
	* package minject.Reflector;
	* - classExtendsOrImplements
	**/

	public function typeImplements(type : Class<Dynamic>, superType : Class<Dynamic>) : Bool
	{
		var actualClass : Class<Dynamic> = null;

		if(Std.is(type, Class))
		{
			actualClass = cast(type, Class<Dynamic>);
		}
		else if(Std.is(type, String))
		{
			try
			{
				actualClass = Type.resolveClass(cast(type, String));
			}
			catch(e : Dynamic)
			{
				throw "The class name " + type + " is not valid because of " + e + "\n" + e.getStackTrace();
			}
		}

		if(actualClass == null)
		{
			throw "The parameter classOrClassName must be a Class or fully qualified class name.";
		}

		var classInstance = Type.createEmptyInstance(actualClass);
		return Std.is(classInstance, superType);
	}

	public function describeInjections(classType : Class<Dynamic>) : TypeDescription
	{
		var typeMeta = Meta.getType(classType);

		var description : TypeDescription = new TypeDescription(false);
		var fieldsMeta = getFields(classType);
		var fields : Array<String> = Reflect.fields(fieldsMeta);

		// When there is no info, simply pass 'no params constructor'
		if(fields.length == 0)
			description.ctor = new NoParamsConstructorInjectionPoint();

		else
		{
			//trace(typeMeta);
			//trace(fieldsMeta);

			var postConstructors : Array<Dynamic> = [];

			// Check if the class has constructor injections, if not, put no params point.
			if(fields.indexOf("_") == -1)
				description.ctor = new NoParamsConstructorInjectionPoint();

			for(field in fields)
			{
				var fieldMeta : Dynamic = Reflect.field(fieldsMeta, field);

				var inject = Reflect.hasField(fieldMeta, "inject");
				var post = Reflect.hasField(fieldMeta, "post");
				var type = Reflect.field(fieldMeta, "type");
				var args = Reflect.field(fieldMeta, "args");

				if(field == "_") // constructor
				{
					addCtorInjectionPoint(description, fieldMeta);
				}
				else if(Reflect.hasField(fieldMeta, "args")) // method
				{
					if(inject) // method injection
					{
						/*var point = new MethodInjectionPoint(field, fieldMeta.args);
						injectionPoints.push(point);*/
					}
					else if(post) // post construction
					{
						postConstructors.push({description:description, field:field, fieldMeta:fieldMeta});
						//addPostConstructMethodPoints(description, field, fieldMeta);
					}
				}
				else if(type != null) // property
				{
					addFieldInjectionPoints(description, field, fieldMeta);
				}
			}

			var iL : Int = postConstructors.length;
			for(i in 0...iL)
			{
				var item : Dynamic = postConstructors[i];
				addPostConstructMethodPoints(item.description, item.field, item.fieldMeta);
			}
		}

		return description;
	}

	/**
	*  Collects constructor injections data.
	*
	*  NOTE: Named injections not supported yet. Information is available via the 'args' array.
	*  NOTE: Optionals are still acting weird. Best not to use it for now.
	**/

	private function addCtorInjectionPoint(description : TypeDescription, meta : Dynamic) : Void
	{
		if(meta.args.length == 0)
		{
			description.ctor = new NoParamsConstructorInjectionPoint();
			return;
		}

		// trace(meta.args);

		// CHECK add injectParameters
		var injectParameters : Map<String, Dynamic> = null;
		var parameters : Dynamic = formatParameters(meta.args);

		description.ctor = new ConstructorInjectionPoint(parameters.types, parameters.required, injectParameters);
	}

	/**
	* Collects Field injection points.
	*
	* NOTE: Named injections not supported yet.
	**/

	private function addFieldInjectionPoints(description : TypeDescription, propertyName : String, meta : Dynamic) : Void
	{
		var name = meta.inject == null ? null : meta.inject[0];
		var type : String = meta.type[0] + "|";

		// CHECK add injectParameters
		var injectParameters : Map<String, Dynamic> = null;
		var point : PropertyInjectionPoint = new PropertyInjectionPoint(type, propertyName, false, injectParameters);

		description.addInjectionPoint(point);
	}

	/**
	* Collects PostConstruction injection points.
	*
	* NOTE: Ordering doesn't seem to work.
	**/

	private function addPostConstructMethodPoints(description : TypeDescription, methodName : String, meta : Dynamic) : Void
	{
		var parameters : Dynamic = formatParameters(meta.args);
		var order = meta.post == null ? 0 : meta.post[0];

		var point : PostConstructInjectionPoint = new PostConstructInjectionPoint(methodName, parameters.types, parameters.required, order);

		description.addInjectionPoint(point);
	}

	private function isInterface(type : Class<Dynamic>) : Bool
	{
		// Hack to check if class is an interface by looking at its class name and seeing if it Starts with a (IU)ppercase
		var classPath = CallProxy.replaceClassName(type);
		var split = classPath.split(".");
		var className : String = split[split.length - 1];

		if(className.length <= 1)
			return false;

		var r = ~/(I)([A-Z])/;
		var f2 = className.substr(0, 2);
		if(r.match(f2))
			return true;

		return false;
	}

	private function getFields(type : Class<Dynamic>) : Dynamic
	{
		var meta = {};
		while(type != null)
		{
			var typeMeta = haxe.rtti.Meta.getFields(type);
			for(field in Reflect.fields(typeMeta))
				Reflect.setField(meta, field, Reflect.field(typeMeta, field));
			type = Type.getSuperClass(type);
		}
		return meta;
	}

	/**
	* Service method to help transform the args array into Swiftsuspenders v2 format.
	**/

	private function formatParameters(args : Array<Dynamic>) : Dynamic
	{
		var types : Array<String> = [];
		var required : UInt = 0;

		if(args != null)
		{
			var iL : Int = args.length;
			for(i in 0...iL)
			{
				var arg : Dynamic = args[i];

				types.push(arg.type + "|");

				if(!arg.opt)
					required++;
			}
		}

		return {types : types, required : required};
	}
}
