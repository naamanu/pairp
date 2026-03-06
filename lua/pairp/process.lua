local M = {}

function M.exec(cli_path, prompt, callbacks)
	local stdout = vim.uv.new_pipe()

	local handle
	handle = vim.uv.spawn(cli_path, {
		args = { "--print", prompt },
		stdio = { nil, stdout, nil },
	}, function(code)
		stdout:close()
		handle:close()
		if callbacks.on_exit then
			callbacks.on_exit(code)
		end
	end)

	if not handle then
		vim.schedule(function()
			vim.notify("Pairp: failed to start '" .. cli_path .. "'", vim.log.levels.ERROR)
		end)
		stdout:close()
		return
	end

	stdout:read_start(function(err, data)
		if err then
			return
		end
		if data and callbacks.on_stdout then
			callbacks.on_stdout(data)
		end
	end)
end

return M
