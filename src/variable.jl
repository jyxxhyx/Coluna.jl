mutable struct Variable <: AbstractVarConstr
    var_uid::VarId
    form_uid::FormId
    name::String
    cost::Float64 
    lower_bound::Float64
    upper_bound::Float64 
    kind::VarKind
    flag::Flag     # Static, Dynamic, Artifical, Implicit
    duty::VarDuty
    sense::VarSense 
end

function Variable(m::AbstractModel, form_uid::FormId, n::String, c::Float64, lb::Float64, 
                  ub::Float64, t::VarKind, flag::Flag, d::VarDuty, s::VarSense)
    uid = getnewuid(m.var_counter)
    return Variable(uid, form_uid, n, c, lb, ub, t, flag, d, s)
end

function Variable(m::AbstractModel,  n::String)
    return Variable(m, 0, n, 0.0, -Inf, Inf, Continuous, Static, OriginalVar, Free)
end

getuid(v::Variable) = v.var_uid
getform(v::Variable) = v.form_uid
getname(v::Variable) = v.name
getcost(v::Variable) = v.cost
getlb(v::Variable) = v.lower_bound
getub(v::Variable) = v.upper_bound
gettype(v::Variable) = v.kind
getduty(v::Variable) = v.duty
getsense(v::Variable) = v.sense
getflag(v::Variable) = v.flag

setcost!(v::Variable, c::Float64) = v.cost += c
setname!(v::Variable, name::String) = v.name = name
setform!(v::Variable, uid::FormId) = v.form_uid = uid
setlowerbound!(v::Variable, lb::Float64) = v.lower_bound = lb
setupperbound!(v::Variable, ub::Float64) = v.upper_bound = ub
setduty!(v::Variable, d::VarDuty) = v.duty = d
settype!(v::Variable, t::VarKind) = v.kind = t
setsense!(v::Variable, s::VarSense) = v.sense = s

function set!(v::Variable, ::MOI.ZeroOne)
    settype!(v, Binary)
    setsense!(v, Positive)
    (v.lower_bound < 0) && setlowerbound!(v, 0.0)
    (v.upper_bound > 1) && setupperbound!(v, 1.0)
    return
end

function set!(v::Variable, ::MOI.Integer)
    settype!(v, Integ)
    return
end

function set!(v::Variable, s::MOI.GreaterThan)
    lb = float(s.lower)
    (v.lower_bound < lb) && setlowerbound!(v, lb)
    (lb >= 0) && setsense!(v, Positive)
    return
end

function set!(v::Variable, s::MOI.EqualTo)
    val = float(s.value)
    setlowerbound!(v, val)
    setupperbound!(v, val)
    return
end

function set!(v::Variable, s::MOI.LessThan)
    ub = float(s.upper)
    (v.upper_bound > ub) && setupperbound!(v, ub)
    (ub <= 0) && settype!(v, Negative)
    return
end

