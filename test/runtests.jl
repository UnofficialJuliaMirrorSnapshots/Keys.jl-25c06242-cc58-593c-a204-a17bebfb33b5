
using Keys
import Documenter: makedocs

makedocs(
    modules = [Keys],
    sitename = "Keys.jl",
    root = joinpath(dirname(@__DIR__), "docs"),
    strict = true
)

using Test: @test, @test_throws

x = (1, 2, 3)
t0 = ()
switch = (True(), True(), False())
new = (4, 5)

@test_throws ArgumentError reduce_unrolled(+, t0)

@test getindex_unrolled(x, t0) == t0
@test getindex_unrolled(t0, switch) == t0

@test setindex_unrolled(t0, t0, switch) == t0
@test setindex_unrolled(t0, new, t0) == t0
@test setindex_unrolled(t0, new, switch) == t0
@test setindex_unrolled(x, t0, t0) == x
@test setindex_unrolled(x, t0, switch) == x
@test setindex_unrolled(x, new, t0) == t0
@test setindex_unrolled(t0, t0, t0) == t0
