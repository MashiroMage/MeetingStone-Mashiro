
BuildEnv(...)


ProtoBase = Addon:NewClass('ProtoBase')




function ProtoBase:ApplyProto(proto, data, offset)
    offset = offset or 0

    for i, k in ipairs(proto) do
        if not k:find('^_') then
            self[k] = data[offset + i]
        end
    end
end
