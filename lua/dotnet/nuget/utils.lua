local M = {}

-- parses a csproj file and returns the nuget projects and their versions
function M.get_nuget_pkgs(file)
    local f = io.open(file, "r")
    if not f then
        return nil
    end

    local content = f:read("*a")
    f:close()

    local packages = {}
    for line in content:gmatch("[^\r\n]+") do
        local id = line:match('<PackageReference Include="([^"]+)"')
        local version = line:match('Version="([^"]+)"')
        if id and version then
            table.insert(packages, { id = id, version = version })
        end
    end

    return packages
end

return M
