local M = {}

--- Creates smart readonly ouptput options for the dotnet CLI.
function M.smart_output_opts(bufnr, win)
    local opts = {}

    local spaces = 0 -- Count spaces and collapse consecutive empty lines
    local on_output = function(_, data, _)
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end

        if data and #data > 0 then
            -- Create a smart split of the output data
            local width = vim.api.nvim_win_get_width(win)

            -- Smartly split the output lines based on the width
            local splits = {}
            for _, line in ipairs(data) do
                local split_lines = require "dotnet.utils".split_smart(line, width, 2, 1, 2)
                for _, split_line in ipairs(split_lines) do
                    local is_space = not split_line or split_line:match("^%s*$")
                    if is_space then
                        spaces = spaces + 1
                        if spaces % 2 == 1 then
                            table.insert(splits, "")
                        end
                    else
                        spaces = 0
                        table.insert(splits, split_line)
                    end
                end
            end

            -- Ensure the buffer is modifiable before writing to it
            vim.api.nvim_buf_set_option(bufnr, "modifiable", true)

            -- Get the last line of the buffer to append after
            local last_line = vim.api.nvim_buf_line_count(bufnr)

            --- Append new lines to the buffer
            vim.api.nvim_buf_set_lines(bufnr, last_line, -1, false, splits)

            -- Set cursor to the end of the buffer
            last_line = vim.api.nvim_buf_line_count(bufnr)
            vim.api.nvim_win_set_cursor(win, { last_line, 0 })
        end
    end

    opts.stdout = on_output
    opts.stderr = on_output

    opts.on_start = function()
        if not vim.api.nvim_buf_is_valid(bufnr) then
            return
        end

        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {})
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    end

    opts.on_exit = function()
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    end

    return opts
end

return M
