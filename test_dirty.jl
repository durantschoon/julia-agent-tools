struct UntypedContainer
    data
    value
end

struct BadContainer
    data::AbstractArray
    value::Number
    valid::Float64
end
