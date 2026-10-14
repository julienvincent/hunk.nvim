local fs = require("hunk.api.fs")

describe("diff view: jj integration", function()
  if vim.fn.executable("jj") ~= 1 then
    pending("requires jj on PATH", function() end)
    return
  end

  local root = vim.fn.getcwd()
  local workspace
  local env
  local tool_config = assert(fs.read_file(root .. "/README.md"):match("```toml\n(%[merge%-tools%.hunk%].-)\n```"))

  local function write_config(interactive)
    local args = "-u " .. vim.fn.shellescape(root .. "/tests/utils/diff_view_jj.lua") .. " -i NONE "
    if not interactive then
      args = "--headless " .. args
    end
    local launcher = tool_config:gsub("%[merge%-tools%.hunk%]", "[merge-tools.hunk-test]"):gsub("exec nvim ", function()
      return "exec nvim " .. args
    end)
    if not interactive then
      launcher = launcher:gsub(" </dev/tty >/dev/tty", "")
    end
    fs.write_file(env.JJ_CONFIG, {
      "[user]",
      'name = "Diff view test"',
      'email = "diff-view@example.com"',
      "[signing]",
      'behavior = "drop"',
      launcher,
    })
  end

  local function jj(args, extra_env)
    local command = { "jj", "--no-pager", "--color=never" }
    vim.list_extend(command, args)
    local result = vim
      .system(command, {
        cwd = workspace.repo,
        env = vim.tbl_extend("force", env, extra_env or {}),
        text = true,
      })
      :wait(15000)
    assert.are.equal(0, result.code, result.stderr)
    return result
  end

  local function write(lines)
    fs.write_file(workspace.repo .. "/file", lines)
  end

  local function view(args, expected)
    local extra_env = { HUNK_TEST_MANIFEST = workspace.root .. "/manifest" }
    for key, value in pairs(expected) do
      extra_env[key] = type(value) == "table" and vim.json.encode(value) or value
    end
    local result = jj(vim.list_extend(vim.deepcopy(args), { "--tool", "hunk-test" }), extra_env)
    assert.is_nil(result.stderr:match("Tool exited"), result.stderr)
    assert.is_nil(result.stderr:match("Error"), result.stderr)
    local dirs = vim.fn.readfile(extra_env.HUNK_TEST_MANIFEST)
    assert.are.equal(2, #dirs)
    assert.are.equal(0, vim.fn.isdirectory(dirs[1]))
    assert.are.equal(0, vim.fn.isdirectory(dirs[2]))
  end

  before_each(function()
    local temp = vim.fn.tempname() .. " jj diff view"
    workspace = { root = temp, repo = temp .. "/repo" }
    vim.fn.mkdir(workspace.repo, "p")
    env = {
      JJ_CONFIG = temp .. "/config.toml",
      HUNK_TEST_ROOT = root,
      HUNK_TEST_CWD = temp,
      HUNK_EXPECT_LEFT = "",
      HUNK_EXPECT_RIGHT = "",
      HUNK_CONFLICT_SIDE = "",
      PATH = vim.fs.dirname(vim.v.progpath) .. ":" .. vim.env.PATH,
    }
    write_config(false)
    jj({ "git", "init", "--no-colocate" })
  end)

  after_each(function()
    vim.fn.delete(workspace.root, "rf")
  end)

  it("views an ordinary jj diff and exits successfully", function()
    write({ "old" })
    jj({ "new" })
    write({ "new" })
    view({ "diff", "-r", "@" }, { HUNK_EXPECT_LEFT = { "old" }, HUNK_EXPECT_RIGHT = { "new" } })
    assert.are.equal("new\n", fs.read_file(workspace.repo .. "/file"))
  end)

  if vim.fn.has("unix") == 1 then
    it("launches interactive Neovim directly through the terminal shell wrapper", function()
      write({ "old" })
      jj({ "new" })
      write({ "new" })
      write_config(true)
      local output = {}
      local manifest = workspace.root .. "/terminal-manifest"
      local job = vim.fn.jobstart({
        "jj",
        "--no-pager",
        "--color=never",
        "diff",
        "-r",
        "@",
        "--tool",
        "hunk-test",
      }, {
        cwd = workspace.repo,
        env = vim.tbl_extend("force", env, {
          HUNK_TEST_MANIFEST = manifest,
          HUNK_EXPECT_LEFT = vim.json.encode({ "old" }),
          HUNK_EXPECT_RIGHT = vim.json.encode({ "new" }),
        }),
        pty = true,
        on_stdout = function(_, data)
          vim.list_extend(output, data)
        end,
      })
      assert.is_true(job > 0)
      local result = vim.fn.jobwait({ job }, 15000)[1]
      if result == -1 then
        vim.fn.jobstop(job)
      end
      local text = table.concat(output, "\n")
      assert.are.equal(0, result, text)
      assert.is_nil(text:match("Tool exited"), text)
      assert.are.equal(1, vim.fn.filereadable(manifest), text)
      for _, dir in ipairs(vim.fn.readfile(manifest)) do
        assert.are.equal(0, vim.fn.isdirectory(dir))
      end
    end)
  end

  it("preserves literal paths containing spaces and filename metacharacters", function()
    write({ "old" })
    jj({ "new" })
    write({ "new" })
    local tmpdir = workspace.root .. "/tmp #%'\"\\ café"
    vim.fn.mkdir(tmpdir, "p")
    env.TMPDIR = tmpdir
    view({ "diff", "-r", "@" }, { HUNK_EXPECT_LEFT = { "old" }, HUNK_EXPECT_RIGHT = { "new" } })
  end)

  it("views a conflicted revision compared with a clean revision", function()
    write({ "base" })
    jj({ "new" })
    write({ "first" })
    jj({ "bookmark", "create", "first" })
    jj({ "new", "@-" })
    write({ "second" })
    jj({ "bookmark", "create", "second" })
    jj({ "new", "first", "second" })
    view({ "diff", "--from", "first", "--to", "@" }, {
      HUNK_EXPECT_LEFT = { "first" },
      HUNK_CONFLICT_SIDE = "RIGHT",
    })
  end)

  it("views an interdiff's computed conflict even when both revisions are clean", function()
    write({ "foo" })
    jj({ "new" })
    write({ "bar" })
    jj({ "bookmark", "create", "left" })
    jj({ "new", "root()" })
    write({ "abc" })
    jj({ "new" })
    write({ "def" })
    jj({ "bookmark", "create", "right" })
    local conflicts = jj({ "log", "-r", "left|right", "--no-graph", "-T", "conflict" })
    assert.are.equal("falsefalse", conflicts.stdout)
    view({ "interdiff", "--from", "left", "--to", "right" }, {
      HUNK_EXPECT_RIGHT = { "def" },
      HUNK_CONFLICT_SIDE = "LEFT",
    })
  end)
end)
