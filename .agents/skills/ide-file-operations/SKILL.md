---
name: ide-file-operations
description: Safe file reading and writing in RAD Studio, handling IDE buffers and DFM/PAS safety.
---

# IDE File Operations

## When to use this skill

Use this skill for any file read or write operation when the RAD Studio IDE (Kai MCP) is available. It ensures that unsaved changes in the IDE are preserved and that designer files (.dfm) are handled safely.

## How to read a file (IDE-first)

1. Check if the file is open using `listOpenFiles`.
2. If open: Use `getEditorLines` (preferred â€” provide `startLine` and `lineCount` to read only what is needed). Use `getEditorContent` only when the entire file content is required. The IDE buffer is the source of truth.
3. If closed: Read directly from disk.

## How to write or edit a file

1. **Check IDE Status**: Determine if the file is open in the IDE.
2. **DFM Safety**: If editing a `.dfm` file:
   - Switch focus to the paired `.pas` file first: `openFile(pasPath, false)`.
   - This prevents the designer from being active during the text edit.
3. **Apply Edit**:
   - **Partial change**: Use `applyEdit` (preferred â€” provide `oldContent` with the exact text to replace, and `newContent`). Read the relevant lines with `getEditorLines` first to get the exact text. Returns an error if `oldContent` is not found.
   - **Full rewrite**: Use `setEditorContent` only when replacing the entire file content.
4. **Restore Designer**: If it was a `.dfm` and the designer was active before, restore it with `openFile(dfmPath, true)`.
5. **Closed Files**: If the file is not open, write directly to disk. Do not call `openFile` unless the user explicitly wants to see the file.

## Safety Rules

- Never use `reloadFile` without explicit user confirmation via `yesNoQuestion`.
- Treat the IDE buffer as canonical.
- Execute tools strictly sequentially.
