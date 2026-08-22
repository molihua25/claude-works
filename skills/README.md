# Claude Skills

与 Claude 合作沉淀的可复用技能,每个 skill 一个目录,`SKILL.md` 为入口(含 frontmatter 触发描述)。

| Skill | 用途 |
|---|---|
| [etf-strategy-v5-2](etf-strategy-v5-2/SKILL.md) | V5-2 累计回撤驱动 ETF 量化波段策略(含 1000 元应急备用金)完整规则库与维护口径 |
| [paper-deep-read](paper-deep-read/SKILL.md) | 精读文献:输入论文(PDF/docx),按八段式模板生成深度精读报告 |

## 使用方式

Claude Code 会话中自动按描述匹配加载;也可手动复制到本地 `~/.claude/skills/<skill名>/` 或项目 `.claude/skills/<skill名>/` 使用。
