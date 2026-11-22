#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/**
 * Gives the Int, UInt, Float and Bool fields left without a value the value Flash gives them: 0, 0.0 or false.
 * In JS they would be undefined: 10 + undefined is NaN, and undefined == 0 is false.
 * Applied to every class of the JS build (common.hxml). Fields set by Type.createEmptyInstance skip it, as they skip constructors.
 * @spec html5::flash-default-values
 */
class FlashDefaults {
	public static macro function build():Array<Field> {
		var fields = Context.getBuildFields();
		var owner = Context.getLocalClass();
		// The standard library is written for each target: it is left as it is (changing it breaks its core types).
		if (owner == null || owner.get().isExtern || owner.get().isInterface || isStandardLibrary(owner.get().pos))
			return null;
		var changed = false;
		for (field in fields) {
			if (field.access != null && (field.access.indexOf(AInline) >= 0 || field.access.indexOf(AExtern) >= 0))
				continue;
			switch (field.kind) {
				case FVar(type, null) if (defaultOf(type) != null):
					field.kind = FVar(type, defaultOf(type));
					changed = true;
				case FProp(get, set, type, null) if (defaultOf(type) != null && (get == "default" || get == "null" || set == "default" || set == "null" || hasIsVar(field))):
					field.kind = FProp(get, set, type, defaultOf(type));
					changed = true;
				case _:
			}
		}
		// Returning the fields unchanged would still redefine core types, which the compiler refuses.
		return changed ? fields : null;
	}

	static function isStandardLibrary(position:Position) {
		return Context.getPosInfos(position).file.split("\\").join("/").indexOf("/std/") >= 0;
	}

	static function hasIsVar(field:Field) {
		return field.meta != null && Lambda.exists(field.meta, function(m) return m.name == ":isVar");
	}

	static function defaultOf(type:ComplexType):Expr {
		if (type == null) return null;
		return switch (type) {
			case TPath({pack: [], name: "Int" | "UInt", params: []}): macro 0;
			case TPath({pack: [], name: "Float", params: []}): macro 0.0;
			case TPath({pack: [], name: "Bool", params: []}): macro false;
			case _: null;
		}
	}
}
