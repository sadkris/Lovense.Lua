local KrissyUtil = {}

function KrissyUtil:sleep(a)
    local sec = tonumber(os.clock() + a);
    while (os.clock() < sec) do
    end
end
function KrissyUtil:startsWith(str, start)
    return string.sub(str, 1, string.len(start)) == start
end

return KrissyUtil