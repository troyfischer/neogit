local M = {}

local util = require("neogit.lib.util")
local git = require("neogit.lib.git")
local client = require("neogit.client")
local notif = require("neogit.lib.notification")
local CommitSelectViewBuffer = require("neogit.buffers.commit_select_view")

---@param popup any
---@return CommitLogEntry[]
local function get_commits(popup)
  local commits
  if #popup.state.env.commits > 0 then
    vim.notify("Reverting single commit")
    commits = util.reverse(popup.state.env.commits)
    commits = vim.tbl_map(function(v)
      return v.oid
    end, commits)
  else
    print("Selecting commits")
    commits = CommitSelectViewBuffer.new(git.log.list { "--max-count=256" }):open_async()
  end

  return commits or {}
end

local function build_commit_message(commits)
  local message = {}
  table.insert(message, string.format("Revert %d commits\n", #commits))

  for _, commit in ipairs(commits) do
    table.insert(message, string.format("%s '%s'", commit:sub(1, 7), git.log.message(commit)))
  end

  return table.concat(message, "\n") .. "\04"
end

function M.commits(popup)
  local commits = get_commits(popup)
  if #commits == 0 then
    return
  end

  local args = popup:get_arguments()

  vim.notify("Reverting commits" .. vim.inspect(commits))
  local success = git.revert.commits(commits, args)

  if not success then
    notif.create("Revert failed. Resolve conflicts before continuing", vim.log.levels.ERROR)
    return
  end

  local commit_cmd = git.cli.commit.no_verify.with_message(build_commit_message(commits))
  if vim.tbl_contains(args, "--edit") then
    commit_cmd = commit_cmd.edit
  else
    commit_cmd = commit_cmd.no_edit
  end

  client.wrap(commit_cmd, {
    autocmd = "NeogitRevertComplete",
    refresh = "do_revert",
    msg = {
      setup = "Reverting...",
      success = "Reverted!",
      fail = "Couldn't revert",
    },
  })
end

function M.changes(popup)
  local commits = get_commits(popup)
  if not commits[1] then
    return
  end

  git.revert.commits(commits, popup:get_arguments())
end

function M.continue()
  git.revert.continue()
end

function M.skip()
  git.revert.skip()
end

function M.abort()
  git.revert.abort()
end

return M
