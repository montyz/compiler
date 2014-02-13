package mantra.symbols;

import org.antlr.v4.runtime.tree.ParseTree;

public class BaseSymbol implements Symbol {
	public String name;      // All symbols at least have a name
	public Type type;
	public Scope scope;      // All symbols know what scope contains them.
	public ParseTree def;    // points at ID node in tree

	public BaseSymbol(String name) { this.name = name; }
	public BaseSymbol(String name, Type type) { this(name); this.type = type; }
	public String getName() { return name; }

	public String toString() {
		String s = "";
		if ( scope!=null ) s = scope.getScopeName()+".";
		if ( type!=null ) return '<'+s+getName()+":"+type+'>';
		return s+getName();
	}
}