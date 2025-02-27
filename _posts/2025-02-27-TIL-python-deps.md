---
title: "Python Dependency Checker"
date: 2025-02-27
category: til
---

I discovered [Tach](https://github.com/gauge-sh/tach), a static code checker for Python projects to enforce dependencies between modules. For example in a layered backend architecture you can enforce that `controller` modules can only depend on `service` and `repository` modules and, e.g. `repository` modules cannot import from `controller` modules. Looks interesting also to enforce code boundaries between modules (or components) in a modular monolith. I'd like to check it out in one of my next projects.