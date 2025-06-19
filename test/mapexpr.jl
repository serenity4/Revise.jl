using Revise, Test
import Core: @latestworld
using Logging
!@isdefined(var"@yry") && include("common.jl")

empty!(Revise.queue_errors)
Revise.retry()

testdir = newtestdir()

unique_name(base) = Symbol(replace(lstrip(String(gensym(base)), '#'), '#' => '_'))

a1 = "a = 1"
a2 = "a = 2"
b1 = "b(x) = 1 + x"
b2 = "b(x::Float64) = 2 + x"

name = unique_name(:MapExpr)
src = """
module $name

global state

include("a.jl") do ex
  @assert Meta.isexpr(ex, :(=), 2)
  ex.args[2] = :(1 + \$(ex.args[2]::Int))
  return ex
end
function add_neg!(ex::Expr)
  @assert Meta.isexpr(ex, :(=), 2)
  rhs = ex.args[2]
  rhs.args[1] = :(-\$(rhs.args[1]::Int))
  return ex
end
Base.include((state = rand(); assign_neg!), $name, "b.jl")

end # module
"""
dn = joinpath(testdir, "$name", "src")
mkpath(dn)
write(joinpath(dn, "$name.jl"), src)
write(joinpath(dn, "a.jl"), a1)
write(joinpath(dn, "b.jl"), b1)
sleep(mtimedelay)
@eval import $name
sleep(mtimedelay)
mod = @eval $name
@test mod.a === 2
@test mod.b(0) === -1
write(joinpath(dn, "a.jl"), a2)
write(joinpath(dn, "b.jl"), b2)
@yry()
@test mod.a === 3
@test !hasmethod(mod.b, Tuple{Int})
@test mod.b(0.0) === -2.0

# XXX: test that extracting method signatures does go through `mapexpr`.
# XXX: ensure that when we track methods we always go through it as well.
# XXX: ensure that when we revise an `include(mapexpr, ...)` with a different `mapexpr` it updates it.
# XXX: revise entire included file when `mapexpr` changes.
