#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
OPTIONS_FILE="${ROOT_DIR}/ctags.d/julia.ctags"
SAMPLE_FILE="${ROOT_DIR}/test/fixtures/sample.jl"

mkdir -p "${ROOT_DIR}/test/fixtures"

cat << 'EOF' > "${SAMPLE_FILE}"
module SampleModule

export AbstractShape, Circle, MutablePoint, Color, Point3D, area, move!

abstract type AbstractShape{T <: Real} end

struct Circle{T <: Real} <: AbstractShape{T}
    radius::T
end

mutable struct MutablePoint{T <: Real}
    x::T
    y::T
end

@enum Color RED GREEN BLUE

const Point3D = MutablePoint{Float64}
const MAX_RADIUS = 1000.0

@inline area(c::Circle{T}) where {T} = T(pi) * c.radius^2

function move!(p::MutablePoint{T}, dx::T, dy::T) where {T}
    p.x += dx
    p.y += dy
    return p
end

macro log_call(ex)
    quote
        println("Calling expression")
        $(esc(ex))
    end
end

end # module SampleModule
EOF

echo "Running Universal Ctags on ${SAMPLE_FILE}..."
OUTPUT=$(ctags --options="${OPTIONS_FILE}" -f - --fields=+K+n+S "${SAMPLE_FILE}")

echo "${OUTPUT}"

# Assertions
echo "Verifying tags..."
echo "${OUTPUT}" | grep -E "AbstractShape.*abstract" > /dev/null || (echo "FAILED: AbstractShape abstract tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "Circle.*struct" > /dev/null || (echo "FAILED: Circle struct tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "MutablePoint.*mutablestruct" > /dev/null || (echo "FAILED: MutablePoint mutablestruct tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "Color.*enum" > /dev/null || (echo "FAILED: Color enum tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "Point3D.*typealias" > /dev/null || (echo "FAILED: Point3D typealias tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "area.*function" > /dev/null || (echo "FAILED: area function tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "move!.*function" > /dev/null || (echo "FAILED: move! function tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "log_call.*macro" > /dev/null || (echo "FAILED: log_call macro tag missing" && exit 1)
echo "${OUTPUT}" | grep -E "SampleModule.*module" > /dev/null || (echo "FAILED: SampleModule module tag missing" && exit 1)

echo "All Universal Ctags tests passed successfully!"
