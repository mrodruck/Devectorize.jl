# This file defines a hierarchy of typed expressions


##########################################################################
#
# 	Typed expressions
#
##########################################################################

# modes: the role/functionality of an expression

abstract TMode
type ScalarMode <: TMode end
type EWiseMode{D} <: TMode end
type ReducMode <: TMode end
type ColwiseReducMode <: TMode end
type RowwiseReducMode <: TMode end

# types

abstract TExpr

# expressions that can be an argument for element-wise computation
abstract TEWise <: TExpr

# expressions that is sured to be a scalar
abstract TScalar <: TEWise

type TEmpty <: TExpr end

# simple expressions

type TNum{T<:Number} <: TScalar
	val::T
end

== (a::TNum, b::TNum) = (a.val == b.val)
!= (a::TNum, b::TNum) = !(a == b)

type TScalarVar <: TScalar
	name::Symbol
end

== (a::TScalarVar, b::TScalarVar) = (a.name == b.name)
!= (a::TScalarVar, b::TScalarVar) = !(a == b)

type TVar <: TEWise
	name::Symbol
end

== (a::TVar, b::TVar) = (a.name == b.name)
!= (a::TVar, b::TVar) = !(a == b)

# qualified variable, e.g. abc.x
type TQVar <: TEWise
	form::Expr
end

== (a::TQVar, b::TQVar) = (a.form == b.form)
!= (a::TQVar, b::TQVar) = !(a == b)

TGeneralVar = Union(TVar, TQVar)


# references

abstract TRef <: TEWise

typealias TIndex Union(Int,Symbol)
abstract TRange

type TColon <: TRange end
type TInterval <: TRange
	first::TIndex
	last::Union(TIndex,Nothing)
end

== (a::TInterval, b::TInterval) = (a.first == b.first) && (a.last == b.last)
!= (a::TInterval, b::TInterval) = !(a == b)

abstract TRefScalar <: TScalar

type TRefScalar1 <: TRefScalar
	host::TGeneralVar
	i::TIndex
end

== (a::TRefScalar1, b::TRefScalar1) = (a.host == b.host) && (a.i == b.i)
!= (a::TRefScalar1, b::TRefScalar1) = !(a == b)

type TRefScalar2 <: TRefScalar
	host::TGeneralVar
	i::TIndex
	j::TIndex
end

== (a::TRefScalar2, b::TRefScalar2) = (a.host == b.host) && (a.i == b.i) && (a.j == b.j)
!= (a::TRefScalar2, b::TRefScalar2) = !(a == b)

type TRef1D <: TRef
	host::TGeneralVar
	rgn::TRange
end

== (a::TRef1D, b::TRef1D) = (a.host == b.host) && (a.rgn == b.rgn)
!= (a::TRef1D, b::TRef1D) = !(a == b)

type TRefCol <: TRef
	host::TGeneralVar
	rrgn::TRange
	icol::TIndex
end

== (a::TRefCol, b::TRefCol) = (a.host == b.host) && (a.rrgn == b.rrgn) && (a.icol == b.icol)
!= (a::TRefCol, b::TRefCol) = !(a == b)

type TRefRow <: TRef
	host::TGeneralVar
	irow::TIndex
	crgn::TRange
end

== (a::TRefRow, b::TRefRow) = (a.host == b.host) && (a.irow == b.irow) && (a.crgn == b.crgn)
!= (a::TRefRow, b::TRefRow) = !(a == b)

type TRef2D <: TRef
	host::TGeneralVar
	rrgn::TRange
	crgn::TRange
end

== (a::TRef2D, b::TRef2D) = (a.host == b.host) && (a.rrgn == b.rrgn) && (a.crgn == b.crgn)
!= (a::TRef2D, b::TRef2D) = !(a == b)

# function calls

type TMap <: TEWise
	fun::Symbol
	args::(TEWise...,)
	mode::TMode
	deps::Union(Array{TExpr}, Nothing)
end

type TReduc <: TExpr
	fun::Symbol
	args::(TEWise...,)
	arg_mode::TMode
	deps::Union(Array{TExpr}, Nothing)
end

type TColwiseReduc <: TExpr
	fun::Symbol
	args::(TEWise...,)
	deps::Union(Array{TExpr}, Nothing)
end

type TRowwiseReduc <: TExpr
	fun::Symbol
	args::(TEWise...,)
	deps::Union(Array{TExpr}, Nothing)
end

typealias TFunCall Union(TMap, TReduc, TColwiseReduc, TRowwiseReduc)

function == (a::TFunCall, b::TFunCall) 
	na = length(a.args)
	if a.fun == b.fun && typeof(a) == typeof(b) && na == length(b.args)
		for i = 1 : na
			if !(a.args[i] == b.args[i])
				return false
			end
		end
		return true
	end
	return false
end

!= (a::TFunCall, b::TFunCall) = !(a == b)

# others

typealias TRValue Union(TEWise, TFunCall)
typealias TLValue Union(TGeneralVar, TRefScalar, TRef)

type TAssign{Lhs<:TLValue, Rhs<:TRValue} <: TExpr
	lhs::Lhs
	rhs::Rhs
	mode::TMode
end

== (a::TAssign, b::TAssign) = (a.lhs == b.lhs) && (a.rhs == b.rhs)
!= (a::TAssign, b::TAssign) = !(a == b)

is_trivial_assignment(ex::TAssign) = isa(ex.lhs, TGeneralVar) &&
	(isa(ex.rhs, TGeneralVar) || isa(ex.rhs, TNum))

type TBlock <: TExpr
	stmts::Array{TAssign}
	TBlock() = new(TAssign[])
end

== (a::TBlock, b::TBlock) = length(a.stmts) == length(b.stmts) && all(a.stmts .== b.stmts)
!= (a::TBlock, b::TBlock) = !(a == b)


##########################################################################
#
# 	Determining the expression mode
#
#	i.e. what kind of things that the whole expression wants to do
#	(ewise, reduc, etc)
#
##########################################################################

tmode_num{D}(::EWiseMode{D}) = D

tmode(ex::TScalar) = ScalarMode()
tmode(ex::TGeneralVar) = EWiseMode{0}()

tmode(ex::TRef1D) = EWiseMode{1}() 
tmode(ex::TRef2D) = EWiseMode{2}()
tmode(ex::TRefCol) = EWiseMode{1}()
tmode(ex::TRefRow) = EWiseMode{1}()

tmode(ex::TMap) = ex.mode
tmode(ex::TReduc) = isa(ex.arg_mode, ScalarMode) ? ScalarMode() : ReducMode()
tmode(ex::TColwiseReduc) = ColwiseReducMode()
tmode(ex::TRowwiseReduc) = RowwiseReducMode()

tmode(ex::TAssign) = ex.mode

promote_ewise_tmode(m::TMode) = m
promote_ewise_tmode(m1::ScalarMode, m2::ScalarMode) = ScalarMode()
promote_ewise_tmode(m1::ScalarMode, m2::EWiseMode) = EWiseMode{tmode_num(m2)}()
promote_ewise_tmode(m1::EWiseMode, m2::ScalarMode) = EWiseMode{tmode_num(m1)}()

function promote_ewise_tmode(m1::EWiseMode, m2::EWiseMode)
	d1 = tmode_num(m1)
	d2 = tmode_num(m2)

	d1 == d2 ? EWiseMode{d1}() :
	d1 == 0 ? EWiseMode{d2}() :
	d2 == 0 ? EWiseMode{d1}() :
	throw(DeError("Incompatible ewise mode."))
end

promote_ewise_tmode(m1::TMode, m2::TMode, m3::TMode) = promote_ewise_tmode(promote_ewise_tmode(m1, m2), m3)



##########################################################################
#
# 	functions to construct simple components of a typed expression
#
##########################################################################

type DeError <: Exception
	msg::ASCIIString
end

# number literals

tnum(x::Number) = TNum{typeof(x)}(x)

# variable

tvar(s::Symbol) = TVar(s)
tscalarvar(s::Symbol) = TScalarVar(s)

# qualified variable

function is_valid_tqvar(ex::Expr)
	@assert ex.head == :(.) && length(ex.args) == 2

	a1 = ex.args[1]
	a2 = ex.args[2]

	(isa(a1, Symbol) || is_valid_tqvar(a1)) &&
	a2.head == (:quote) && isa(a2.args[1], Symbol)
end

function tqvar(ex::Expr) 
	if !is_valid_tqvar(ex)
		throw(DeError("$ex is not a valid form for variable."))
	end
	TQVar(ex)
end


# reference expressions

function check_simple_ref(c::Bool)
	if !c
		throw(DeError("non-simple ref-expression is not supported"))
	end
end

tref_arg(i::Int) = i
tref_arg(i::Symbol) = i == :(:) ? TColon() : i

function tref_arg(ex::Expr)
	check_simple_ref(ex.head == :(:) && length(ex.args) == 2)
	a1 = ex.args[1]
	a2 = ex.args[2]
	
	if isa(a1, Int) || (isa(a1, Symbol) && a1 != :(:))
		first = a1
	else
		check_simple_ref(false)
	end

	if isa(a2, Int)
		last = a2
	elseif isa(a2, Symbol)
		last = a2 == :(:) ? nothing : a2
	else
		check_simple_ref(false)
	end

	TInterval(first, last)
end

tref(x::TGeneralVar, i::TIndex) = TRefScalar1(x, i)
tref(x::TGeneralVar, r::TRange) = TRef1D(x, r)

tref(x::TGeneralVar, i::TIndex, j::TIndex) = TRefScalar2(x, i, j)
tref(x::TGeneralVar, i::TIndex, c::TRange) = TRefRow(x, i, c)
tref(x::TGeneralVar, r::TRange, j::TIndex) = TRefCol(x, r, j)
tref(x::TGeneralVar, r::TRange, c::TRange) = TRef2D(x, r, c)

function tref(ex::Expr)
	@assert ex.head == :(ref)

	na = length(ex.args)
	check_simple_ref(na == 2 || na == 3)

	h = ex.args[1]
	if isa(h, Symbol)		
		h = tvar(h)
	elseif isa(h, Expr) && h.head == :(.)
		h = tqvar(h)
	else
		check_simple_ref(false)
	end

	if na == 2
		a1 = ex.args[2]
		tref(h, tref_arg(a1))

	else 
		a1 = ex.args[2]
		a2 = ex.args[3]
		tref(h, tref_arg(a1), tref_arg(a2))
	end
end


##########################################################################
#
# 	function call recognition
#
##########################################################################

is_ewise_call(f::Symbol, N::Int) = isa(get_op_kind(TCallSig{f, N}()), EWiseOp)
is_reduc_call(f::Symbol, N::Int) = isa(get_op_kind(TCallSig{f, N}()), ReducOp)

function check_funcall_args(args::TExpr...)
	na = length(args)
	deps = nothing

	pargs = Array(TExpr, na)

	for i = 1 : na
		a = args[i]
		if isa(a, TEWise)
			pargs[i] = a
		elseif isa(a, TReduc) || isa(a, TColwiseReduc) || isa(a, TRowwiseReduc)
			dep_sym = gensym("dep")
			pargs[i] = isa(a, TReduc) ? TScalarSym(dep_sym) : TVar(dep_sym)
			if deps == nothing
				deps = TExpr[]
			end
			push!(deps, tassign(TVar(dep_sym), a))
		else
			throw(DeError("Arguments in unsupported form."))
		end
	end
	(tuple(pargs...), deps)
end

# due to intricate semantics of partial reduction in Julia syntax
# we here hand-coded the specific form to be recognized as partial reduction

function recognize_partial_reduction(f::Symbol, a::TExpr...)
	if f == (:sum) || f == (:mean)
		if length(a) == 2 && isa(a[2], TNum{Int})
			fargs, deps = check_funcall_args(a[1])
			dim = a[2].val
			if dim == 1
				TColwiseReduc(f, fargs, deps)
			elseif dim == 2
				TRowwiseReduc(f, fargs, deps)
			else
				throw(DeError("DeExpr supports either colwise or rowwise reduction."))
			end
		end
	elseif f == (:max) || f == (:min)
		if length(a) == 3 && isa(a[2], TEmpty) && isa(a[3], TNum{Int})
			fargs, deps = check_funcall_args(a[1])
			dim = a[3].val
			if dim == 1
				TColwiseReduc(f, fargs, deps)
			elseif dim == 2
				TRowwiseReduc(f, fargs, deps)
			else
				throw(DeError("DeExpr supports either colwise or rowwise reduction."))
			end
		end
	end
end


function tcall(f::Symbol, args)
	n = length(args)
	if is_ewise_call(f, n)
		fargs, deps = check_funcall_args(args...)
		mode = promote_ewise_tmode([tmode(a) for a in fargs]...)
		TMap(f, fargs, mode, deps)

	elseif is_reduc_call(f, n)
		fargs, deps = check_funcall_args(args...)
		arg_mode = promote_ewise_tmode([tmode(a) for a in fargs]...)
		TReduc(f, fargs, arg_mode, deps)

	elseif f == :(*)
		throw(DeError("DeExpr does not support *, please use .* to express element-wise multiplication."))
		
	elseif f == :(/)
		throw(DeError("DeExpr does not support /, please use ./ to express element-wise division."))
		
	elseif f == :(^)
		throw(DeError("DeExpr does not support ^, please use .^ to express element-wise power."))

	else
		ex = recognize_partial_reduction(f, args...)
		if ex == nothing
			throw(DeError("Unrecognized function $f with $n arguments (in DeExpr)"))
		end
		return ex
	end
end

function tcall(ex::Expr)
	@assert ex.head == :(call)
	fsym = ex.args[1]
	if !isa(fsym, Symbol)
		throw(DeError("call-expressions with non-symbol function name: $fsym"))
	end
	tcall(fsym, map(texpr, ex.args[2:]))
end

function tcomparison(ex::Expr)
	@assert ex.head == :(comparison)
	opsym = ex.args[2]
	tcall(opsym, map(texpr, [ex.args[1], ex.args[3]]))
end




##########################################################################
#
# 	assignment construction
#
##########################################################################

function decide_assign_tmode(lhs::TExpr, rhs::TExpr)

	# TScalarSym can only be created internally, which would never
	# be placed on the left hand side
	@assert !isa(lhs, TScalarVar)

	if isa(lhs, TGeneralVar)
		mode = tmode(rhs)

	elseif isa(lhs, TRefScalar)
		rmode = tmode(rhs)
		if isa(rmode, ScalarMode) || isa(rmode, EWiseMode{0})
			mode = ScalarMode()
		elseif isa(rmode, ReducMode)
			mode = ReducMode()
		else
			throw(DeError("rhs cannot contain non-scalar ref when lhs is a scalar-ref."))
		end

	elseif isa(lhs, TRef)
		@assert isa(lhs, TEWise)
		rmode = tmode(rhs)
		if isa(rmode, EWiseMode) || isa(rmode, ScalarMode)
			mode = promote_ewise_tmode(tmode(lhs), rmode)
		elseif isa(rmode, ColwiseReducMode) || isa(rmode, RowwiseReducMode)
			mode = rmode
		else
			throw(DeError("Incompatible lhs and rhs."))
		end

	else
		throw(DeError("Incompatible modes between lhs and rhs."))
	end
end


function tassign(lhs::TExpr, rhs::TExpr)
	if isa(rhs, TAssign)
		throw(DeError("chained assignment is not supported by DeExpr"))
	end
	mode = decide_assign_tmode(lhs, rhs)
	TAssign{typeof(lhs),typeof(rhs)}(lhs, rhs, mode)
end


function topassign(aop::Symbol, lhs::TExpr, rhs::TExpr)
	op = extract_assign_op(aop)
	new_rhs = tcall(op, [lhs, rhs])
	tassign(lhs, new_rhs)
end


function tassign(ex::Expr)
	@assert ex.head == :(=)
	@assert length(ex.args) == 2

	lhs = ex.args[1]
	rhs = ex.args[2]
	tassign(texpr(lhs), texpr(rhs))
end

function topassign(ex::Expr)
	topassign(ex.head, texpr(lhs), texpr(rhs))
end


##########################################################################
#
# 	block construction
#
##########################################################################


function tblock(blk_ex::Expr)

	@assert blk_ex.head == :(block)

	blk = TBlock()
	for e in ex.args
		if isa(e, LineNumberNode) || e.head == (:line)
			continue
		end
		if !(e.head == :(=) || ex.head == :(block))
			throw(DeError("Each statement in a block must be an assignment or a nested block"))
		end
		push!(blk.stmts, texpr(e))
	end
	blk
end



##########################################################################
#
# 	AST construction:  Expr ==> TExpr
#
##########################################################################

texpr(x::Number) = tnum(x)
texpr(x::Symbol) = tvar(x)

is_empty_tuple(ex::Expr) = ex.head == :(tuple) && isempty(ex.args)

texpr(ex::Expr) = 
	ex.head == :(.) ? tqvar(ex) :
	ex.head == :(call) ? tcall(ex) :
	ex.head == :(comparison) ? tcomparison(ex) :
	ex.head == :(ref) ? tref(ex) :
	ex.head == :(=) ? tassign(ex) :
	ex.head == :(block) ? tblock(ex) :
	is_empty_tuple(ex) ? TEmpty() :
	is_opassign(TFun{ex.head}()) ? topassign(ex) :
	throw(DeError("Unrecognized expression: $ex"))



