# GitHub Copilot Workspace Instructions  
For Delphi 13.1 Enterprise + FMXLinux + Linux ARM Targets  
Author: Antony (Delphi programmer, 35+ years experience)

---

## 🧩 Coding Language & Version
- Always generate **Delphi 13.1 Enterprise–compatible** code.
  - The code should be backwards compatible to Delphi 11 where possible
- Use **modern Delphi syntax** (generics, anonymous methods, RTTI, attributes).
- No interfaces unless requested
- Use **Threading via TTask or TThread** to avoid potential UI block
- Always consider SoC and keep classes simple and single purpose
- Avoid outdated Delphi 7-era patterns unless explicitly requested.
- When unsure about a Delphi feature, **state uncertainty rather than speculate**.

---

## 🖥 Framework Preferences
### FMX / FMXLinux
- Prefer **FMX** examples over VCL unless I explicitly ask for VCL.
- For cross‑platform UI, use **FMXLinux conventions**.
- Use platform‑safe components and avoid Windows‑only APIs unless requested.

### Linux ARM Targets
- When generating Linux code:
  - Use **FMXLinux** for UI.
  - Avoid Windows‑specific units (`Winapi.*`, `Vcl.*`).
  - Prefer **POSIX**, **System.***, and **RTL** units compatible with Linux ARM.

### CLI Targets
- All CLI projects should have a help page (-? or -h) 
- Target Windows and 64bit primarily
- Have an option (-logfile <path>) for log output
- Help instructions should be coloured to ease reading

### Windows Targets
- Windows‑only APIs are not allowed unless requested
- No .NET libraries unless requested 
  - .NET libraries are allowed if it is the **only** way logic can be created

---

## 🧱 Code Structure Requirements
- Always output **full, compilable Delphi units**, including:
  - `unit ...;`
  - `interface`
  - `uses`
  - `type`
  - `implementation`
  - `end.`

- When generating classes:
  - Include constructors/destructors.
  - Include interface implementations when requested.
  - Use clear separation between interface and implementation sections.

- When generating forms:
  - Provide both the **.pas** logic and the **FMX form description** when relevant.
  - Use named components with meaningful identifiers.

---

## 🧠 Behaviour & Explanation Style
- Provide **clear, accurate, non‑speculative** explanations.
- If something is unknown or ambiguous, say so plainly.
- Before showing code, give a **brief explanation** of:
  - What the code does
  - Why it is structured that way
  - Any platform considerations (Windows vs Linux)

- When refactoring:
  - Show **before/after** comparisons.
  - Explain the reasoning behind changes.

- When debugging:
  - Provide **step‑by‑step reasoning**.
  - Reference actual Delphi compiler behaviour.
  - Avoid generic or language‑agnostic debugging advice.

---

## 🔧 Project Context
This project uses:
- FMX as a Windows target 
- VCL as a Windows target
- CLI as a target for command line under Windows
- **Modern Delphi OOP patterns**  
- **Threading via TTask or TThread**  
- **Enterprise-level architecture**

---

## 📐 Formatting & Style
- Use **consistent indentation** and readable formatting.
- Prefer **TObjectList<T>**, **TList<T>**, and modern collections.
- Use **interfaces** for architecture where appropriate.
- Avoid unnecessary global variables.
- Use **try/finally** for resource safety.
- When generating REST code, prefer **THTTPClient** unless Indy is explicitly requested.

---

## 🧪 Testing & Examples
- Provide runnable examples.
- Include test harnesses or minimal demo forms when helpful.
- Use realistic data structures and types.

---

## 🚫 What to Avoid
- No pseudocode.
- No speculative behaviour.
- No generic “AI-style” answers.
- No code that only compiles on Windows unless I ask for it.
- No outdated Delphi patterns (e.g., `with`, untyped pointers, manual memory unless needed).

---

## 🎯 Goal
Produce **accurate, idiomatic, modern Delphi code** with **clear explanations**, tailored to **FMXLinux**, **Linux ARM**, and **Enterprise-level development**, without requiring repeated instructions from the user.
