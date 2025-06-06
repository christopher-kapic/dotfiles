require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("i", "kj", "<ESC>")

-- map()
map({"n", "i", "v", "t"}, "<C-\\>", function()
  require("nvchad.term").toggle {pos = "float", id="floatTerm", float_opts={
    row = 0.05,
    col = 0.05,
    width = 0.9,
    height = 0.8

  }}
end, { desc = "terminal toggle floating term"}
)

-- map({"n", "i", "v", "t"}, "<C-h>", function()
--   require("nvchad.term").toggle {pos = "hsp", id="horizTerm", size=0.4}
-- end, { desc = "terminal toggle floating term"}
-- )

map({"n"}, "<leader>bb", function()
  require("nvchad.tabufline").prev()
end, { desc = "buffer goto previous"}
)

map({"n"}, "<leader>bn", function()
  require("nvchad.tabufline").next()
end, { desc = "buffer goto next"}
)

map("n", "<leader>e", "<cmd>NvimTreeToggle<CR>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
