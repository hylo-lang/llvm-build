# Hylo LLVM builds

GitHub CI based builds of LLVM libraries, compatible with the Swift
runtime.

These builds contain a set of libraries suitable for compiler
development, and a very minimal set of tools such as `llvm-config` and
`lld`.  If you're looking for a compiler binary (e.g. `clang`), look
elsewhere!

Swift compatibility is mostly irrelevant except when it comes to
Windows, where these builds of LLVM always link against a release-mode
multithreaded DLL C runtime and have iterator debugging disabled
(`_ITERATOR_DEBUG_LEVEL=0`) for C++.
