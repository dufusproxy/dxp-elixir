# Credo Configuration
# https://hexdocs.pm/credo/config_file.html

%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/", "src/", "web/"],
        excluded: [~r"/_build/", ~r"/deps/", ~r"/node_modules/"]
      },
      strict: true,
      checks: %{
        enabled: [
          # Credo checks - all enabled by default
          {Credo.Check.Design.DuplicatedCode, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.PredicateFunctionNames, []},
          {Credo.Check.Readability.ImplTrue, []},
          {Credo.Check.Readability.MaxLineLength, [max_length: 120]}
        ],
        disabled: []
      }
    }
  ]
}
