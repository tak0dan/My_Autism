{
  inputs,
  config,
  ...
}: {
  imports = [inputs.nvf.homeManagerModules.default];

  programs.nvf = {
    enable = true;

    settings.vim = {
      vimAlias = true;
      viAlias = true;
      withNodeJs = true;
      lineNumberMode = "number";
      enableLuaLoader = true;
      preventJunkFiles = true;
      options = {
        tabstop = 4;
        shiftwidth = 2;
        wrap = false;
      };

      clipboard = {
        enable = true;
        registers = "unnamedplus";
        providers = {
          wl-copy = {
            enable = true;
          };
          xsel = {
            enable = true;
          };
        };
      };

      maps = {
        normal = {
          "<leader>e" = {
            action = "<CMD>Neotree toggle<CR>";
            silent = false;
          };
        };
      };

      diagnostics = {
        enable = true;
        config = {
          virtual_lines = {
            enable = true;
          };
          underline = true;
        };
      };

      keymaps = [
        {
          key = "jk";
          mode = ["i"];
          action = "<ESC>";
          desc = "Exit insert mode";
        }
        {
          key = "<leader>nh";
          mode = ["n"];
          action = ":nohl<CR>";
          desc = "Clear search highlights";
        }
        {
          key = "<leader>ff";
          mode = ["n"];
          action = "<cmd>Telescope find_files<cr>";
          desc = "Search files by name";
        }
        {
          key = "<leader>lg";
          mode = ["n"];
          action = "<cmd>Telescope live_grep<cr>";
          desc = "Search files by contents";
        }
        {
          key = "<leader>fe";
          mode = ["n"];
          action = "<cmd>Neotree toggle<cr>";
          desc = "File browser toggle";
        }
        {
          key = "<C-h>";
          mode = ["i"];
          action = "<Left>";
          desc = "Move left in insert mode";
        }
        {
          key = "<C-j>";
          mode = ["i"];
          action = "<Down>";
          desc = "Move down in insert mode";
        }
        {
          key = "<C-k>";
          mode = ["i"];
          action = "<Up>";
          desc = "Move up in insert mode";
        }
        {
          key = "<C-l>";
          mode = ["i"];
          action = "<Right>";
          desc = "Move right in insert mode";
        }
        {
          key = "<leader>dj";
          mode = ["n"];
          action = "<cmd>Lspsaga diagnostic_jump_next<CR>";
          desc = "Go to next diagnostic";
        }
        {
          key = "<leader>dk";
          mode = ["n"];
          action = "<cmd>Lspsaga diagnostic_jump_prev<CR>";
          desc = "Go to previous diagnostic";
        }
        {
          key = "<leader>dl";
          mode = ["n"];
          action = "<cmd>Lspsaga show_line_diagnostics<CR>";
          desc = "Show diagnostic details";
        }
        {
          key = "<leader>dt";
          mode = ["n"];
          action = "<cmd>Trouble diagnostics toggle<cr>";
          desc = "Toggle diagnostics list";
        }
        {
          key = "<leader>t";
          mode = ["n"];
          action = "<cmd>ToggleTerm<CR>";
          desc = "Toggle terminal";
        }
        {
          key = "<leader>mp";
          mode = ["n"];
          action = ":MarkdownPreview<CR>";
          desc = "Toggle Markdown Preview";
        }
      ];

      telescope = {
        enable = true;
      };

      spellcheck = {
        enable = true;
        languages = ["en"];
        programmingWordlist = {
          enable = true;
        };
      };

      lsp = {
        enable = true;
        formatOnSave = true;
        lspkind = {
          enable = false;
        };
        lightbulb = {
          enable = false; #even with this disabled enabling lspaga sets lightbulb on
        };
        lspsaga = {
          enable = false; #when enabled getting annoying lightbulb
        };
        trouble = {
          enable = true;
        };
        lspSignature = {
          enable = false;
        };
        otter-nvim = {
          enable = false;
        };
        nvim-docs-view = {
          enable = false;
        };
      };

      languages = {
        enableFormat = true;
        enableTreesitter = true;
        enableExtraDiagnostics = true;
        nix = {
          enable = true;
          lsp = {
            server = "nil";
          };
        };
        clang = {
          enable = true;
        };
        zig = {
          enable = true;
        };
        python = {
          enable = true;
        };
        markdown = {
          enable = true;
        };
        ts = {
          enable = true;
          lsp = {
            enable = true;
          };
          format.type = "prettierd";
          extensions.ts-error-translator = {
            enable = true;
          };
        };
        html = {
          enable = true;
        };
        lua = {
          enable = true;
        };
        css = {
          enable = true;
          format.type = "prettierd";
        };
        typst = {
          enable = true;
        };
        rust = {
          enable = true;
          crates = {
            enable = true;
          };
        };
      };

      visuals = {
        nvim-web-devicons = {
          enable = true;
        };
        nvim-cursorline = {
          enable = true;
        };
        cinnamon-nvim = {
          enable = true;
        };
        fidget-nvim = {
          enable = true;
        };
        highlight-undo = {
          enable = true;
        };
        indent-blankline = {
          enable = true;
        };
        rainbow-delimiters = {
          enable = true;
        };
      };
      statusline.lualine = {
        enable = true;
        theme = "base16";
      };

      autopairs = {
        nvim-autopairs = {
          enable = true;
        };
      };

      autocomplete = {
        nvim-cmp = {
          enable = false;
        };
        blink-cmp = {
          enable = true;
          friendly-snippets.enable = true;
          setupOpts = {
            completion.documentation.auto_show_delay_ms = 50;
          };
        };
      };

      snippets = {
        luasnip = {
          enable = true;
        };
      };

      tabline = {
        nvimBufferline = {
          enable = true;
        };
      };

      treesitter = {
        context = {
          enable = false;
        };
      };

      binds = {
        whichKey = {
          enable = true;
        };
        cheatsheet = {
          enable = true;
        };
      };

      git = {
        enable = true;
        gitsigns = {
          enable = true;
          codeActions = {
            enable = false;
          };
        };
      };

      projects = {
        project-nvim = {
          enable = true;
        };
      };

      dashboard = {
        dashboard-nvim = {
          enable = true;
        };
        alpha = {
          enable = false;
        };
      };

      filetree = {
        neo-tree = {
          enable = true;
        };
      };

      notify = {
        nvim-notify = {
          enable = true;
          setupOpts.background_colour = "#${config.lib.stylix.colors.base01}";
        };
      };

      utility = {
        preview.markdownPreview = {
          enable = true;
        };
        ccc = {
          enable = false;
        };
        vim-wakatime = {
          enable = false;
        };
        icon-picker = {
          enable = true;
        };
        surround = {
          enable = true;
        };
        diffview-nvim = {
          enable = true;
        };
        motion = {
          hop = {
            enable = true;
          };
          leap = {
            enable = true;
          };
          precognition = {
            enable = false;
          };
        };
        images = {
          image-nvim = {
            enable = false;
          };
        };
      };

      ui = {
        borders = {
          enable = true;
        };
        noice = {
          enable = true;
        };
        colorizer = {
          enable = true;
        };
        illuminate = {
          enable = true;
        };
        breadcrumbs = {
          enable = false;
          navbuddy = {
            enable = false;
          };
        };
        smartcolumn = {
          enable = true;
        };
        fastaction = {
          enable = true;
        };
      };

      terminal = {
        toggleterm = {
          enable = true;
          lazygit = {
            enable = true;
          };
        };
      };

      session = {
        nvim-session-manager = {
          enable = false;
        };
      };
      comments = {
        comment-nvim.enable = true;
      };
    };
  };

  home.activation = {
    dirtytalkUpdate = config.lib.dag.entryAfter ["writeBoundary"] ''
      # Check if programmingWordlist file already exists to avoid unnecessary downloads
      WORDLIST_FILE="$HOME/.config/nvim/spell/programming.utf-8.add"
      if [ ! -f "$WORDLIST_FILE" ]; then
        echo "Programming wordlist not found, downloading via DirtytalkUpdate..."
        if ${config.programs.nvf.finalPackage}/bin/nvim -c "DirtytalkUpdate" -c "qa!" 2>/dev/null; then
          echo "DirtytalkUpdate completed successfully"
        else
          echo "DirtytalkUpdate failed, but continuing..." >&2
        fi
      else
        echo "Programming wordlist already exists at $WORDLIST_FILE, skipping download"
      fi
    '';
  };
}

