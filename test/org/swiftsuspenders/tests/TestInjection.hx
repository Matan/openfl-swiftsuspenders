package org.swiftsuspenders.tests;

class TestInjection
{
	private var _me : String;

	@inject
	public var fieldValue1 : InjClass1;

	@inject
	public var fieldValue2 : IInjClass;

	@inject
	public var fieldValue3 : InjClass3;

	@inject
	public function new(ctorValue1 : InjClass1, ctorValue2 : InjClass2, ctorValue3 : InjClass3)
	{
		_me = Type.getClassName(Type.getClass(this));

		trace('$_me -- Constructed');

		ctorValue1.hello();
		ctorValue2.hello();
		ctorValue3.hello();
	}

	@post
	public function postConstructorMethod_default() : Void
	{
		trace('$_me -- postConstructorMethod_default');

		fieldValue1.hello();
		fieldValue2.hello();
		fieldValue3.hello();
	}

	@post(2)
	public function postConstructorMethod_second() : Void
	{
		trace('$_me -- postConstructorMethod_second');

		fieldValue1.hello();
		fieldValue2.hello();
		fieldValue3.hello();
	}

	public function hello() : Void
	{
		trace('$_me -- hello!');
	}
}
