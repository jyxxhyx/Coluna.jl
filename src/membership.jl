mutable struct Filter
    used_mask::SparseVector{Bool,Int}
    active_mask::SparseVector{Bool,Int}
    static_mask::SparseVector{Bool,Int}
    artificial_mask::SparseVector{Bool,Int}
end

Filter() = Filter(spzeros(MAX_SV_ENTRIES), spzeros(MAX_SV_ENTRIES), spzeros(MAX_SV_ENTRIES), spzeros(MAX_SV_ENTRIES))

activemask(f::Filter) = f.used_mask .& f.active_mask
staticmask(f::Filter) = f.used_mask .& f.static_mask
artificalmask(f::Filter) = f.used_mask .& f.artificial_mask
#selectivemask(f::Filter, active::Bool, static::Bool, artificial::Bool) = f.used_mask active ? .& f.active_mask : nothing  static ? .& f.static_mask : nothing  artificial ? .& f.artificial_mask : nothing

struct Memberships
    var_to_constr_members::Dict{VarId, ConstrMembership}
    var_to_partialsol_members::Dict{VarId, VarMembership}
    var_to_expression_members::Dict{VarId, VarMembership}
    constr_to_var_members::Dict{ConstrId, VarMembership}
end

function Memberships()
    var_m = Dict{VarId, ConstrMembership}()
    partialsol_m = Dict{VarId, VarMembership}()
    expression_m = Dict{VarId, VarMembership}()
    constr_m = Dict{ConstrId, ConstrMembership}()
    return Memberships(var_m, partialsol_m, expression_m, constr_m)
end

hasvar(m::Memberships, uid) = haskey(m.var_to_constr_members, uid)
hasconstr(m::Memberships, uid) = haskey(m.constr_to_var_members, uid)
hasexpression(m::Memberships, uid) = haskey(m.var_to_expression_members, uid)

function get_constr_members_of_var(m::Memberships, uid::VarId) 
    hasvar(m, uid) && return m.var_to_constr_members[uid]
    error("Variable $uid not stored in formulation.")
end

function get_var_members_of_constr(m::Memberships, uid::ConstrId) 
    hasconstr(m, uid) && return m.constr_to_var_members[uid]
    error("Constraint $uid not stored in formulation.")
end

function get_var_members_of_expression(m::Memberships, uid::VarId) 
    hasexpression(m, uid) && return m.var_to_expression_members[uid]
    error("Expression $uid not stored in formulation.")
end

function add_variable!(m::Memberships, var_uid::VarId)
    hasvar(m, var_uid) && error("Variable with uid $var_uid already registered.")
    m.var_to_constr_members[var_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end

function addvarmembership!(m::Memberships, var_uid, new_membership::ConstrMembership)
    existing_membership = get_constr_members_of_var(m, var_uid)
    constr_uids, vals = findnz(new_membership)
    for j in 1:length(constr_uids)
        m.var_to_constr_members[var_uid][constr_uids[j]] = vals[j]
        if hasconstr(m, constr_uids[j]) 
            m.constr_to_var_members[constr_uids[j]][var_uid] = vals[j]
        else
            @warn "Constr with uid $(constr_uids[j]) not registered in Memberships."
        end
    end
    return
end



function add_variable!(m::Memberships, var_uid::VarId, membership::SparseVector)
    hasvar(m, var_uid) && error("Variable with uid $var_uid already registered.")
    m.var_to_constr_members[var_uid] = membership
    constr_uids, vals = findnz(membership)
    for j in 1:length(constr_uids)
        if hasconstr(m, constr_uids[j]) 
            m.constr_to_var_members[constr_uids[j]][var_uid] = vals[j]
        else
            @warn "Constr with uid $(constr_uids[j]) not registered in Memberships."
        end
    end
    return
end

function add_constraint!(m::Memberships, constr_uid::ConstrId)
    hasconstr(m, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    m.constr_to_var_members[constr_uid] = spzeros(Float64, MAX_SV_ENTRIES)
    return
end


function add_constraint!(m::Memberships, constr_uid::ConstrId, membership::SparseVector) 
    hasconstr(m, constr_uid) && error("Constraint with uid $constr_uid already registered.")
    m.constr_to_var_members[constr_uid] = membership
    var_uids, vals = findnz(membership)
    for j in 1:length(var_uids)
        if hasvar(m, var_uids[j])
            m.var_to_constr_members[var_uids[j]][constr_uid] = vals[j]
        else
            @warn "Variable with uid $(var_uids[j]) not registered in Memberships."
        end
    end
    return
end
