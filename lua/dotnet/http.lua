local M = {}

local Job = require "plenary.job"

function M.fetch_service_index(callback)
    local url = "https://api.nuget.org/v3/index.json"
    Job:new({
        command = "curl",
        args = { "-s", url },
        on_exit = function(job, code)
            local result = job:result()
            vim.schedule(function()
                if code == 0 then
                    local data = vim.fn.json_decode(result)
                    callback(data)
                else
                    callback(nil, "Failed to fetch service index")
                end
            end)
        end,
    }):start()
end

function M.test()
    M.fetch_service_index(function(data, err)
        if err then
            print("Error: " .. err)
        else
            print("Service Index: " .. vim.inspect(data))
        end
    end)
end

return M
