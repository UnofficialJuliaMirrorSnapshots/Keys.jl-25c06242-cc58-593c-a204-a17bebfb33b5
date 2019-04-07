module Keys

import Base: getindex, haskey, merge, convert, &, |, @pure, Bool, tail, Generator
import Base.Meta: quot
import MacroTools: @capture
import Base.Iterators: flatten
import Base: Generator

include("typed_bools.jl")
include("recur_unroll.jl")

export Key
"""
    struct Key{K}

A typed key. See [`@__str`](@ref) for an easy way to create keys. Use to create
[`Keyed`](@ref) values.
"""
struct Key{K} end

inner_value(k::Key{K}) where K = K

export @__str
"""
    @__str

make a key

```jldoctest
julia> using Keys

julia> _"a"
.a
```
"""
macro __str(s::String)
    esc(:($Key{$(quot(Symbol(s)))}()))
end

const SomeKeys = NTuple{N, Key} where N
const PairOfKeys = Pair{T1, T2} where {T1 <: Key, T2 <: Key}

function Base.show(io::IO, key::Key{K}) where K
    print(io, :.)
    print(io, K)
end

export Keyed
"""
    struct Keyed{K, V}

an alias for a [`Key`](@ref)-value pair. a tuple of `Keyed` values is aliased
as a [`KeyedTuple`](@ref).
"""
const Keyed{K, V} = Pair{Key{K}, V} where {K, V}

export key
"""
    key(keyed::Keyed)

get the key of a [`Keyed`](@ref) value.

```jldoctest
julia> using Keys

julia> key.((_"a" => 1, _"b" => 2))
(.a, .b)
```
"""
key(::Keyed{K}) where K = Key{K}()

export value
"""
    value(key::Keyed)

get the value of a [`Keyed`](@ref) value.

```jldoctest
julia> using Keys

julia> value.((_"a" => 1, _"b" => 2))
(1, 2)
```
"""
value(keyed_tuple::Keyed) = keyed_tuple.second

export KeyedTuple
"""
    const KeyedTuple

A tuple with only [`Keyed`](@ref) values. You can index them with [`Key`](@ref)s or
access them with dots. Duplicated keys are allowed; will return the
first match.

```jldoctest
julia> using Keys

julia> keyed_tuple = (_"a" => 1, _"b" => 2)
(.a => 1, .b => 2)

julia> keyed_tuple.b
2

julia> keyed_tuple[(_"a", _"b")]
(.a => 1, .b => 2)

julia> keyed_tuple.c
ERROR: Key .c not found
[...]

julia> haskey(keyed_tuple, _"b")
True()

julia> merge(keyed_tuple, (_"a" => 4, _"c" => 3))
(.b => 2, .a => 4, .c => 3)
```
"""
const KeyedTuple = Tuple{Keyed, Vararg{Keyed}}

match_key(::Keyed{K}, ::Key{K}) where K = True()
match_key(::Keyed, ::Key) = False()

function match_key(keyed::Keyed, keys::SomeKeys)
    reduce_unrolled(|, map(
        let keyed = keyed
            key -> match_key(keyed, key)
        end,
        keys
    ))
end

first_error(::Tuple{}, key::Key) = error("Key $key not found")
first_error(keyed_tuple::KeyedTuple, key::Key) = value(keyed_tuple[1])

which_key(keyed_tuple::KeyedTuple, key::Union{Key, SomeKeys}) = map(
    let key = key
        keyed -> match_key(keyed, key)
    end,
    keyed_tuple
)

_getindex(keyed_tuple, keys) =
    getindex_unrolled(keyed_tuple, which_key(keyed_tuple, keys))

getindex(keyed_tuple::KeyedTuple, key::Key) =
    first_error(_getindex(keyed_tuple, key), key)

getindex(keyed_tuple::KeyedTuple, keys::SomeKeys) =
    _getindex(keyed_tuple, keys)

haskey(keyed_tuple::KeyedTuple, key::Key) =
    reduce_unrolled(|, which_key(keyed_tuple, key))

export delete
"""
    delete(keyed_tuple::KeyedTuple, keys::Key...)

delete all [`Keyed`](@ref) values matching [`Key`](@ref)s in a [`KeyedTuple`](@ref).

```jldoctest
julia> using Keys

julia> delete((_"a" => 1, _"b" => 2), _"a")
(.b => 2,)
```
"""
delete(keyed_tuple::KeyedTuple, keys::Key...) =
    getindex_unrolled(keyed_tuple, map(
        not,
        which_key(keyed_tuple, keys)))

export push
"""
    push(keyed_tuple::KeyedTuple, pairs::Keyed...)

push the [`Keyed`](@ref) values in `pairs` into the
[`KeyedTuple`](@ref), replacing common [`Key`](@ref)s.

```jldoctest
julia> using Keys

julia> push((_"a" => 1, _"b" => 2), _"b" => 4, _"c" => 3)
(.a => 1, .b => 4, .c => 3)
```
"""
push(keyed_tuple::KeyedTuple, pairs::Keyed...) =
    delete(keyed_tuple, key.(pairs)...)..., pairs...

@inline Base.getproperty(key::KeyedTuple, s::Symbol) = getindex(key, Key{s}())

export map_values
"""
    map_values(f, keyed_tuple::KeyedTuple)

map `f` over the values of a [`KeyedTuple`](@ref).

```jldoctest
julia> using Keys

julia> map_values(x -> x + 1, (_"a" => 1, _"b" => 2))
(.a => 2, .b => 3)
```
"""
map_values(f, keyed_tuple::KeyedTuple) = map(
    let f = f
        keyed -> key(keyed) => f(value(keyed))
    end,
    keyed_tuple
)

rename_one(pair_of_keys::Keyed{New, Key{Old}}, old_keyed::Keyed{Old}) where {Old, New} =
    pair_of_keys.first => old_keyed.second
rename_one(pair_of_keys::PairOfKeys, old_keyed::Keyed) = old_keyed

rename_single(pair_of_keys::PairOfKeys, ::Tuple{}) = ()
rename_single(pair_of_keys::PairOfKeys, keyed_tuple::KeyedTuple) =
    rename_one(pair_of_keys, keyed_tuple[1]),
    rename_single(pair_of_keys, tail(keyed_tuple))...

rename(keyed_tuple::KeyedTuple) = keyed_tuple

export rename
"""
    rename(keyed_tuple::KeyedTuple, pairs_of_keys::PairOfKeys...)

for each pair of [`Key`](@ref)s, where the first key matches in
[`KeyedTuple`](@ref), it will be replaced by the second.

```jldoctest
julia> using Keys

julia> rename((_"a" => 1, _"b" => 2), _"c" => _"a")
(.c => 1, .b => 2)
```
"""
rename(keyed_tuple::KeyedTuple, pairs_of_keys::PairOfKeys...) =
    rename(rename_single(pairs_of_keys[1], keyed_tuple), tail(pairs_of_keys)...)

common_keys(x::KeyedTuple, y::KeyedTuple) =
    first.(filter_unrolled(pair -> pair[1] === pair[2], product_unrolled(key.(x), key.(y))))

merge(a::KeyedTuple, b::KeyedTuple) =
    (delete(a, common_keys(a, b)...)..., b...)

#=
@require DataFrames begin

    import DataFrames: DataFrame

    (::Type{KeyedTuple})(d::DataFrame) = (map(
        (name, column) -> Key{name}() => (column),
        names(d),
        d.columns
    )...)

    DataFrame(k::KeyedTuple) =
        DataFrame(map(x -> inner_value(x.first) => x.second, k)...)

end
=#

substitute_underscores!(dictionary, body) = body
substitute_underscores!(dictionary, body::Symbol) =
    if all(isequal('_'), string(body))
        if !haskey(dictionary, body)
            dictionary[body] = gensym("argument")
        end
        dictionary[body]
    else
        body
    end
substitute_underscores!(dictionary, body::Expr) =
    if body.head == :quote
        body
    elseif @capture body @_ args__
        body
    else
        Expr(body.head,
            map(body -> substitute_underscores!(dictionary, body), body.args)
        ...)
    end

string_length(something) = something |> String |> length

function anonymize(body, line, file)
    dictionary = Dict{Symbol, Symbol}()
    new_body = substitute_underscores!(dictionary, body)
    sorted_dictionary = sort(
        lt = (pair1, pair2) ->
            isless(string_length(pair1.first), string_length(pair2.first)),
        collect(dictionary)
    )
    Expr(:->,
        Expr(:tuple, Generator(pair -> pair.second, sorted_dictionary)...),
        Expr(:block, LineNumberNode(line, file), new_body)
    )
end

export @_
"""
    macro _(body::Expr)

Another syntax for anonymous functions. The arguments are inside the body; the
first arguments is `_`, the second argument is `__`, etc.

```jldoctest
julia> using Keys

julia> 1 |> (@_ _ + 1)
2

julia> map((@_ __ - _), (1, 2), (2, 1))
(1, -1)
```
"""
macro _(body::Expr)
    anonymize(body, @__LINE__, @__FILE__) |> esc
end

build_call(afunction, arguments, parity, line, file) =
    if length(arguments) >= parity
        anonymous_arguments = ((anonymize(argument, line, file), quot(argument))
            for argument in arguments[parity+1:end])
        Expr(:call,
            afunction,
            arguments[1:parity]...,
            flatten(anonymous_arguments)...
        )
    else
        error("Expecting at least $parity argument(s)")
    end

anonymize_arguments(atail, line, file) =
    if @capture atail numberedfunction_(arguments__)
        string_function = string(numberedfunction)
        parity = tryparse(Int, string(string_function[end]))
        if parity == nothing
            atail
        else
            build_call(Symbol(chop(string_function)), arguments, parity, line, file)
        end
    else
        atail
    end

query(body, line, file)  =
    if @capture body head_ |> atail_
        Expr(:call, anonymize(anonymize_arguments(atail, line, file), line, file),
            query(head, line, file)
        )
    else
        body
    end

export @query
"""
    macro query(body::Expr)

Query your code. If body is a chain `head_ |> tail_`, recur on
head. If tail is a function call, and the function ends
with a number (the parity), anonymize and quote arguments past that parity.
Either way, anonymize the whole tail, then call it on head.

```jldoctest
julia> using Keys

julia> call(source1, source2, anonymous, quoted) = anonymous(source1, source2);

julia> @query 1 |> (_ - 2) |> abs(_) |> call2(_, 2, _ + __)
3

julia> @query 1 |> call2(_)
ERROR: LoadError: Expecting at least 2 argument(s)
[...]
```
"""
macro query(body)
    line = @__LINE__
    file = @__FILE__
    query(body, line, file) |> esc
end

end
