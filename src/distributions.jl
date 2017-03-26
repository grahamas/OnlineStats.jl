# For DistributionStat objects
# fit! methods should only update "sufficient statistics"
# value methods should create the distribution

#--------------------------------------------------------------# common
const DistributionStat{I} = OnlineStat{I, DistributionOut}
for f in [:mean, :var, :std, :params, :ncategories, :cov]
    @eval Ds.$f(d::DistributionStat) = $f(value(d))
end
Base.rand(d::DistributionStat, args...) = rand(value(d), args...)


#--------------------------------------------------------------# Beta
struct FitBeta <: DistributionStat{NumberIn}
    var::Variance
    FitBeta() = new(Variance())
end
fit!(o::FitBeta, y::Real, γ::Float64) = fit!(o.var, y, γ)
function value(o::FitBeta, nobs::Integer)
    if nobs > 1
        m = mean(o.var)
        v = var(o.var)
        α = m * (m * (1 - m) / v - 1)
        β = (1 - m) * (m * (1 - m) / v - 1)
        return Ds.Beta(α, β)
    else
        return Ds.Beta()
    end
end


#------------------------------------------------------------------# Categorical
struct FitCategorical{T<:Any} <: DistributionStat{NumberIn}
    d::Dict{T, Int}
    FitCategorical{T}() where T<:Any = new(Dict{T, Int}())
end
function fit!{T}(o::FitCategorical{T}, y::T, γ::Float64)
    haskey(o.d, y) ? (o.d[y] += 1) : (o.d[y] = 1)
end
function value(o::FitCategorical, nobs::Integer)
    nobs > 0 ? Ds.Categorical(collect(values(o.d)) ./ nobs) : Ds.Categorical(1)
end
Base.keys(o::FitCategorical) = keys(o.d)
# function _fit!(o::FitCategorical, y::Union{Real, AbstractString, Symbol}, γ::Float64)
#     if haskey(o.d, y)
#         o.d[y] += 1
#     else
#         o.d[y] = 1
#     end
#     o
# end
# # FitCategorical allows more than just Real input, so it needs special fit! methods
# function fit!(o::FitCategorical, y::Union{AbstractString, Symbol})
#     updatecounter!(o)
#     γ = weight(o)
#     _fit!(o, y, γ)
#     o
# end
# function fit!{T <: Union{AbstractString, Symbol}}(o::FitCategorical, y::AVec{T})
#     for yi in y
#         fit!(o, yi)
#     end
#     o
# end
#
# sortpairs(o::FitCategorical) = sort(collect(o.d), by = x -> 1 / x[2])
# # function Base.sort!(o::FitCategorical)
# #     if nobs(o) > 0
# #         sortedpairs = sortpairs(o)
# #         counts = zeros(length(sortedpairs))
# #         for i in 1:length(sortedpairs)
# #             counts[i] = sortedpairs[i][2]
# #         end
# #         o.value = Ds.Categorical(counts / sum(counts))
# #     end
# # end
# function value(o::FitCategorical)
#     if nobs(o) > 0
#         o.value = Ds.Categorical(collect(values(o.d)) ./ nobs(o))
#     end
# end
# function Base.show(io::IO, o::FitCategorical)
#     header(io, "FitCategorical")
#     print_item(io, "value", value(o))
#     print_item(io, "labels", keys(o.d))
#     print_item(io, "nobs", nobs(o))
# end
# updatecounter!(o::FitCategorical, n2::Int = 1) = (o.nobs += n2)
# weight(o::FitCategorical, n2::Int = 1) = 0.0
# nobs(o::FitCategorical) = o.nobs
#
#
#------------------------------------------------------------------# Cauchy
struct FitCauchy <: DistributionStat{NumberIn}
    q::QuantileMM
end
FitCauchy() = FitCauchy(QuantileMM())
fit!(o::FitCauchy, y::Real, γ::Float64) = fit!(o.q, y, γ)
function value(o::FitCauchy, nobs::Integer)
    if nobs > 1
        return Ds.Cauchy(o.q.value[2], 0.5 * (o.q.value[3] - o.q.value[1]))
    else
        return Ds.Cauchy()
    end
end


#------------------------------------------------------------------------# Gamma
# method of moments, TODO: look at Distributions for MLE
struct FitGamma <: DistributionStat{NumberIn}
    var::Variance
end
FitGamma() = FitGamma(Variance())
fit!(o::FitGamma, y::Real, γ::Float64) = fit!(o.var, y, γ)
nobs(o::FitGamma) = nobs(o.var)
function value(o::FitGamma, nobs::Integer)
    if nobs > 1
        m = mean(o.var)
        v = var(o.var)
        θ = v / m
        α = m / θ
        return Ds.Gamma(α, θ)
    else
        return Ds.Gamma()
    end
end


#-----------------------------------------------------------------------# LogNormal
struct FitLogNormal <: DistributionStat{NumberIn}
    var::Variance
    FitLogNormal() = new(Variance())
end
fit!(o::FitLogNormal, y::Real, γ::Float64) = fit!(o.var, log(y), γ)
function value(o::FitLogNormal, nobs::Integer)
    nobs > 1 ? Ds.LogNormal(mean(o.var), std(o.var)) : Ds.LogNormal()
end


#-----------------------------------------------------------------------# Normal
struct FitNormal <: DistributionStat{NumberIn}
    var::Variance
    FitNormal() = new(Variance())
end
fit!(o::FitNormal, y::Real, γ::Float64) = fit!(o.var, y, γ)
function value(o::FitNormal, nobs::Integer)
    nobs > 1 ? Ds.Normal(mean(o.var), std(o.var)) : Ds.Normal()
end


#-----------------------------------------------------------------------# Multinomial
type FitMultinomial <: DistributionStat{VectorIn}
    mvmean::MV{Mean}
    FitMultinomial(p::Integer) = new(MV(p, Mean()))
end
fit!{T<:Real}(o::FitMultinomial, y::AVec{T}, γ::Float64) = fit!(o.mvmean, y, γ)
function value(o::FitMultinomial, nobs::Integer)
    m = value(o.mvmean)
    p = length(o.mvmean.stats)
    nobs > 0 ? Ds.Multinomial(p, m / sum(m)) : Ds.Multinomial(p, ones(p) / p)
end


# #--------------------------------------------------------------# DirichletMultinomial
# # TODO
# # """
# # Dirichlet-Multinomial estimation using Type 1 Online MM.
# # """
# # type FitDirichletMultinomial{T <: Real} <: DistributionStat{VectorIn}
# #     value::Ds.DirichletMultinomial{T}
# #     suffstats::DirichletMultinomialStats
# #     weight::EqualWeight
# #     function FitDirichletMultinomial(p::Integer, wt::Weight = EqualWeight())
# #         new(Ds.DirichletMultinomial(1, p), EqualWeight())
# #     end
# # end
#
#
#
#
# #---------------------------------------------------------------------# MvNormal
# type FitMvNormal{W<:Weight} <: DistributionStat{VectorIn}
#     value::Ds.MvNormal
#     cov::CovMatrix{W}
# end
# function FitMvNormal(p::Integer, wgt::Weight = EqualWeight())
#     FitMvNormal(Ds.MvNormal(zeros(p), eye(p)), CovMatrix(p, wgt))
# end
# nobs(o::FitMvNormal) = nobs(o.cov)
# Base.std(d::FitMvNormal) = sqrt.(var(d))  # No std() method from Distributions?
# _fit!{T<:Real}(o::FitMvNormal, y::AVec{T}, γ::Float64) = _fit!(o.cov, y, γ)
# function value(o::FitMvNormal)
#     c = cov(o.cov)
#     if isposdef(c)
#         o.value = Ds.MvNormal(mean(o.cov), c)
#     else
#         warn("Covariance not positive definite.  More data needed.")
#     end
# end
# updatecounter!(o::FitMvNormal, n2::Int = 1) = updatecounter!(o.cov, n2)
# weight(o::FitMvNormal, n2::Int = 1) = weight(o.cov, n2)
#
#
#
# #---------------------------------------------------------------------# convenience constructors
# for nm in [:FitBeta, :FitGamma, :FitLogNormal, :FitNormal]
#     eval(parse("""
#         function $nm{T<:Real}(y::AVec{T}, wgt::Weight = EqualWeight())
#             o = $nm(wgt)
#             fit!(o, y)
#             o
#         end
#     """))
# end
#
# function FitCauchy{T<:Real}(y::AVec{T}, wgt::Weight = LearningRate())
#     o = FitCauchy(wgt)
#     fit!(o, y)
#     o
# end
#
# for nm in [:FitMultinomial, :FitMvNormal, :FitDirichletMultinomial]
#     eval(parse("""
#         function $nm{T<:Real}(y::AMat{T}, wgt::Weight = EqualWeight())
#             o = $nm(size(y, 2), wgt)
#             fit!(o, y)
#             o
#         end
#     """))
# end
#
# for nm in[:Beta, :Categorical, :Cauchy, :Gamma, :LogNormal, :Normal, :Multinomial, :MvNormal]
#     eval(parse("""
#         fitdistribution(::Type{Ds.$nm}, args...) = Fit$nm(args...)
#     """))
# end
#
#
#
# #--------------------------------------------------------------# fitdistribution docs
# """
# Estimate the parameters of a distribution.
#
# ```julia
# using Distributions
# # Univariate distributions
# o = fitdistribution(Beta, y)
# o = fitdistribution(Categorical, y)  # ignores Weight
# o = fitdistribution(Cauchy, y)
# o = fitdistribution(Gamma, y)
# o = fitdistribution(LogNormal, y)
# o = fitdistribution(Normal, y)
# mean(o)
# var(o)
# std(o)
# params(o)
#
# # Multivariate distributions
# o = fitdistribution(Multinomial, x)
# o = fitdistribution(MvNormal, x)
# mean(o)
# var(o)
# std(o)
# cov(o)
# ```
# """
# fitdistribution
