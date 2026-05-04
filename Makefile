REPO_URL := https://raw.githubusercontent.com/guidomantilla/best-practices/main
SKILLS_DIR := .skills

.PHONY: help install-claude install-copilot install-cursor list

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
	@echo "  make install-claude TARGET=~/projects/my-app SKILLS='secure-review testing-review'"

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
	@echo ""
	@echo "Done. Skills installed to $(TARGET)/.claude/skills/"
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
			cp "$$dir/SKILL.md" "$(TARGET)/.cursor/rules/$$skill.md"; \
			echo "  ✓ $$skill"; \
		done; \
	else \
		echo "Installing selected skills to $(TARGET)/.cursor/rules/"; \
		for skill in $(SKILLS); do \
			if [ -d "$(SKILLS_DIR)/$$skill" ]; then \
				cp "$(SKILLS_DIR)/$$skill/SKILL.md" "$(TARGET)/.cursor/rules/$$skill.md"; \
				echo "  ✓ $$skill"; \
			else \
				echo "  ✗ $$skill (not found)"; \
			fi; \
		done; \
	fi
	@echo ""
	@echo "Done. Skills installed to $(TARGET)/.cursor/rules/"
	@echo "Skills reference content from: $(REPO_URL)/"
