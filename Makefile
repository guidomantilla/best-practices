REPO_URL := https://raw.githubusercontent.com/guidomantilla/best-practices/main
SKILLS_DIR := .skills
COMMANDS_DIR := .claude-commands

.PHONY: help install-claude install-copilot install-cursor uninstall-claude uninstall-copilot uninstall-cursor uninstall-all list

help: ## Show available commands
	@echo "Best Practices — Skill Installer"
	@echo ""
	@echo "Usage: make <command> TARGET=<path-to-your-repo>"
	@echo ""
	@echo "Commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-20s %s\n", $$1, $$2}'
	@echo ""
	@echo "Examples:"
	@echo "  make install-claude TARGET=~/projects/my-app"
	@echo "  make install-copilot TARGET=~/projects/my-app"
	@echo "  make install-cursor TARGET=~/projects/my-app"
	@echo "  make install-claude TARGET=~/projects/my-app SKILLS='assess-secure-coding assess-testing'"
	@echo "  make uninstall-claude TARGET=~/projects/my-app"
	@echo "  make uninstall-all TARGET=~/projects/my-app"

list: ## List available skills
	@echo "Available skills:"
	@for dir in $(SKILLS_DIR)/*/; do echo "  $$(basename $$dir)"; done

install-claude: ## Install skills for Claude Code (TARGET=<repo-path> [SKILLS='skill1 skill2'])
	@if [ -z "$(TARGET)" ]; then echo "Error: TARGET is required. Usage: make install-claude TARGET=~/projects/my-app"; exit 1; fi
	@mkdir -p "$(TARGET)/.claude/skills"
	@if [ -z "$(SKILLS)" ]; then \
		echo "Installing all skills to $(TARGET)/.claude/skills/"; \
		for dir in $(SKILLS_DIR)/*/; do \
			skill=$$(basename $$dir); \
			mkdir -p "$(TARGET)/.claude/skills/$$skill"; \
			cp "$$dir/SKILL.md" "$(TARGET)/.claude/skills/$$skill/SKILL.md"; \
			echo "  ✓ $$skill"; \
		done; \
	else \
		echo "Installing selected skills to $(TARGET)/.claude/skills/"; \
		for skill in $(SKILLS); do \
			if [ -d "$(SKILLS_DIR)/$$skill" ]; then \
				mkdir -p "$(TARGET)/.claude/skills/$$skill"; \
				cp "$(SKILLS_DIR)/$$skill/SKILL.md" "$(TARGET)/.claude/skills/$$skill/SKILL.md"; \
				echo "  ✓ $$skill"; \
			else \
				echo "  ✗ $$skill (not found)"; \
			fi; \
		done; \
	fi
	@if [ -d "$(COMMANDS_DIR)" ]; then \
		mkdir -p "$(TARGET)/.claude/commands"; \
		for f in $(COMMANDS_DIR)/*.md; do \
			[ -e "$$f" ] || continue; \
			cmd=$$(basename "$$f"); \
			cp "$$f" "$(TARGET)/.claude/commands/$$cmd"; \
			echo "  ✓ /$${cmd%.md} (slash command)"; \
		done; \
	fi
	@echo ""
	@echo "Done. Skills installed to $(TARGET)/.claude/skills/"
	@echo "Slash commands installed to $(TARGET)/.claude/commands/"
	@echo "Skills reference content from: $(REPO_URL)/"

install-copilot: ## Install skills for GitHub Copilot (TARGET=<repo-path> [SKILLS='skill1 skill2'])
	@if [ -z "$(TARGET)" ]; then echo "Error: TARGET is required. Usage: make install-copilot TARGET=~/projects/my-app"; exit 1; fi
	@mkdir -p "$(TARGET)/.github"
	@echo "Generating $(TARGET)/.github/copilot-instructions.md"
	@echo "# Best Practices — Code Review Instructions" > "$(TARGET)/.github/copilot-instructions.md"
	@echo "" >> "$(TARGET)/.github/copilot-instructions.md"
	@echo "Auto-generated from [guidomantilla/best-practices](https://github.com/guidomantilla/best-practices)." >> "$(TARGET)/.github/copilot-instructions.md"
	@echo "Reference content at: $(REPO_URL)/" >> "$(TARGET)/.github/copilot-instructions.md"
	@echo "" >> "$(TARGET)/.github/copilot-instructions.md"
	@echo "---" >> "$(TARGET)/.github/copilot-instructions.md"
	@echo "" >> "$(TARGET)/.github/copilot-instructions.md"
	@if [ -z "$(SKILLS)" ]; then \
		for dir in $(SKILLS_DIR)/*/; do \
			skill=$$(basename $$dir); \
			echo "" >> "$(TARGET)/.github/copilot-instructions.md"; \
			awk 'BEGIN{fm=0} /^---$$/{fm++; next} fm>=2{print}' "$$dir/SKILL.md" >> "$(TARGET)/.github/copilot-instructions.md"; \
			echo "" >> "$(TARGET)/.github/copilot-instructions.md"; \
			echo "---" >> "$(TARGET)/.github/copilot-instructions.md"; \
			echo "  ✓ $$skill"; \
		done; \
	else \
		for skill in $(SKILLS); do \
			if [ -d "$(SKILLS_DIR)/$$skill" ]; then \
				echo "" >> "$(TARGET)/.github/copilot-instructions.md"; \
				awk 'BEGIN{fm=0} /^---$$/{fm++; next} fm>=2{print}' "$(SKILLS_DIR)/$$skill/SKILL.md" >> "$(TARGET)/.github/copilot-instructions.md"; \
				echo "" >> "$(TARGET)/.github/copilot-instructions.md"; \
				echo "---" >> "$(TARGET)/.github/copilot-instructions.md"; \
				echo "  ✓ $$skill"; \
			else \
				echo "  ✗ $$skill (not found)"; \
			fi; \
		done; \
	fi
	@echo ""
	@echo "Done. Generated $(TARGET)/.github/copilot-instructions.md"

install-cursor: ## Install skills for Cursor (TARGET=<repo-path> [SKILLS='skill1 skill2'])
	@if [ -z "$(TARGET)" ]; then echo "Error: TARGET is required. Usage: make install-cursor TARGET=~/projects/my-app"; exit 1; fi
	@mkdir -p "$(TARGET)/.cursor/rules"
	@if [ -z "$(SKILLS)" ]; then \
		echo "Installing all skills to $(TARGET)/.cursor/rules/"; \
		for dir in $(SKILLS_DIR)/*/; do \
			skill=$$(basename $$dir); \
			desc=$$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$$dir/SKILL.md"); \
			{ echo "---"; echo "description: $$desc"; echo "globs: \"**/*\""; echo "alwaysApply: false"; echo "---"; awk 'BEGIN{fm=0} /^---$$/{fm++; next} fm>=2{print}' "$$dir/SKILL.md"; } > "$(TARGET)/.cursor/rules/$$skill.mdc"; \
			echo "  ✓ $$skill"; \
		done; \
	else \
		echo "Installing selected skills to $(TARGET)/.cursor/rules/"; \
		for skill in $(SKILLS); do \
			if [ -d "$(SKILLS_DIR)/$$skill" ]; then \
				desc=$$(awk '/^description:/{sub(/^description:[[:space:]]*/,""); print; exit}' "$(SKILLS_DIR)/$$skill/SKILL.md"); \
				{ echo "---"; echo "description: $$desc"; echo "globs: \"**/*\""; echo "alwaysApply: false"; echo "---"; awk 'BEGIN{fm=0} /^---$$/{fm++; next} fm>=2{print}' "$(SKILLS_DIR)/$$skill/SKILL.md"; } > "$(TARGET)/.cursor/rules/$$skill.mdc"; \
				echo "  ✓ $$skill"; \
			else \
				echo "  ✗ $$skill (not found)"; \
			fi; \
		done; \
	fi
	@echo ""
	@echo "Done. Skills installed to $(TARGET)/.cursor/rules/"
	@echo "Skills reference content from: $(REPO_URL)/"

uninstall-claude: ## Uninstall skills from Claude Code (TARGET=<repo-path> [SKILLS='skill1 skill2'])
	@if [ -z "$(TARGET)" ]; then echo "Error: TARGET is required. Usage: make uninstall-claude TARGET=~/projects/my-app"; exit 1; fi
	@if [ -z "$(SKILLS)" ]; then \
		echo "Removing all repo skills from $(TARGET)/.claude/skills/"; \
		for dir in $(SKILLS_DIR)/*/; do \
			skill=$$(basename $$dir); \
			if [ -d "$(TARGET)/.claude/skills/$$skill" ]; then \
				rm -rf "$(TARGET)/.claude/skills/$$skill"; \
				echo "  ✓ removed $$skill"; \
			fi; \
		done; \
		if [ -d "$(COMMANDS_DIR)" ]; then \
			for f in $(COMMANDS_DIR)/*.md; do \
				[ -e "$$f" ] || continue; \
				cmd=$$(basename "$$f"); \
				if [ -f "$(TARGET)/.claude/commands/$$cmd" ]; then \
					rm -f "$(TARGET)/.claude/commands/$$cmd"; \
					echo "  ✓ removed /$${cmd%.md} (slash command)"; \
				fi; \
			done; \
		fi; \
	else \
		echo "Removing selected skills from $(TARGET)/.claude/skills/"; \
		for skill in $(SKILLS); do \
			if [ -d "$(TARGET)/.claude/skills/$$skill" ]; then \
				rm -rf "$(TARGET)/.claude/skills/$$skill"; \
				echo "  ✓ removed $$skill"; \
			else \
				echo "  ✗ $$skill (not installed)"; \
			fi; \
		done; \
	fi
	@echo "Done."

uninstall-cursor: ## Uninstall skills from Cursor (TARGET=<repo-path> [SKILLS='skill1 skill2'])
	@if [ -z "$(TARGET)" ]; then echo "Error: TARGET is required. Usage: make uninstall-cursor TARGET=~/projects/my-app"; exit 1; fi
	@if [ -z "$(SKILLS)" ]; then \
		echo "Removing all repo rules from $(TARGET)/.cursor/rules/"; \
		for dir in $(SKILLS_DIR)/*/; do \
			skill=$$(basename $$dir); \
			if [ -f "$(TARGET)/.cursor/rules/$$skill.mdc" ]; then \
				rm -f "$(TARGET)/.cursor/rules/$$skill.mdc"; \
				echo "  ✓ removed $$skill"; \
			fi; \
		done; \
	else \
		echo "Removing selected rules from $(TARGET)/.cursor/rules/"; \
		for skill in $(SKILLS); do \
			if [ -f "$(TARGET)/.cursor/rules/$$skill.mdc" ]; then \
				rm -f "$(TARGET)/.cursor/rules/$$skill.mdc"; \
				echo "  ✓ removed $$skill"; \
			else \
				echo "  ✗ $$skill (not installed)"; \
			fi; \
		done; \
	fi
	@echo "Done."

uninstall-copilot: ## Print instructions to remove Copilot instructions (TARGET=<repo-path>)
	@if [ -z "$(TARGET)" ]; then echo "Error: TARGET is required. Usage: make uninstall-copilot TARGET=~/projects/my-app"; exit 1; fi
	@target_file="$(TARGET)/.github/copilot-instructions.md"; \
	if [ -f "$$target_file" ]; then \
		echo "WARNING: Copilot instructions are bundled into a single file that may contain user-owned content."; \
		echo "Not deleting automatically to avoid data loss."; \
		echo ""; \
		echo "To remove, run manually:"; \
		echo "  rm '$$target_file'"; \
		echo ""; \
		echo "Or edit it to keep your own sections and drop the auto-generated ones."; \
	else \
		echo "Nothing to remove: $$target_file does not exist."; \
	fi

uninstall-all: ## Run all uninstall targets (TARGET=<repo-path> [SKILLS='skill1 skill2'])
	@$(MAKE) --no-print-directory uninstall-claude TARGET="$(TARGET)" SKILLS="$(SKILLS)"
	@$(MAKE) --no-print-directory uninstall-cursor TARGET="$(TARGET)" SKILLS="$(SKILLS)"
	@$(MAKE) --no-print-directory uninstall-copilot TARGET="$(TARGET)"
