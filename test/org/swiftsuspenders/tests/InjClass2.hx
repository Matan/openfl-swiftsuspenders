package org.swiftsuspenders.tests;
class InjClass2 implements IInjClass
{
	private var _me : String;

	public function new()
	{
		_me = Type.getClassName(Type.getClass(this));

		trace('$_me -- Constructed');
	}

	public function hello() : Void
	{
		trace('$_me -- hello!');
	}
}
