ExpandContext struct #RefType {
	top Namespace
}

Expander {
	expandPass1(c ExpandContext) {
		expandNamespace1(c, c.top)
	}
	
	expandNamespace1(c ExpandContext, ns Namespace) {
		for e in ns.members {
			mem := e.value
			match mem {
				Namespace: expandNamespace1(c, mem)
				FunctionDef: expandFunction(c, mem)
				default: {}
			}
		}
	}
	
	expandFunction(c ExpandContext, func FunctionDef) {
		if func.tas == null {
			return
		}
		for ta in func.tas {
			expandFunctionVariant(c, func, ta)
		}
	}
	
	expandFunctionVariant(c ExpandContext, func FunctionDef, ta Array<Tag>) {
		if func.outgoingCalls != null {
			for call in func.outgoingCalls {
				closed := TypeChecker.closeTagArgs(call.ta, func.typeParamList, ta)
				if call.to.tas.tryAdd(closed) {
					expandFunctionVariant(c, call.to, closed)
				}			
			}
		}
		if func.typeUsages != null {
			for usage in func.typeUsages {
				closedArgs := TypeChecker.closeTagArgs(usage.args, func.typeParamList, ta)
				usage.ti.tas.tryAdd(closedArgs)
			}
		}
	}
	
	expandPass2(c ExpandContext) {
		expandNamespace2(c, c.top)
	}
	
	expandNamespace2(c ExpandContext, ns Namespace) {
		for e in ns.members {
			mem := e.value
			match mem {
				Namespace: expandNamespace2(c, mem)
				default: {}
			}
		}
		if ns.typeParamList != null {
			for ta in ns.tas {
				expandStructVariant(c, ns, ta)
			}
		}
	}
	
	expandStructVariant(c ExpandContext, type Namespace, ta Array<Tag>) {
		if type.typeUsages != null {
			for usage in type.typeUsages {
				closedArgs := TypeChecker.closeTagArgs(usage.args, type.typeParamList, ta)
				if usage.ti.tas.tryAdd(closedArgs) {
					expandStructVariant(c, usage.ti, closedArgs)
				}
			}
		}
	}	

	debug(outer Namespace) {
		for e in outer.members {
			mem := e.value
			match mem {
				Namespace: {
					ns := mem
					if ns.typeParamList != null {
						Stdout.writeLine(ns.name)
						for ta in ns.tas {
							Stdout.writeLine(format("  {}", Tag.argsToString(ta)))
						}
					}
					debug(ns)
				}
				FunctionDef: {
					func := mem
					if func.typeParamList != null {
						Stdout.writeLine(format("{}.{}", func.ns.name, func.name.value))
						for ta in func.tas {
							Stdout.writeLine(format("  {}", Tag.argsToString(ta)))
						}
					}
				}
				default: {}
			}			
		}
	}
}
