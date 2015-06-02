package ;

import org.swiftsuspenders.tests.TestInjection;
import org.swiftsuspenders.tests.IInjClass;
import org.swiftsuspenders.tests.InjClass3;
import org.swiftsuspenders.tests.InjClass2;
import org.swiftsuspenders.tests.InjClass1;
import org.swiftsuspenders.Injector;

/**
* Lamest inline tests ever written in history! Just temp, don't go hatin'!
*/
class Test
{
	public static function main()
	{
		var injector = new Injector();

		injector.map(InjClass1).asSingleton();
		injector.map(InjClass2).asSingleton();
		injector.map(InjClass3).asSingleton();

		injector.map(IInjClass).toValue(injector.getInstance(InjClass2));

		var instance : TestInjection = injector.instantiateUnmapped(TestInjection);
		instance.hello();
	}
}
