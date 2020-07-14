[![Build Status](https://travis-ci.com/Tieske/accessor.lua.svg?branch=master)](https://travis-ci.com/Tieske/accessor.lua)
[![Coverage Status](https://coveralls.io/repos/github/Tieske/accessor.lua/badge.svg?branch=master)](https://coveralls.io/github/Tieske/accessor.lua?branch=master)

accessor.lua
==============

This module implements an easy way to access arbitrary depth keys in Lua tables.

* for a single access it is convenient if you do not want to check the existence
  of intermediate tables or if the key is user provided
* performant if repeatedly looking up the same key in different tables

Both the [source code](https://github.com/Tieske/accessor.lua) as well as the
[documentation](http://tieske.github.io/accessor.lua) are on github


History
=======

### Release instructions

- update history and version information
- create new rockspec
- render the documentation
- commit and tag
- upload rock to LuaRocks

Version 1.0.0, 14-Jul-2020

 - Initial release


Copyright & license
===================
See [license](https://github.com/Tieske/accessor.lua/blob/master/LICENSE).
