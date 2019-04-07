export TypedBool
"""
    abstract TypedBool

typed bools, [`True`](@ref) and [`False`](@ref), can guarantee type stability in
cases where constant propogation is not working for Bools.

```jldoctest
julia> using Keys

julia> Bool(False())
false

julia> Bool(True())
true

julia> TypedBool(false)
False()

julia> TypedBool(true)
True()

julia> True() & True() & False()
False()

julia> False() & False() & True()
False()

julia> True() | True() | False()
True()

julia> False() | False() | True()
True()

```
"""
abstract type TypedBool end
@inline TypedBool(b::Bool) =
    if b
        True()
    else
        False()
    end

export True
"a [`TypedBool`](@ref)"
struct True <: TypedBool end

export False
"a [`TypedBool`](@ref)"
struct False <: TypedBool end

Bool(::True) = true
Bool(::False) = false

(&)(::False, ::False) = False()
(&)(::False, ::True) = False()
(&)(::True, ::False) = False()
(&)(::True, ::True) = True()

(|)(::False, ::False) = False()
(|)(::False, ::True) = True()
(|)(::True, ::False) = True()
(|)(::True, ::True) = True()

export not
"""
    not(x)

[`TypedBool`](@ref) aware version of `!`.

```jldoctest
julia> using Keys

julia> not(True())
False()

julia> not(False())
True()
```
"""
not(::False) = True()
not(::True) = False()

"""
    if_else(switch, new, old)

[`TypedBool`](@ref) aware version of `ifelse`.

```julia
julia> using Keys

julia> if_else(true, 1, 0)
1

julia> if_else(True(), 1, 0)
1

julia> if_else(False(), 1, 0)
0
```
"""
if_else(b::Bool, new, old) = ifelse(b, new, old)  # generic fallback
if_else(::True, new, old) = new
if_else(::False, new, old) = old

export same_type
"""
    same_type(a, b)

Check whether `a` and `b` are the same type; return a [`TypedBool`](@ref).

```jldoctest
julia> using Keys

julia> same_type(1, 2)
True()

julia> same_type(1, 2.0)
False()
```
"""
same_type(a::T, b::T) where T = True()
same_type(a, b) = False()
