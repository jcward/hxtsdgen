package hxtsdgen;

import haxe.macro.Type;
import hxtsdgen.Generator;

using haxe.macro.Tools;

class Selector {

    public var exposed:Array<ExposeKind>;
    public var onAutoInclude:Array<ExposeKind> -> Void;

    var isIncluded:Map<String, Bool>;

    public function new() {
        isIncluded = new Map<String, Bool>();
    }

    public function getExposed(types:Array<Type>) {
        exposed = [];
        for (type in types) {
            switch [type, type.follow()] {
                case [TType(_.get() => t, _), TAnonymous(_.get() => anon)]:
                    if (t.meta.has(":expose")) {
                        exposed.push(ETypedef(t, anon));
                    }
                case [_, TInst(_.get() => cl, _)]:
                    if (cl.meta.has(':enum')) {
                        if (Generator.GEN_ENUM_TS || cl.meta.has(":expose"))
                            exposed.push(EEnum(cl));
                    } else {
                        exposeClass(cl);
                    }
                default:
            }
        }
        return exposed.length;
    }

    function exposeClass(cl:ClassType, autoInclude = false) {
        if (autoInclude) {
            if (isIncluded.exists(cl.name)) return;
        }
        isIncluded.set(cl.name, true);

        if (autoInclude || cl.meta.has(":expose")) {
            if (cl.interfaces != null && cl.interfaces.length > 0) {
                for (item in cl.interfaces) {
                    var sup = item.t.get();
                    if (!sup.meta.has(":expose")) {
                        exposeClass(sup, true);
                    }
                }
            }
            if (cl.superClass != null) {
                var sup = cl.superClass.t.get();
                if (!sup.meta.has(":expose")) {
                    exposeClass(sup, true);
                }
            }
            exposed.push(EClass(cl));
        }
        for (f in cl.statics.get()) {
            if (f.meta.has(":expose"))
                exposed.push(EMethod(cl, f));
        }
    }

    public function ensureIncluded(t:Type) {
        // A type is referenced, maybe it needs to be generated as well
        switch [t, t.follow()] {
            case [_, TInst(_.get() => cl, _)] if (!cl.isExtern && !cl.meta.has(":expose")):
                var key = cl.pack.join('.') + '.' + cl.name;
                if (!isIncluded.exists(key)) {
                    isIncluded.set(key, true);
                    onAutoInclude([EClass(cl)]);
                }
                return true;
            case [TType(_.get() => tt, _), TAnonymous(_.get() => anon)] if (!tt.meta.has(":expose")):
                var key = tt.pack.join('.') + '.' + tt.name;
                if (!isIncluded.exists(key)) {
                    isIncluded.set(key, true);
                    onAutoInclude([ETypedef(tt, anon)]);
                }
                return true;
            case [TAbstract(_.get() => ab, params), _] if (!ab.meta.has(":expose")):
                var cl = ab.impl.get();
                if (cl.meta.has(':enum')) {
                    var key = cl.pack.join('.') + '.' + cl.name;
                    if (!isIncluded.exists(key)) {
                        isIncluded.set(key, true);
                        onAutoInclude([EEnum(cl)]);
                    }
                    return true;
                }
            case [TEnum(_.get() => et, params), _]:
                var key = et.pack.join('.') + '.' + et.name;
                if (!isIncluded.exists(key)) {
                    isIncluded.set(key, true);
                    onAutoInclude([EEnumArray(et)]);
                }
                return true;

            default:
        }
        return false;
    }
}
