std             = "ngx_lua"
unused_args     = false
redefined       = false
max_line_length = false


globals = {
    "_KONG",
    "kong",
    "ngx.IS_CLI",
}


not_globals = {
    "string.len",
    "table.getn",
}


files["spec/**/*.lua"] = {
    std = "ngx_lua+busted",
}

exclude_files = {
    "here/**",
    "lua_install/**",
    --"spec/fixtures/invalid-module.lua",
    --"spec-old-api/fixtures/invalid-module.lua",
}
