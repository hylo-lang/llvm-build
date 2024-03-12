# Hylo LLVM builds

GitHub CI based builds of LLVM libraries, compatible with the Swift
runtime.

[These builds](https://github.com/hylo-lang/llvm-build/releases)
contain a set of libraries suitable for compiler
development, and a very minimal set of tools such as `llvm-config` and
`lld`.  If you're looking for a compiler binary (e.g. `clang`), look
elsewhere!

Both the “Debug” and “MinSizeRel” builds have **assertions enabled**; 
without assertions, during development it's too easy to violate
LLVM's preconditions (some of which are 
[undocumented](https://github.com/llvm/llvm-project/pull/82519) or 
[incorrectly documented](https://github.com/llvm/llvm-project/pull/82517))

Swift compatibility is mostly irrelevant except when it comes to
Windows, where these builds of LLVM always link against a release-mode
multithreaded DLL C runtime and have iterator debugging disabled
(`_ITERATOR_DEBUG_LEVEL=0`) for C++.
