local ffi = require("ffi")
local entity = require("sia.entity")

local concat = table.concat

local entity_command = entity.command

local ffic = {}

---@param ctype string
---@param commands table<string, function>
---@return ffi.ctype*
ffic.struct = function(ctype, commands)
    local mt = {}

    ---@diagnostic disable-next-line: param-type-mismatch
    local comp_type = ffi.metatype("struct "..ctype, mt)

    local index = {
        __sia_component_meta = {
            key = comp_type,
            ffi_ctype = ctype
        }
    }
    mt.__index = index

    if commands ~= nil then
        for command_name, handler in pairs(commands) do
            ---@diagnostic disable-next-line: assign-type-mismatch
            index[command_name] = entity_command(comp_type, handler)
        end
    end

    return comp_type
end

local polymer_count = 0

---@param ctype string
---@param subcomp_ctypes string[]
local function generate_polymer_struct_def(ctype, subcomp_ctypes)
    local t = {"typedef struct ", ctype, "{"}

    for i = 1, #subcomp_ctypes do
        local subcomp_ctype = subcomp_ctypes[i]
        t[#t+1] = "struct "
        t[#t+1] = subcomp_ctype
        t[#t+1] = " "
        t[#t+1] = subcomp_ctype
        t[#t+1] = ";"
    end

    t[#t+1] = "} "
    t[#t+1] = ctype
    t[#t+1] = ";"
    return concat(t)
end

local function iter_polymer_subcomps(state, key)
    local i = state[1]
    local subcomp_ctypes = state[2]
    if i >= #subcomp_ctypes then
        return nil
    end

    i = i + 1
    state[1] = i

    local subcomp_types = state[3]
    local polymer = state[4]
    return subcomp_types[i], polymer[subcomp_ctypes[i]]
end

---@param ... ffi.ctype*
---@return ffi.ctype*
ffic.polymer = function(...)
    local subcomp_types = {...}
    if #subcomp_types == nil then
        error("subcomp_types table cannot be empty")
    end

    local subcomp_ctypes = {}
    for i = 1, #subcomp_types do
        ---@diagnostic disable-next-line: undefined-field
        subcomp_ctypes[i] = subcomp_types[i].__sia_component_meta.ffi_ctype
    end

    polymer_count = polymer_count + 1
    local ctype = "__sia_polymer_"..polymer_count
    ffi.cdef(generate_polymer_struct_def(ctype, subcomp_ctypes))

    local mt = {}
    ---@diagnostic disable-next-line: param-type-mismatch
    local comp_type = ffi.metatype(ctype, mt)

    mt.__index = {
        __sia_component_meta = {
            key = comp_type,
            iter_subcomponents = function(comp)
                return iter_polymer_subcomps, {0, subcomp_ctypes, subcomp_types, comp}, nil
            end
        }
    }

    return comp_type
end

return ffic