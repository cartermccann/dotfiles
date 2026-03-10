-- AI integration via Ollama
return {
  {
    "David-Kunz/gen.nvim",
    opts = {
      model = "llama3.2:3b",
      host = "localhost",
      port = "11434",
      display_mode = "split",
      show_prompt = true,
      show_model = true,
    },
    keys = {
      { "<leader>ag", ":Gen<CR>", mode = { "n", "v" }, desc = "Gen AI menu" },
      { "<leader>ac", ":Gen Chat<CR>", mode = { "n", "v" }, desc = "AI Chat" },
      { "<leader>ae", ":Gen Enhance_Code<CR>", mode = "v", desc = "AI Enhance code" },
      { "<leader>ar", ":Gen Review_Code<CR>", mode = "v", desc = "AI Review code" },
      { "<leader>ax", ":Gen Explain_Code<CR>", mode = "v", desc = "AI Explain code" },
    },
  },
}
